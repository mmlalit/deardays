import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/routing/app_router.dart';
import 'package:deardays/core/config/supabase_config.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/core/providers/locale_provider.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/services/subscription/revenuecat_service.dart';
import 'package:deardays/services/notification/notification_service.dart';
import 'package:deardays/services/connectivity/connectivity_service.dart';
import 'package:deardays/services/sync/sync_service.dart';
import 'package:deardays/services/sync/sync_queue.dart';
import 'package:deardays/services/crash_reporting/crash_reporting_service.dart';
import 'package:deardays/services/analytics/analytics_service.dart';
import 'package:deardays/services/backup/backup_service.dart';
import 'package:deardays/services/ai/ai_credit_service.dart';
import 'package:deardays/services/ai/offline_ai_queue.dart';
import 'package:deardays/services/media/pending_photo_uploads.dart';
import 'package:deardays/core/config/feature_flags.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/services/version/version_check_service.dart';
import 'package:deardays/services/sync/offline_write_service.dart';
import 'package:deardays/features/journal/data/repositories/reflection_override_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Services that failed to initialize. Read by DearDaysApp to populate
/// [serviceInitFailuresProvider] once the widget tree is built.
final List<String> _serviceInitFailures = [];

void _recordInitFailure(String service, Object error) {
  _serviceInitFailures.add(service);
  try {
    CrashReportingService().recordError(
      error, StackTrace.current,
      reason: '${service.toLowerCase().replaceAll(' ', '_')}_init_failed',
    );
  } catch (_) {}
}

void main() async {
  debugPrint('[main] ════════════ DearDays main() ENTERED ════════════');
  // Run app inside crash reporting zone (binding must be in the same zone as runApp)
  CrashReportingService().runGuarded(() async {
    debugPrint('[main] runGuarded callback started');
    final startupStopwatch = Stopwatch()..start();
    WidgetsFlutterBinding.ensureInitialized();
    debugPrint('[main] ✓ WidgetsBinding initialized (${startupStopwatch.elapsedMilliseconds}ms)');

    // ── Phase 1: Sequential dependencies ────────────────────────────────────
    // These must complete before anything else can start.

    // Initialize Supabase (skip if no URL configured — allows web preview)
    // Timeout after 10s so the app doesn't hang on bad network / first install.
    debugPrint('[main] Supabase URL: ${SupabaseConfig.supabaseUrl.isEmpty ? "EMPTY" : SupabaseConfig.supabaseUrl}');
    if (SupabaseConfig.supabaseUrl.isNotEmpty) {
      try {
        debugPrint('[main] → Supabase.initialize starting...');
        await Supabase.initialize(
          url: SupabaseConfig.supabaseUrl,
          anonKey: SupabaseConfig.supabaseAnonKey,
        ).timeout(const Duration(seconds: 10));
        debugPrint('[main] ✓ Supabase initialized (${startupStopwatch.elapsedMilliseconds}ms)');
      } on TimeoutException {
        debugPrint('[main] ✗ Supabase.initialize timed out after 10s — continuing');
      } catch (e) {
        debugPrint('[main] ✗ Supabase.initialize failed: $e');
      }
    } else {
      debugPrint('[main] ⚠ Supabase URL is EMPTY — skipping init');
    }

    // Initialize crash reporting after Supabase so auth context is available.
    try {
      debugPrint('[main] → CrashReporting init...');
      await CrashReportingService().init();
      debugPrint('[main] ✓ CrashReporting initialized (${startupStopwatch.elapsedMilliseconds}ms)');
    } catch (e) {
      debugPrint('[main] ✗ CrashReportingService init failed: $e');
    }

    // Local storage must init first — sync queue & AI queue depend on its cipher
    debugPrint('[main] → LocalStorage init...');
    final localStorage = LocalStorageService();
    await localStorage.init();
    debugPrint('[main] ✓ LocalStorage initialized (${startupStopwatch.elapsedMilliseconds}ms)');

    // Onboarding state (Hive box used by OnboardingNotifier)
    debugPrint('[main] → Hive onboarding_prefs...');
    await Hive.openBox<String>('onboarding_prefs');
    debugPrint('[main] ✓ Hive onboarding box opened (${startupStopwatch.elapsedMilliseconds}ms)');

    // Sync queue and reflection overrides both depend on localStorage.cipher
    debugPrint('[main] → SyncQueue + ReflectionOverrides init...');
    await Future.wait([
      SyncQueue().init(localStorage.cipher),
      ReflectionOverrideRepository().init(),
    ]);
    debugPrint('[main] ✓ SyncQueue + ReflectionOverrides (${startupStopwatch.elapsedMilliseconds}ms)');

    final phase1Ms = startupStopwatch.elapsedMilliseconds;
    debugPrint('[main] ═══ Phase 1 complete: ${phase1Ms}ms ═══');

    // ── Phase 2: Wire up sync (depends on Phase 1) ──────────────────────────
    debugPrint('[main] → SyncService init...');
    await SyncService().init();
    SyncService().enableQueue();
    debugPrint('[main] ✓ SyncService ready (${startupStopwatch.elapsedMilliseconds}ms)');

    // ── Launch the app immediately ───────────────────────────────────────────
    // All remaining services (analytics, notifications, connectivity, etc.) are
    // started fire-and-forget AFTER runApp so that permission dialogs and slow
    // network calls never block the first frame on Android.
    debugPrint('[main] ═══ Phase 2 complete — calling runApp (${startupStopwatch.elapsedMilliseconds}ms) ═══');
    runApp(const ProviderScope(child: DearDaysApp()));
    debugPrint('[main] ✓ runApp called (${startupStopwatch.elapsedMilliseconds}ms)');

    // ── Phase 3: Background services (fire-and-forget) ──────────────────────
    // Each service is wrapped in its own try-catch so one failure doesn't
    // prevent others from initializing. Failures are tracked in
    // _serviceInitFailures so the UI can show a degraded-service banner.
    // OfflineAiQueue.init() must complete before pruneStale() is called.
    unawaited(OfflineAiQueue().init().then((_) => OfflineAiQueue().pruneStale())
        .catchError((e) { debugPrint('[main] OfflineAiQueue init failed: $e'); _recordInitFailure('AI Queue', e); return 0; }));
    unawaited(AnalyticsService().init().then((_) {
      AnalyticsService().track('app_startup', properties: {
        'total_ms': startupStopwatch.elapsedMilliseconds.toString(),
        'phase1_ms': phase1Ms.toString(),
      });
    }).catchError((e) { debugPrint('[main] AnalyticsService init failed: $e'); return null; }));
    unawaited(RevenueCatService().init()
        .catchError((e) { debugPrint('[main] RevenueCatService init failed: $e'); _recordInitFailure('Subscriptions', e); }));
    unawaited(NotificationService().init()
        .catchError((e) { debugPrint('[main] NotificationService init failed: $e'); _recordInitFailure('Notifications', e); }));
    unawaited(ConnectivityService().init()
        .catchError((e) { debugPrint('[main] ConnectivityService init failed: $e'); _recordInitFailure('Connectivity', e); }));
    unawaited(BackupService().init()
        .catchError((e) { debugPrint('[main] BackupService init failed: $e'); _recordInitFailure('Backup', e); }));
    unawaited(AiCreditService().init()
        .catchError((e) { debugPrint('[main] AiCreditService init failed: $e'); _recordInitFailure('AI Credits', e); }));
    unawaited(FeatureFlags().init()
        .catchError((e) { debugPrint('[main] FeatureFlags init failed: $e'); _recordInitFailure('Feature Flags', e); }));
    unawaited(VersionCheckService().check()
        .catchError((e) => debugPrint('[main] VersionCheckService check failed: $e')));
    unawaited(PendingPhotoUploads().init()
        .catchError((e) { debugPrint('[main] PendingPhotoUploads init failed: $e'); _recordInitFailure('Photo Uploads', e); }));
  });
}

class DearDaysApp extends ConsumerStatefulWidget {
  const DearDaysApp({super.key});

  @override
  ConsumerState<DearDaysApp> createState() => _DearDaysAppState();
}

class _DearDaysAppState extends ConsumerState<DearDaysApp> {
  StreamSubscription<bool>? _connectivitySub;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    // Surface any Phase 3 service init failures to the provider tree.
    // Delayed so the provider is readable after the first frame.
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _serviceInitFailures.isNotEmpty) {
        ref.read(serviceInitFailuresProvider.notifier).state =
            List.unmodifiable(_serviceInitFailures);
      }
    });
    // Set initial value
    _wasOffline = !ConnectivityService().isOnline;
    ref.read(connectivityProvider.notifier).state =
        ConnectivityService().isOnline;
    // Wire ConnectivityService stream → connectivityProvider
    _connectivitySub = ConnectivityService().onlineStatus.listen((online) {
      if (mounted) ref.read(connectivityProvider.notifier).state = online;
      // Retry any queued photo uploads when connectivity is restored.
      if (online && PendingPhotoUploads().hasPending) {
        PendingPhotoUploads().retryAll();
      }
      // Replay queued offline writes when connectivity is restored.
      if (online && _wasOffline && OfflineWriteService().pendingCount > 0) {
        OfflineWriteService().replayQueue();
      }
      _wasOffline = !online;
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final localeState = ref.watch(localeProvider);

    return MaterialApp.router(
      title: 'DearDays',
      debugShowCheckedModeBanner: false,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: theme.effectiveThemeMode,
      locale: localeState.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: AppRouter.router,
    );
  }
}
