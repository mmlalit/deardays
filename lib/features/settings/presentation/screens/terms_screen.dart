import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: DearDaysHeader.appBar(
        context: context,
        title: 'Terms of Service',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLastUpdated(),
            const SizedBox(height: 24),
            _buildSection(
              'Acceptance of Terms',
              'By downloading, installing, or using DearDays ("the App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, please do not use the App.\n\n'
              'DearDays is a personal journaling application designed to help you capture, reflect on, and preserve your life story. These Terms govern your use of the App and any related services.',
            ),
            _buildSection(
              'Account Registration',
              'To use DearDays, you must create an account using a valid email address. You are responsible for:\n\n'
              '\u2022 Maintaining the confidentiality of your account credentials\n'
              '\u2022 All activities that occur under your account\n'
              '\u2022 Notifying us immediately of any unauthorized use\n\n'
              'You must be at least 13 years of age to create an account. If you are under 18, you represent that you have your parent or guardian\'s permission to use the App.',
            ),
            _buildSection(
              'Your Content',
              'You retain full ownership of all content you create within DearDays, including journal entries, voice recordings, and photos ("Your Content"). We do not claim any ownership rights over Your Content.\n\n'
              'Your Content is encrypted using zero-knowledge encryption. This means:\n\n'
              '\u2022 Only you can read your journal entries\n'
              '\u2022 We cannot access, read, or decrypt Your Content\n'
              '\u2022 If you lose your encryption key or password, we cannot recover Your Content\n\n'
              'You are solely responsible for maintaining backups of Your Content.',
            ),
            _buildSection(
              'Acceptable Use',
              'You agree not to:\n\n'
              '\u2022 Use the App for any unlawful purpose\n'
              '\u2022 Attempt to reverse-engineer, decompile, or disassemble the App\n'
              '\u2022 Interfere with or disrupt the App\'s servers or networks\n'
              '\u2022 Use automated systems to access the App without permission\n'
              '\u2022 Share your account credentials with others\n'
              '\u2022 Impersonate another person or entity',
            ),
            _buildSection(
              'Age Requirements & Parental Consent',
              'DearDays enforces age-based access requirements in compliance with applicable laws:\n\n'
              '\u2022 United States & European Union: You must be at least 13 years old (COPPA/GDPR)\n'
              '\u2022 India: You must be at least 18 years old (Digital Personal Data Protection Act 2023)\n'
              '\u2022 Other jurisdictions: You must meet the minimum digital consent age in your country\n\n'
              'If you are under the applicable age threshold, you may not create an account. We verify age during signup and reserve the right to terminate accounts that do not meet age requirements.',
            ),
            _buildSection(
              'Subscriptions & Payments',
              'DearDays offers a free trial period and paid subscription plans:\n\n'
              '\u2022 Free Trial: 30 days of full access, no credit card required\n'
              '\u2022 Monthly Plan: \$3.99/month, billed monthly\n'
              '\u2022 Annual Plan: \$29.99/year, billed annually\n\n'
              'Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current billing period. You can manage and cancel subscriptions through your device\'s app store settings.\n\n'
              'Existing entries remain readable even after your subscription expires. You will not lose access to content you have already created.',
            ),
            _buildSection(
              'Health & Mood Data Processing',
              'DearDays allows you to record mood data alongside journal entries. This data may be classified as health-related information under certain privacy laws (including GDPR Article 9 and the Washington My Health My Data Act).\n\n'
              'By enabling mood tracking, you provide separate, explicit consent for us to process this special category of data. You may withdraw this consent at any time through Settings, which will stop mood data collection going forward.\n\n'
              'We never sell, share, or use your mood/health data for advertising, profiling, or any purpose other than providing the journaling service to you.',
            ),
            _buildSection(
              'Refunds',
              'Refund eligibility is governed by the policies of the Apple App Store or Google Play Store, depending on your platform. We do not process refunds directly. Please contact the relevant app store for refund requests.',
            ),
            _buildSection(
              'Data Export',
              'You may export Your Content at any time in PDF or JSON format through the App\'s export feature. We encourage regular exports as a personal backup strategy.',
            ),
            _buildSection(
              'Service Availability',
              'We strive to keep DearDays available at all times, but we do not guarantee uninterrupted access. We may temporarily suspend the service for maintenance, updates, or circumstances beyond our control.\n\n'
              'We reserve the right to modify, suspend, or discontinue the App at any time. In the event of permanent discontinuation, we will provide at least 90 days\' notice and ensure you can export Your Content.',
            ),
            _buildSection(
              'AI-Generated Content',
              'DearDays offers optional AI features including writing polish, prompts, and weekly summaries. When using these features:\n\n'
              '\u2022 AI-generated or AI-modified content is clearly labeled within the App\n'
              '\u2022 You retain ownership of the original content; AI modifications are derivative works you also own\n'
              '\u2022 AI processing is transient — your content is not stored on AI servers or used to train models\n'
              '\u2022 AI features are entirely optional and can be disabled at any time\n\n'
              'In compliance with the EU AI Act Article 50, all AI-generated content within DearDays is transparently identified with visible badges.',
            ),
            _buildSection(
              'Limitation of Liability',
              'To the maximum extent permitted by law, DearDays and its creators shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the App.\n\n'
              'Our total liability shall not exceed the amount you paid for the App in the 12 months preceding the claim.',
            ),
            _buildSection(
              'International Users',
              'DearDays is available globally. By using the App, you acknowledge that your encrypted data may be transferred to and processed in the United States, where our servers are located.\n\n'
              'For users in the European Economic Area: We rely on Standard Contractual Clauses (SCCs) for data transfers. Your data is encrypted before transfer, providing an additional safeguard.\n\n'
              'For users in India: We comply with the Digital Personal Data Protection Act 2023 (DPDPA). Data processing occurs only with your explicit consent, and you may exercise your rights as a Data Principal through the App or by contacting us.',
            ),
            _buildSection(
              'Changes to Terms',
              'We may update these Terms from time to time. When we make material changes, we will notify you through the App or via email. Your continued use of the App after such changes constitutes acceptance of the updated Terms.',
            ),
            _buildSection(
              'Contact',
              'If you have questions about these Terms, please contact us at:\n\n'
              'support@deardays.app',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            'Last updated: March 1, 2026',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String body) {
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
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}
