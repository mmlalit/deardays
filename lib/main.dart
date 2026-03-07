import 'package:flutter/material.dart';
import 'package:deardays/core/theme/app_theme.dart';
import 'package:deardays/core/routing/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DearDaysApp());
}

class DearDaysApp extends StatelessWidget {
  const DearDaysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DearDays',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
    );
  }
}
