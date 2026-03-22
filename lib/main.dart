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
import 'package:deardays/core/config/feature_flags.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/services/version/version_check_service.dart';
import 'package:deardays/features/journal/data/repositories/reflection_override_repository.dart';
import 'package:deardays/services/location/location_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  // Initialize crash reporting first so it captures all subsequent errors
  await CrashReportingService().init();

  // Run app inside crash reporting zone (binding must be in the same zone as runApp)
  CrashReportingService().runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ── Phase 1: Sequential dependencies ────────────────────────────────────
    // These must complete before anything else can start.

    // Initialize Supabase (skip if no URL configured — allows web preview)
    if (SupabaseConfig.supabaseUrl.isNotEmpty) {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    }

    // Local storage must init first — sync queue & AI queue depend on its cipher
    final localStorage = LocalStorageService();
    await localStorage.init();

    // Onboarding state (Hive box used by OnboardingNotifier)
    await Hive.openBox<String>('onboarding_prefs');

    // Sync queue and reflection overrides both depend on localStorage.cipher
    await Future.wait([
      SyncQueue().init(localStorage.cipher),
      ReflectionOverrideRepository().init(),
    ]);

    // ── Phase 2: Everything else in parallel ────────────────────────────────
    // These services are independent of each other and can init concurrently.
    // This cuts startup time from ~1100ms to ~500ms.
    await Future.wait([
      AnalyticsService().init(),
      RevenueCatService().init(),
      NotificationService().init(),
      LocationService().requestPermission(),
      ConnectivityService().init(),
      BackupService().init(),
      AiCreditService().init(),
      OfflineAiQueue().init(),
      FeatureFlags().init(),
      VersionCheckService().check(),
    ]);

    // ── Phase 3: Wire up sync (depends on connectivity) ─────────────────────
    unawaited(OfflineAiQueue().pruneStale()); // non-blocking housekeeping
    await SyncService().init();
    SyncService().enableQueue();

    runApp(const ProviderScope(child: DearDaysApp()));
  });
}

class DearDaysApp extends ConsumerStatefulWidget {
  const DearDaysApp({super.key});

  @override
  ConsumerState<DearDaysApp> createState() => _DearDaysAppState();
}

class _DearDaysAppState extends ConsumerState<DearDaysApp> {
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    // Set initial value
    ref.read(connectivityProvider.notifier).state =
        ConnectivityService().isOnline;
    // Wire ConnectivityService stream → connectivityProvider
    _connectivitySub = ConnectivityService().onlineStatus.listen((online) {
      if (mounted) ref.read(connectivityProvider.notifier).state = online;
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
