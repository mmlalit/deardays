// WeeklyReportScreen is superseded by ReflectionScreen(period: weekly).
// This file keeps the class alive so existing imports don't break while
// any remaining call-sites are migrated.
export 'package:deardays/features/journal/presentation/screens/reflection_screen.dart'
    show ReflectionScreen;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:deardays/features/journal/presentation/screens/reflection_screen.dart';

/// Deprecated — navigates to [ReflectionScreen] with the weekly period.
@Deprecated('Use ReflectionScreen(period: ReflectionPeriod.weekly) directly.')
class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Replace this entry in the navigation stack immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        try {
          context.pushReplacement('/reflection?period=weekly');
        } catch (e) {
          debugPrint('[WeeklyReport] Navigation error: $e');
        }
      }
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
