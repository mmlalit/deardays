import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';

/// Header modes for DearDays screens.
enum HeaderMode {
  /// Top-level tab screen (Home, My Story, Insights, Settings).
  /// No back button, large title.
  topLevel,

  /// Push navigation screen (Edit Profile, Subscription, Privacy, etc.).
  /// Back arrow + centered title.
  push,

  /// Modal/overlay screen (Paywall, Recording).
  /// Close (X) button + centered title.
  modal,
}

/// A shared header widget that ensures design consistency across all screens.
///
/// Usage:
/// ```dart
/// DearDaysHeader(
///   title: 'Settings',
///   mode: HeaderMode.push,
/// )
/// ```
class DearDaysHeader extends StatelessWidget {
  final String title;
  final HeaderMode mode;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final Color? backgroundColor;

  const DearDaysHeader({
    super.key,
    required this.title,
    this.mode = HeaderMode.push,
    this.subtitle,
    this.trailing,
    this.onBack,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          if (mode == HeaderMode.push) _buildBackButton(context),
          if (mode == HeaderMode.modal) _buildCloseButton(context),
          if (mode != HeaderMode.topLevel) const SizedBox(width: 12),
          Expanded(
            child: mode == HeaderMode.topLevel
                ? _buildTopLevelTitle()
                : _buildPushTitle(),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
      color: isDark ? Colors.white : AppColors.textPrimary,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.close, size: 24),
      color: isDark ? Colors.white : AppColors.textPrimary,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildTopLevelTitle() {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final textColor = isDark ? Colors.white : AppColors.textPrimary;
      final subtextColor = isDark ? Colors.white70 : AppColors.textSecondary;

      if (subtitle != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: subtextColor,
              ),
            ),
          ],
        );
      }
      return Text(
        title,
        style: GoogleFonts.playfairDisplay(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      );
    });
  }

  Widget _buildPushTitle() {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final textColor = isDark ? Colors.white : AppColors.textPrimary;
      final subtextColor = isDark ? Colors.white70 : AppColors.textSecondary;

      if (subtitle != null) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: subtextColor,
              ),
            ),
          ],
        );
      }
      return Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      );
    });
  }

  /// Creates an AppBar equivalent for screens that need one.
  static PreferredSizeWidget appBar({
    required BuildContext context,
    required String title,
    HeaderMode mode = HeaderMode.push,
    List<Widget>? actions,
    VoidCallback? onBack,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: mode == HeaderMode.modal
          ? IconButton(
              icon: Icon(Icons.close, size: 24, color: textColor),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          : IconButton(
              icon: Icon(Icons.arrow_back_ios_new, size: 20, color: textColor),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      centerTitle: true,
      actions: actions,
    );
  }
}
