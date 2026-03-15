import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/services/version/version_check_service.dart';

/// Shows a non-dismissible dialog when the app version is below the minimum
/// required by the server. Call from the home screen's `initState`.
class ForceUpdateDialog {
  static bool _shown = false;

  static void showIfNeeded(BuildContext context) {
    if (_shown || !VersionCheckService().needsUpdate) return;
    _shown = true;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final colors = AppColors.of(context);
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: colors.card,
            title: Text(
              'Update Required',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            content: Text(
              'A new version of DearDays is available. '
              'Please update to continue using the app.',
              style: GoogleFonts.manrope(
                fontSize: 14,
                color: colors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Update Now',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w600,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
