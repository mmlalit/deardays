import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Crash reporting and error tracking service.
///
/// In production, this captures unhandled exceptions, Flutter framework errors,
/// and breadcrumbs, then sends them to a configurable backend (Sentry, Crashlytics,
/// or custom endpoint). In debug mode, errors are printed to the console only.
///
/// Usage:
/// ```dart
/// await CrashReportingService().init();
/// ```
class CrashReportingService {
  CrashReportingService._internal();

  static final CrashReportingService _instance =
      CrashReportingService._internal();

  static CrashReportingService get instance => _instance;

  factory CrashReportingService() => _instance;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  String? _userId;
  final Map<String, String> _userContext = {};

  // Breadcrumb trail for debugging context
  static const int _maxBreadcrumbs = 50;
  final List<Breadcrumb> _breadcrumbs = [];
  List<Breadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  // Error log for the current session
  final List<CrashReport> _reports = [];
  List<CrashReport> get reports => List.unmodifiable(_reports);

  // Endpoint for crash reports (configured via dart-define)
  static const String _reportEndpoint = String.fromEnvironment(
    'CRASH_REPORT_URL',
    defaultValue: '',
  );

  bool get isConfigured => _reportEndpoint.isNotEmpty;

  /// Initializes crash reporting by hooking into Flutter's error handlers
  /// and Dart's zone/isolate error streams.
  Future<void> init() async {
    if (_initialized) return;

    // Capture Flutter framework errors (rendering, build, etc.)
    FlutterError.onError = _handleFlutterError;

    // Capture errors from other isolates
    Isolate.current.addErrorListener(RawReceivePort((pair) {
      final errorAndStack = pair as List<dynamic>;
      final error = errorAndStack[0];
      final stack = errorAndStack[1] as String?;
      recordError(
        error,
        stack != null ? StackTrace.fromString(stack) : StackTrace.current,
        reason: 'Isolate error',
      );
    }).sendPort);

    _initialized = true;
    debugPrint('[CrashReportingService] Initialized.');
  }

  /// Wraps [runApp] in an error-capturing zone.
  ///
  /// Call this instead of `runApp()` directly:
  /// ```dart
  /// CrashReportingService().runGuarded(() => runApp(const MyApp()));
  /// ```
  void runGuarded(VoidCallback appRunner) {
    runZonedGuarded(
      appRunner,
      (error, stackTrace) {
        recordError(error, stackTrace, reason: 'Unhandled zone error');
      },
    );
  }

  /// Sets the current user for crash reports.
  void setUser(String userId, {Map<String, String>? context}) {
    _userId = userId;
    if (context != null) {
      _userContext
        ..clear()
        ..addAll(context);
    }
    addBreadcrumb('User identified', data: {'user_id': userId});
  }

  /// Clears user info (e.g., on logout).
  void clearUser() {
    _userId = null;
    _userContext.clear();
  }

  /// Adds a breadcrumb to the trail for debugging context.
  void addBreadcrumb(String message, {Map<String, String>? data}) {
    final crumb = Breadcrumb(
      message: message,
      timestamp: DateTime.now(),
      data: data ?? const {},
    );
    _breadcrumbs.add(crumb);
    if (_breadcrumbs.length > _maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
  }

  /// Records a non-fatal error with optional context.
  void recordError(
    dynamic error,
    StackTrace stackTrace, {
    String? reason,
    Map<String, String>? extras,
  }) {
    final report = CrashReport(
      error: error.toString(),
      stackTrace: stackTrace.toString(),
      reason: reason,
      userId: _userId,
      userContext: Map.of(_userContext),
      extras: extras ?? const {},
      breadcrumbs: List.of(_breadcrumbs),
      timestamp: DateTime.now(),
    );

    _reports.add(report);

    if (kDebugMode) {
      debugPrint('[CrashReportingService] Error: $error');
      debugPrint('[CrashReportingService] Reason: $reason');
      debugPrint('[CrashReportingService] Stack: $stackTrace');
    }

    // In production with a configured endpoint, this would POST the report.
    // For now, we log and store locally.
  }

  /// Records a Flutter framework error.
  void _handleFlutterError(FlutterErrorDetails details) {
    addBreadcrumb('Flutter error', data: {
      'library': details.library ?? 'unknown',
      'context': details.context?.toString() ?? '',
    });

    recordError(
      details.exception,
      details.stack ?? StackTrace.current,
      reason: 'Flutter framework error in ${details.library}',
    );

    // Still print in debug mode for developer convenience
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  }

  /// Records a fatal error that caused the app to crash.
  void recordFatalError(dynamic error, StackTrace stackTrace) {
    recordError(error, stackTrace, reason: 'Fatal error');
  }

  /// Clears all stored reports and breadcrumbs.
  void clear() {
    _reports.clear();
    _breadcrumbs.clear();
  }
}

/// A breadcrumb in the error trail, providing context for crash reports.
class Breadcrumb {
  final String message;
  final DateTime timestamp;
  final Map<String, String> data;

  const Breadcrumb({
    required this.message,
    required this.timestamp,
    this.data = const {},
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'data': data,
      };
}

/// A captured error report with full context.
class CrashReport {
  final String error;
  final String stackTrace;
  final String? reason;
  final String? userId;
  final Map<String, String> userContext;
  final Map<String, String> extras;
  final List<Breadcrumb> breadcrumbs;
  final DateTime timestamp;

  const CrashReport({
    required this.error,
    required this.stackTrace,
    this.reason,
    this.userId,
    this.userContext = const {},
    this.extras = const {},
    this.breadcrumbs = const [],
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'error': error,
        'stack_trace': stackTrace,
        'reason': reason,
        'user_id': userId,
        'user_context': userContext,
        'extras': extras,
        'breadcrumbs': breadcrumbs.map((b) => b.toJson()).toList(),
        'timestamp': timestamp.toIso8601String(),
      };
}
