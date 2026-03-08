import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/routing/app_router.dart';
import 'package:deardays/core/config/supabase_config.dart';
import 'package:deardays/core/providers/theme_provider.dart';
import 'package:deardays/core/providers/locale_provider.dart';
import 'package:deardays/services/storage/local_storage_service.dart';
import 'package:deardays/services/storage/secure_storage_service.dart';
import 'package:deardays/services/encryption/encryption_service.dart';
import 'package:deardays/services/subscription/revenuecat_service.dart';
import 'package:deardays/services/notification/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (skip if no URL configured — allows web preview)
  if (SupabaseConfig.supabaseUrl.isNotEmpty) {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
  }

  // Initialize local encrypted storage
  await LocalStorageService().init();

  // Restore encryption key from keychain if user has an active session.
  // This covers cold restarts where the Supabase session persists but the
  // in-memory encryption key has been cleared.
  if (SupabaseConfig.supabaseUrl.isNotEmpty) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final storedKey = await SecureStorageService().getEncryptionKey();
      if (storedKey != null) {
        EncryptionService().setKey(storedKey);
      }
    }
  }

  // Initialize RevenueCat for in-app purchases
  await RevenueCatService().init();

  // Initialize local notifications
  await NotificationService().init();

  runApp(const ProviderScope(child: DearDaysApp()));
}

class DearDaysApp extends ConsumerWidget {
  const DearDaysApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
