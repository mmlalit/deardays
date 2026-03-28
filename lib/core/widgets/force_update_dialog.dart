import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/services/version/version_check_service.dart';

/// Shows a non-dismissible dialog when the app version is below the minimum
/// required by the server. Call from the home screen's `initState`.
class ForceUpdateDialog {
  static bool _shown = false;

  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.deardays.app';
  static const _appStoreUrl =
      'https://apps.apple.com/app/deardays/id0000000000'; // TODO: replace with real App Store ID

  static String get _storeUrl =>
      Platform.isIOS ? _appStoreUrl : _playStoreUrl;

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
                onPressed: () async {
                  final uri = Uri.parse(_storeUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    // Fallback: show copyable URL
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Open this URL to update: $_storeUrl'),
                          action: SnackBarAction(
                            label: 'Copy',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _storeUrl));
                            },
                          ),
                          duration: const Duration(seconds: 10),
                        ),
                      );
                    }
                  }
                },
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
