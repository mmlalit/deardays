import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DearDaysHeader.appBar(
        context: context,
        title: 'Terms of Service',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLastUpdated(context),
            const SizedBox(height: 24),

            _buildSection(context, '1. Acceptance of Terms',
              'By downloading, installing, or using DearDays ("the App"), you agree to be bound by these Terms of Service ("Terms") and our Privacy Policy. If you do not agree, do not use the App.\n\n'
              'DearDays is operated by DearDays, registered in the Netherlands. These Terms form a legally binding agreement between you and DearDays.',
            ),

            _buildSection(context, '2. Age Requirements',
              'You must meet the minimum age for your country to use DearDays:\n\n'
              '• United States, United Kingdom, Canada: 13 years old minimum\n'
              '• Netherlands and EU member states: 16 years old minimum\n'
              '• India: 18 years old minimum (or verifiable parental consent under DPDPA 2023)\n\n'
              'By creating an account you confirm you meet the minimum age requirement for your country. We verify age at signup. Accounts that do not meet the requirement will be terminated without notice.',
            ),

            _buildSection(context, '3. Account Registration',
              'You must create an account using a valid email address. You are responsible for:\n\n'
              '• Maintaining the confidentiality of your account credentials\n'
              '• All activities that occur under your account\n'
              '• Notifying us immediately of any unauthorised use at support@deardays.app\n\n'
              'One person may not maintain multiple accounts. We reserve the right to terminate duplicate or fraudulent accounts.',
            ),

            _buildSection(context, '4. Your Content',
              'You retain full ownership of all content you create in DearDays, including entries, voice recordings, photos, and memories ("Your Content").\n\n'
              'You grant DearDays a limited, non-exclusive licence to store and transmit Your Content solely to provide the service to you. We claim no ownership and make no other use of Your Content.\n\n'
              'Your Content is encrypted with AES-256 before reaching our servers. We cannot read it. You should use the export feature to maintain personal backups.',
            ),

            _buildSection(context, '5. Acceptable Use',
              'You agree not to:\n\n'
              '• Use the App for any unlawful purpose or in violation of any law\n'
              '• Attempt to reverse-engineer, decompile, or disassemble the App\n'
              '• Interfere with or disrupt the App\'s servers or networks\n'
              '• Use automated systems to access the App without our permission\n'
              '• Share your account credentials with others\n'
              '• Impersonate another person or entity\n'
              '• Upload content that infringes third-party intellectual property rights',
            ),

            _buildSection(context, '6. Subscriptions & Payments',
              'DearDays offers a free trial and paid subscription plans processed through Apple App Store or Google Play:\n\n'
              '• Free Trial: 7 days of full access, no payment required\n'
              '• Monthly Plan: billed monthly (price shown in your local currency at checkout)\n'
              '• Annual Plan: billed yearly (price shown in your local currency at checkout)\n\n'
              'Subscriptions automatically renew unless cancelled at least 24 hours before the end of the current billing period. To cancel:\n'
              '• iOS: Settings → [Your Name] → Subscriptions\n'
              '• Android: Google Play → Subscriptions\n\n'
              'Your existing content remains accessible in read-only mode after your subscription expires. You will not lose access to content you have already created. AI-powered features and the ability to create new entries require an active subscription.',
            ),

            _buildSection(context, '7. EU & UK Right of Withdrawal',
              'If you are in the European Union or United Kingdom, you have a statutory right to withdraw from a subscription purchase within 14 days of the transaction date.\n\n'
              'However, by confirming your consent within the App before completing your purchase — and by beginning to use DearDays premium features immediately — you explicitly request immediate commencement of the service and acknowledge that you waive your 14-day withdrawal right once the service begins, in accordance with EU Consumer Rights Directive Art. 16(m) and the UK Consumer Contracts Regulations 2013 reg. 37. This consent is captured and logged within the App prior to payment.\n\n'
              'This waiver does not affect your rights under Dutch consumer law or any other statutory rights you may have.',
            ),

            _buildSection(context, '8. Refunds',
              'Refund eligibility is governed by the Apple App Store or Google Play Store policies applicable in your country. We do not process refunds directly.\n\n'
              '• Apple: support.apple.com/billing\n'
              '• Google: support.google.com/googleplay/answer/2479637\n\n'
              'EU and UK users: you may be entitled to a refund if the service is not delivered as described. Contact support@deardays.app and we will work with you to resolve the issue.',
            ),

            _buildSection(context, '9. AI Features',
              'DearDays offers optional AI-powered features including writing polish, mood insights, narrative generation, and weekly summaries.\n\n'
              '• AI processing is transient — your content is not stored on AI servers after processing\n'
              '• AI-generated content is never used to train AI models\n'
              '• You retain ownership of AI-modified content as a derivative work\n'
              '• AI features are entirely optional and can be disabled\n\n'
              'Voice transcription: By default, your voice is transcribed entirely on your device with no data sent to any server. If you choose "Use AI Transcription", your audio is sent to OpenAI Whisper for transcription, then permanently deleted. This requires your explicit consent each time.\n\n'
              'In compliance with EU AI Act Article 50, all AI-generated or AI-modified content within DearDays is transparently identified within the App.',
            ),

            _buildSection(context, '10. Health & Mood Data',
              'Mood data you record may be classified as health-related special category data under GDPR Article 9, UK GDPR, and comparable laws.\n\n'
              'By enabling mood tracking, you provide separate explicit consent for us to process this data. You may withdraw this consent at any time via Settings → Privacy → Mood Data Consent, which will stop future mood data collection. Existing mood data will be deleted upon request.\n\n'
              'We never sell, share, or use your mood data for advertising or profiling.',
            ),

            _buildSection(context, '11. Data Export',
              'You may export Your Content at any time in PDF or JSON format via Settings → Export, regardless of your subscription status. We encourage regular exports as a personal backup strategy.',
            ),

            _buildSection(context, '11b. Sharing Your Memories',
              'DearDays allows you to share memories and life books with other users you choose. When you use sharing features:\n\n'
              '• You choose who receives access — DearDays does not share Your Content without your action\n'
              '• You can revoke access at any time via Settings → Sharing\n'
              '• Shared content remains owned by you and subject to these Terms\n'
              '• You are responsible for ensuring you have permission to share content that includes other people',
            ),

            _buildSection(context, '12. Service Availability',
              'We strive to keep DearDays available at all times but do not guarantee uninterrupted access. We may temporarily suspend the service for maintenance or circumstances beyond our control.\n\n'
              'In the event of permanent discontinuation of the App, we will provide at least 90 days\' advance notice and ensure you can export all Your Content before shutdown.',
            ),

            _buildSection(context, '13. Limitation of Liability',
              'To the maximum extent permitted by applicable law, DearDays and its creators shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the App.\n\n'
              'Our total liability shall not exceed the total amount you paid for the App in the 12 months preceding the claim.\n\n'
              'Nothing in these Terms limits our liability for death or personal injury caused by negligence, fraud, or any other liability that cannot be excluded under applicable law, including Dutch consumer law and EU consumer protection regulations.',
            ),

            _buildSection(context, '14. Intellectual Property',
              'The DearDays name, logo, design, and software are owned by DearDays and protected by intellectual property law. You may not use them without our written permission.\n\n'
              'You retain all intellectual property rights in Your Content. We make no claim to Your Content.',
            ),

            _buildSection(context, '15. US Users',
              'For users in the United States, these Terms are in addition to applicable US federal and state laws, including the California Consumer Privacy Act (CCPA/CPRA) and Children\'s Online Privacy Protection Act (COPPA).\n\n'
              'Disputes: Any dispute arising from these Terms shall be resolved by binding arbitration under JAMS rules, except that either party may seek injunctive relief in court. Class action waivers apply to the extent permitted by law.\n\n'
              'Governing law for US users: The laws of the State of California, without regard to conflict-of-law principles.',
            ),

            _buildSection(context, '16. UK Users',
              'For users in the United Kingdom, these Terms are subject to UK law including the UK GDPR, Data Protection Act 2018, and Consumer Rights Act 2015.\n\n'
              'Nothing in these Terms affects your statutory rights as a UK consumer. If any part of these Terms conflicts with UK mandatory consumer protection law, UK law prevails.\n\n'
              'Governing law for UK users: The laws of England and Wales. Disputes may be referred to UK courts.',
            ),

            _buildSection(context, '17. Canadian Users',
              'For users in Canada, these Terms are subject to applicable Canadian federal and provincial laws, including PIPEDA and Quebec Law 25.\n\n'
              'Quebec residents: Cette politique est disponible en français sur demande à support@deardays.app. (This policy is available in French upon request.)\n\n'
              'Marketing messages: We send marketing push notifications and emails only with your express consent (CASL). You may withdraw consent at any time via Settings → Privacy → Marketing Preferences.',
            ),

            _buildSection(context, '18. Indian Users',
              'For users in India, these Terms are subject to the Information Technology Act 2000, the Digital Personal Data Protection Act 2023 (DPDPA), and other applicable Indian laws.\n\n'
              'Grievance Officer: Complaints or concerns about these Terms or our data practices may be submitted to grievance@deardays.app. We acknowledge within 48 hours and resolve within 30 days.\n\n'
              'Governing law for Indian users: The laws of India. Disputes shall be subject to the exclusive jurisdiction of the courts in India.',
            ),

            _buildSection(context, '19. Netherlands & EU Users',
              'For users in the Netherlands and EU, these Terms are subject to Dutch law and applicable EU regulations, including GDPR and the EU Consumer Rights Directive.\n\n'
              'Your statutory rights under Dutch consumer law (Burgerlijk Wetboek) and EU consumer protection law are not affected by these Terms. Where these Terms conflict with mandatory EU or Dutch law, the applicable law prevails.\n\n'
              'Governing law: The laws of the Netherlands. Disputes are subject to the jurisdiction of the courts of Amsterdam, Netherlands, without prejudice to your right to bring proceedings before any other competent court.',
            ),

            _buildSection(context, '20. Changes to Terms',
              'We may update these Terms from time to time. For material changes, we will notify you via in-app notification or email at least 30 days before they take effect.\n\n'
              'Your continued use of the App after that period constitutes acceptance of the updated Terms. If you do not agree to the changes, you may delete your account before they take effect.',
            ),

            _buildSection(context, '21. Contact',
              'General enquiries: support@deardays.app\n'
              'Privacy & data requests: privacy@deardays.app\n'
              'India Grievance Officer: grievance@deardays.app\n\n'
              'We aim to respond to all enquiries within 72 hours.',
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
            'Last updated: March 17, 2026',
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
