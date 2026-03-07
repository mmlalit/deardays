import 'package:flutter/material.dart';
import 'package:deardays/core/theme/app_colors.dart';

/// Consistent SnackBar styling across the app.
class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFB91C1C) : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static void success(BuildContext context, String message) {
    show(context, message: message);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, isError: true);
  }
}
