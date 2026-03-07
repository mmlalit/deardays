import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricLockEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildProfileSection(),
              const SizedBox(height: 28),
              _buildSectionLabel('ACCOUNT'),
              _buildSettingsRow(
                icon: Icons.email_outlined,
                label: 'Email',
                trailing: Text(
                  'sarah@example.com',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.lock_outline,
                label: 'Password',
                trailing: Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 22),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.workspace_premium_outlined,
                label: 'Subscription',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Premium Plan',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        color: Colors.grey.shade400, size: 22),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _buildSectionLabel('JOURNALING'),
              _buildSettingsRow(
                icon: Icons.notifications_none_rounded,
                label: 'Daily Reminder',
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '8:30 PM',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF2D2D2D),
                    ),
                  ),
                ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.edit_note_rounded,
                label: 'Writing Style',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Memoir',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        color: Colors.grey.shade400, size: 22),
                  ],
                ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.auto_stories_outlined,
                label: 'Chapter Organization',
                trailing: Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 22),
              ),
              const SizedBox(height: 28),
              _buildSectionLabel('APPEARANCE'),
              _buildThemeSelector(),
              const SizedBox(height: 28),
              _buildSectionLabel('PRIVACY & SECURITY'),
              _buildSettingsRow(
                icon: Icons.fingerprint,
                label: 'Biometric Lock',
                trailing: Switch(
                  value: _biometricLockEnabled,
                  onChanged: (value) {
                    setState(() {
                      _biometricLockEnabled = value;
                    });
                  },
                  activeColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey.shade300,
                ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.enhanced_encryption_outlined,
                label: 'Encryption Info',
                trailing: Icon(Icons.chevron_right,
                    color: Colors.grey.shade400, size: 22),
              ),
              const SizedBox(height: 28),
              _buildSectionLabel('DATA'),
              _buildSettingsRow(
                icon: Icons.download_outlined,
                label: 'Export All Data',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PDF / JSON',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right,
                        color: Colors.grey.shade400, size: 22),
                  ],
                ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.delete_outline,
                label: 'Delete Account',
                labelColor: Colors.red.shade600,
                iconColor: Colors.red.shade600,
                trailing: Icon(Icons.chevron_right,
                    color: Colors.red.shade300, size: 22),
              ),
              const SizedBox(height: 28),
              _buildSectionLabel('ABOUT'),
              _buildSettingsRow(
                icon: Icons.info_outline,
                label: 'Version',
                trailing: Text(
                  '1.2.0',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                trailing: Icon(Icons.open_in_new,
                    color: Colors.grey.shade400, size: 18),
              ),
              _buildDivider(),
              _buildSettingsRow(
                icon: Icons.description_outlined,
                label: 'Terms of Service',
                trailing: Icon(Icons.open_in_new,
                    color: Colors.grey.shade400, size: 18),
              ),
              const SizedBox(height: 36),
              _buildFooter(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.arrow_back_ios_new,
                color: Color(0xFF2D2D2D), size: 22),
          ),
          const SizedBox(width: 16),
          Text(
            'Settings',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D2D2D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.15),
                ),
                alignment: Alignment.center,
                child: Text(
                  'SJ',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgLight, width: 2),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Sarah Jenkins',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D2D2D),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'sarah@example.com',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: Text(
              'Edit Profile',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade400,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String label,
    required Widget trailing,
    Color? labelColor,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                color: iconColor ?? Colors.grey.shade600, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? const Color(0xFF2D2D2D),
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector() {
    final currentTheme = ref.watch(themeProvider).themeColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: AppThemeColor.values.map((palette) {
          final isSelected = palette == currentTheme;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(themeProvider.notifier).setThemeColor(palette),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: palette.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: palette.bg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: isSelected
                            ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 6)]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, size: 16, color: AppColors.primary)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      palette.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppColors.primary : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 28),
          const SizedBox(height: 6),
          Text(
            'DearDays',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
