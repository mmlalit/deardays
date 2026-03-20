import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Manages AI usage credits per user to control cost and gate premium features.
///
/// Free users get a limited number of AI calls per month. Premium users
/// get unlimited (or a much higher cap). The service persists credit state
/// locally via Hive and syncs with the server on login.
///
/// Credit tiers:
///   Free:    5 AI polishes, 3 summaries, 10 chat messages / month
///   Premium: 100 polishes, unlimited summaries, unlimited chat / month
///   Ultra:   Unlimited everything
class AiCreditService {
  AiCreditService._internal();
  static final AiCreditService _instance = AiCreditService._internal();
  factory AiCreditService() => _instance;

  static const String _boxName = 'ai_credits';

  Box<dynamic>? _box;

  // ── Default limits per tier ───────────────────────────────────────────────

  static const Map<String, CreditLimits> tierLimits = {
    'free': CreditLimits(
      polish: 30,
      summary: 15,
      chat: 50,
      themes: 20,
      transcription: 30,
    ),
    'premium': CreditLimits(
      polish: 100,
      summary: -1, // unlimited
      chat: -1,
      themes: -1,
      transcription: 50,
    ),
    'ultra': CreditLimits(
      polish: -1,
      summary: -1,
      chat: -1,
      themes: -1,
      transcription: -1,
    ),
  };

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    _checkMonthReset();
    if (kDebugMode) {
      debugPrint('[AiCreditService] Initialized. Usage: ${getUsageSummary()}');
    }
  }

  @visibleForTesting
  Future<void> initForTesting() async {
    _box = await Hive.openBox('${_boxName}_test_${DateTime.now().millisecondsSinceEpoch}');
  }

  // ── Month reset ───────────────────────────────────────────────────────────

  void _checkMonthReset() {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    final storedMonth = _box?.get('credit_month') as String?;

    // Also reset if any usage counter exceeds the current limit (e.g. after a
    // limit increase in an app update) so users don't stay locked out.
    final usageOverLimit = _getUsed('polish_used') >= (tierLimits[currentTier]?.polish ?? 5);

    if (storedMonth != currentMonth || usageOverLimit) {
      // New month or limit increased — reset all usage counters
      _box?.put('credit_month', currentMonth);
      _box?.put('polish_used', 0);
      _box?.put('summary_used', 0);
      _box?.put('chat_used', 0);
      _box?.put('themes_used', 0);
      _box?.put('transcription_used', 0);
      if (kDebugMode) {
        debugPrint('[AiCreditService] Monthly reset — new month: $currentMonth');
      }
    }
  }

  // ── Tier management ───────────────────────────────────────────────────────

  String get currentTier => (_box?.get('tier', defaultValue: 'free') as String?) ?? 'free';

  set currentTier(String tier) {
    _box?.put('tier', tier);
  }

  CreditLimits get limits => tierLimits[currentTier] ?? tierLimits['free']!;

  // ── Usage tracking ────────────────────────────────────────────────────────

  int _getUsed(String key) => _box?.get(key, defaultValue: 0) as int? ?? 0;

  void _increment(String key) {
    final current = _getUsed(key);
    _box?.put(key, current + 1);
  }

  int get polishUsed => _getUsed('polish_used');
  int get summaryUsed => _getUsed('summary_used');
  int get chatUsed => _getUsed('chat_used');
  int get themesUsed => _getUsed('themes_used');
  int get transcriptionUsed => _getUsed('transcription_used');

  // ── Credit checks ─────────────────────────────────────────────────────────

  /// Returns true if the user has credits remaining for the given [operation].
  bool canUse(AiOperation operation) {
    final limit = _limitFor(operation);
    if (limit == -1) return true; // unlimited
    return _usedFor(operation) < limit;
  }

  /// Returns the number of remaining credits for the given [operation].
  int remaining(AiOperation operation) {
    final limit = _limitFor(operation);
    if (limit == -1) return 999; // effectively unlimited
    return (limit - _usedFor(operation)).clamp(0, limit);
  }

  /// Records one usage of the given [operation]. Returns true if successful,
  /// false if the user has no credits remaining.
  bool consume(AiOperation operation) {
    if (!canUse(operation)) {
      if (kDebugMode) {
        debugPrint('[AiCreditService] DENIED: ${operation.name} — no credits left');
      }
      return false;
    }

    _increment(_keyFor(operation));
    if (kDebugMode) {
      debugPrint(
        '[AiCreditService] Used: ${operation.name} '
        '(${_usedFor(operation)}/${_limitFor(operation)})',
      );
    }
    return true;
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  Map<String, CreditUsage> getUsageSummary() {
    return {
      for (final op in AiOperation.values)
        op.name: CreditUsage(
          used: _usedFor(op),
          limit: _limitFor(op),
        ),
    };
  }

  // ── Reset (for testing / account switch) ──────────────────────────────────

  void reset() {
    _box?.put('polish_used', 0);
    _box?.put('summary_used', 0);
    _box?.put('chat_used', 0);
    _box?.put('themes_used', 0);
    _box?.put('transcription_used', 0);
    _box?.put('tier', 'free');
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  int _limitFor(AiOperation op) {
    final l = limits;
    return switch (op) {
      AiOperation.polish => l.polish,
      AiOperation.summary => l.summary,
      AiOperation.chat => l.chat,
      AiOperation.themes => l.themes,
      AiOperation.transcription => l.transcription,
    };
  }

  int _usedFor(AiOperation op) => _getUsed(_keyFor(op));

  String _keyFor(AiOperation op) => switch (op) {
        AiOperation.polish => 'polish_used',
        AiOperation.summary => 'summary_used',
        AiOperation.chat => 'chat_used',
        AiOperation.themes => 'themes_used',
        AiOperation.transcription => 'transcription_used',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

enum AiOperation {
  polish,
  summary,
  chat,
  themes,
  transcription,
}

class CreditLimits {
  final int polish;
  final int summary;
  final int chat;
  final int themes;
  final int transcription;

  const CreditLimits({
    required this.polish,
    required this.summary,
    required this.chat,
    required this.themes,
    required this.transcription,
  });
}

class CreditUsage {
  final int used;
  final int limit; // -1 = unlimited

  const CreditUsage({required this.used, required this.limit});

  bool get isUnlimited => limit == -1;
  int get remaining => isUnlimited ? 999 : (limit - used).clamp(0, limit);
  bool get hasCredits => isUnlimited || used < limit;
  double get usagePercent => isUnlimited ? 0.0 : (used / limit).clamp(0.0, 1.0);

  @override
  String toString() => isUnlimited ? '$used/∞' : '$used/$limit';
}
