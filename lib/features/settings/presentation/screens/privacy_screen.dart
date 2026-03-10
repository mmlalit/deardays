import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DearDaysHeader.appBar(
        context: context,
        title: 'Privacy Policy',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLastUpdated(context),
            const SizedBox(height: 16),
            _buildHighlight(),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Our Privacy Commitment',
              'DearDays is built on the principle that your journal is deeply personal and private. We use zero-knowledge encryption, which means your entries are encrypted on your device before they ever reach our servers. We cannot read, access, or share your journal content — ever.',
            ),
            _buildSection(
              context,
              'Information We Collect',
              'We collect the minimum information necessary to provide our service:\n\n'
              'Account Information:\n'
              '\u2022 Email address (for authentication and account recovery)\n'
              '\u2022 Account creation date\n'
              '\u2022 Subscription status and billing period\n\n'
              'Usage Metadata (non-content):\n'
              '\u2022 Number of entries created (not their content)\n'
              '\u2022 App feature usage (e.g., voice recording, export)\n'
              '\u2022 Device type and operating system version\n'
              '\u2022 App version and crash reports\n\n'
              'What We Do NOT Collect:\n'
              '\u2022 Journal entry content (encrypted; we cannot read it)\n'
              '\u2022 Photos or voice recordings (encrypted on-device)\n'
              '\u2022 Precise location data\n'
              '\u2022 Contacts, calendar, or other device data\n'
              '\u2022 Browsing history or tracking identifiers',
            ),
            _buildSection(
              context,
              'Zero-Knowledge Encryption',
              'All journal content is encrypted using AES-256-GCM encryption with keys derived from your password via PBKDF2 (100,000 iterations). Your encryption key never leaves your device in an unencrypted form.\n\n'
              'This means:\n\n'
              '\u2022 Your entries are encrypted before upload\n'
              '\u2022 Our servers only store encrypted, unreadable data\n'
              '\u2022 We cannot decrypt your data, even if legally compelled\n'
              '\u2022 If you forget your password, we cannot recover your content\n\n'
              'We strongly recommend using the app\'s export feature to maintain personal backups.',
            ),
            _buildSection(
              context,
              'How We Use Your Information',
              '\u2022 Authentication: To verify your identity and protect your account\n'
              '\u2022 Service delivery: To sync your encrypted data across devices\n'
              '\u2022 Billing: To manage your subscription and process payments\n'
              '\u2022 Support: To respond to your help requests\n'
              '\u2022 Improvement: To understand aggregate usage patterns and improve the app\n\n'
              'We never use your information for advertising or sell it to third parties.',
            ),
            _buildSection(
              context,
              'Data Storage & Security',
              'Your encrypted data is stored on Supabase infrastructure with:\n\n'
              '\u2022 Row-Level Security (RLS) ensuring each user can only access their own data\n'
              '\u2022 TLS encryption for all data in transit\n'
              '\u2022 Regular security audits and monitoring\n'
              '\u2022 Automatic backups with geographic redundancy\n\n'
              'Authentication credentials (PIN hash, pattern hash, biometric preference) are stored locally on your device using platform-secure storage (iOS Keychain / Android Keystore).',
            ),
            _buildSection(
              context,
              'Third-Party Services',
              'We use the following third-party services:\n\n'
              '\u2022 Supabase: Database and authentication (hosted in the US)\n'
              '\u2022 Apple / Google: Payment processing for subscriptions\n'
              '\u2022 Google Fonts: Typography (loaded at runtime, no tracking)\n\n'
              'We do not use analytics SDKs, advertising networks, or social media trackers.',
            ),
            _buildSection(
              context,
              'AI Features',
              'DearDays offers optional AI-powered features such as writing prompts, mood insights, and weekly summaries. When you use these features:\n\n'
              '\u2022 Content is sent to our AI service only when you explicitly request it\n'
              '\u2022 AI processing is transient — we do not store your content on AI servers\n'
              '\u2022 AI features are entirely optional and can be disabled\n'
              '\u2022 AI-generated content is never used to train models',
            ),
            _buildSection(
              context,
              'International Data Transfers',
              'DearDays processes data using Supabase infrastructure hosted in the United States. For users in the European Economic Area (EEA), United Kingdom, or other jurisdictions with data transfer restrictions:\n\n'
              '\u2022 We rely on Standard Contractual Clauses (SCCs) approved by the European Commission\n'
              '\u2022 We maintain Data Processing Agreements (DPAs) with all sub-processors\n'
              '\u2022 Your encrypted journal content provides an additional layer of protection — even in transit, your data remains unreadable to us\n\n'
              'For users in India, data processing complies with the Digital Personal Data Protection Act 2023 (DPDPA). We process personal data only with your explicit consent and for the purposes stated in this policy.',
            ),
            _buildSection(
              context,
              'Health & Mood Data',
              'DearDays collects mood data as part of your journal entries. Under GDPR Article 9, mood data may constitute special category (health-related) data. We process this data only with your explicit, separate consent.\n\n'
              'Under the Washington My Health My Data Act and similar US state health privacy laws, we:\n\n'
              '\u2022 Collect mood/health data only with your affirmative consent\n'
              '\u2022 Never sell, share, or monetize your health data\n'
              '\u2022 Allow you to withdraw consent and delete health data at any time\n'
              '\u2022 Do not use health data for advertising or profiling',
            ),
            _buildSection(
              context,
              'Your Rights',
              'You have the right to:\n\n'
              '\u2022 Access: View all data associated with your account\n'
              '\u2022 Export: Download all your data in PDF or JSON format at any time\n'
              '\u2022 Delete: Permanently delete your account and all associated data\n'
              '\u2022 Correct: Update your account information\n'
              '\u2022 Object: Opt out of non-essential data processing\n\n'
              'To exercise these rights, use the in-app settings or contact us at privacy@deardays.app.',
            ),
            _buildSection(
              context,
              'Do Not Sell or Share (CCPA/CPRA)',
              'DearDays does not sell or share your personal information as defined by the California Consumer Privacy Act (CCPA) and California Privacy Rights Act (CPRA).\n\n'
              'You have the right to:\n\n'
              '\u2022 Opt out of the sale or sharing of personal information (we don\'t sell, but you can enable this toggle in Settings)\n'
              '\u2022 Limit the use of sensitive personal information\n'
              '\u2022 Not be discriminated against for exercising your privacy rights\n\n'
              'To exercise these rights, use the "Do Not Sell My Data" toggle in Settings > Privacy, or contact us at privacy@deardays.app.',
            ),
            _buildSection(
              context,
              'Data Retention',
              '\u2022 Active accounts: Data is retained as long as your account is active\n'
              '\u2022 Deleted accounts: All data is permanently deleted within 30 days\n'
              '\u2022 Expired subscriptions: Your encrypted data is retained for 12 months, after which it may be deleted\n\n'
              'You can export your data at any time, regardless of subscription status.',
            ),
            _buildSection(
              context,
              'Age Requirements',
              'DearDays requires users to meet minimum age requirements:\n\n'
              '\u2022 United States and European Union: You must be at least 13 years old\n'
              '\u2022 India: You must be at least 18 years old (per DPDPA 2023)\n'
              '\u2022 Other jurisdictions: You must meet the minimum digital consent age in your country\n\n'
              'We verify age during account creation. If you are a parent or guardian and believe your child has created an account without meeting age requirements, please contact us immediately at privacy@deardays.app.',
            ),
            _buildSection(
              context,
              'Children\'s Privacy',
              'DearDays is not intended for children under 13. We do not knowingly collect personal information from children under 13. If we discover that a child under 13 has created an account, we will promptly delete it.',
            ),
            _buildSection(
              context,
              'Changes to This Policy',
              'We may update this Privacy Policy from time to time. We will notify you of material changes through the App or via email at least 30 days before they take effect. Your continued use of the App constitutes acceptance of the updated policy.',
            ),
            _buildSection(
              context,
              'Contact Us',
              'For privacy-related questions or concerns:\n\n'
              'Email: privacy@deardays.app\n\n'
              'We aim to respond to all privacy inquiries within 72 hours.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.accent.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: colors.accent),
          const SizedBox(width: 10),
          Text(
            'Last updated: March 1, 2026',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlight() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 28, color: AppColors.success),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zero-Knowledge Encryption',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'We cannot read your journal. Your entries are encrypted on your device before reaching our servers.',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: AppColors.success,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String body) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: colors.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
