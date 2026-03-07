import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:deardays/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:deardays/features/auth/presentation/screens/login_screen.dart';
import 'package:deardays/features/journal/presentation/screens/home_screen.dart';
import 'package:deardays/features/journal/presentation/screens/recording_screen.dart';
import 'package:deardays/features/journal/presentation/screens/text_entry_screen.dart';
import 'package:deardays/features/journal/presentation/screens/paywall_screen.dart';
import 'package:deardays/features/journal/presentation/screens/on_this_day_screen.dart';
import 'package:deardays/features/book/presentation/screens/book_view_screen.dart';
import 'package:deardays/features/book/presentation/screens/export_screen.dart';
import 'package:deardays/features/timeline/presentation/screens/timeline_screen.dart';
import 'package:deardays/features/settings/presentation/screens/settings_screen.dart';
import 'package:deardays/core/routing/app_shell.dart';

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingScreen(
          onComplete: () => context.go('/login'),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          onLogin: () => context.go('/home'),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/book',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: BookViewScreen(),
            ),
          ),
          GoRoute(
            path: '/timeline',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TimelineScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/record',
        builder: (context, state) => const RecordingScreen(),
      ),
      GoRoute(
        path: '/write',
        builder: (context, state) => const TextEntryScreen(),
      ),
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/on-this-day',
        builder: (context, state) => const OnThisDayScreen(),
      ),
      GoRoute(
        path: '/export',
        builder: (context, state) => const ExportScreen(),
      ),
    ],
  );
}
