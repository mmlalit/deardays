import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart' as sentry;

/// Crash reporting and error tracking service backed by Sentry.
///
/// In production, captures unhandled exceptions, Flutter framework errors,
/// and breadcrumbs, then sends them to Sentry. In debug mode, errors are
/// printed to the console only.
///
/// Configure via dart-define:
/// ```bash
/// flutter run --dart-define=SENTRY_DSN=https://xxx@xxx.ingest.sentry.io/xxx
/// ```
class CrashReportingService {
  CrashReportingService._internal();

  static final CrashReportingService _instance =
      CrashReportingService._internal();

  static CrashReportingService get instance => _instance;

  factory CrashReportingService() => _instance;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  // Previous Flutter error handler stored so we can restore on dispose.
  FlutterExceptionHandler? _previousFlutterErrorHandler;

  String? _userId;
  final Map<String, String> _userContext = {};

  // Breadcrumb trail for debugging context
  static const int _maxBreadcrumbs = 200;
  final List<Breadcrumb> _breadcrumbs = [];
  List<Breadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  // Error log for the current session
  final List<CrashReport> _reports = [];
  List<CrashReport> get reports => List.unmodifiable(_reports);

  // Sentry DSN (configured via dart-define)
  static const String _sentryDsn = String.fromEnvironment(
    'SENTRY_DSN',
    defaultValue: '',
  );

  bool get isConfigured => _sentryDsn.isNotEmpty;

  /// Initializes crash reporting by hooking into Flutter's error handlers
  /// and Dart's zone/isolate error streams.
  ///
  /// When Sentry DSN is configured, initializes the Sentry SDK which handles
  /// all error capture automatically. Otherwise falls back to local logging.
  Future<void> init() async {
    if (_initialized) return;

    // Store previous handler so dispose() can restore it (prevents accumulation on hot reload).
    _previousFlutterErrorHandler = FlutterError.onError;
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
    debugPrint('[CrashReportingService] Initialized. Sentry: ${isConfigured ? "enabled" : "disabled (no DSN)"}');
  }

  /// Initializes Sentry and runs the app inside its error-capturing zone.
  ///
  /// Call this instead of `runApp()` directly:
  /// ```dart
  /// CrashReportingService().runGuarded(() async {
  ///   // ... init services ...
  ///   runApp(const MyApp());
  /// });
  /// ```
  void runGuarded(VoidCallback appRunner) {
    if (isConfigured && !kDebugMode) {
      // In production with Sentry configured, use Sentry's zone guard
      sentry.SentryFlutter.init(
        (options) {
          // Read from environment or use release-mode defaults
          const tracesSampleRate = kReleaseMode ? 0.1 : 1.0;
          const profilesSampleRate = kReleaseMode ? 0.05 : 1.0;
          options.dsn = _sentryDsn;
          options.tracesSampleRate = tracesSampleRate;
          options.profilesSampleRate = profilesSampleRate;
          options.attachScreenshot = true;
          options.maxBreadcrumbs = _maxBreadcrumbs;
          options.sendDefaultPii = false; // Don't send PII
          options.environment = kDebugMode ? 'development' : 'production';
        },
        appRunner: () {
          runZonedGuarded(
            appRunner,
            (error, stackTrace) {
              recordError(error, stackTrace, reason: 'Unhandled zone error');
            },
          );
        },
      );
    } else {
      // In debug mode or without Sentry, use simple zone guard
      runZonedGuarded(
        appRunner,
        (error, stackTrace) {
          recordError(error, stackTrace, reason: 'Unhandled zone error');
        },
      );
    }
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

    // Set Sentry user
    if (isConfigured) {
      sentry.Sentry.configureScope((scope) {
        scope.setUser(sentry.SentryUser(id: userId));
        if (context != null) {
          for (final entry in context.entries) {
            scope.setTag(entry.key, entry.value);
          }
        }
      });
    }
  }

  /// Clears user info (e.g., on logout).
  void clearUser() {
    _userId = null;
    _userContext.clear();
    if (isConfigured) {
      sentry.Sentry.configureScope((scope) => scope.setUser(null));
    }
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

    // Also add to Sentry
    if (isConfigured) {
      sentry.Sentry.addBreadcrumb(sentry.Breadcrumb(
        message: message,
        data: data ?? const {},
        timestamp: DateTime.now(),
      ));
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

    // Send to Sentry in production
    if (isConfigured && !kDebugMode) {
      sentry.Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (reason != null) scope.setTag('reason', reason);
          if (extras != null) {
            for (final entry in extras.entries) {
              scope.setTag(entry.key, entry.value);
            }
          }
        },
      );
    }
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

  /// Restores the previous Flutter error handler. Call in tests or on hot reload.
  void dispose() {
    FlutterError.onError = _previousFlutterErrorHandler;
    _initialized = false;
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
