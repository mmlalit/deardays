import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/core/theme/app_colors.dart';

/// Consistent circular avatar used in every main-tab header.
///
/// Shows the user's first initial (from display name or email).
/// Tapping navigates to [/settings].
class AppAvatar extends ConsumerWidget {
  const AppAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final initial = (profile?.displayName?.isNotEmpty == true
            ? profile!.displayName![0]
            : Supabase.instance.client.auth.currentUser?.email?[0] ?? 'A')
        .toUpperCase();

    return Tooltip(
      message: 'Settings',
      child: GestureDetector(
        onTap: () => context.push('/settings'),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.accent, colors.accentLight],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              initial,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
