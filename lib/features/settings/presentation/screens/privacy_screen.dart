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
            _buildHighlight(context),
            const SizedBox(height: 24),

            // ── 1. Introduction ──────────────────────────────────────────
            _buildSection(context, '1. Introduction',
              'DearDays ("we", "us", "our") is operated by DearDays, registered in the Netherlands (KVK number on file). This Privacy Policy explains how we collect, use, store, and protect your personal data when you use the DearDays mobile application ("App").\n\n'
              'We are a Data Controller under the EU General Data Protection Regulation (GDPR) and applicable national laws. Because we are based in the Netherlands, the Dutch Data Protection Authority (Autoriteit Persoonsgegevens, autoriteitpersoonsgegevens.nl) is our lead supervisory authority.\n\n'
              'This policy applies to users in: the United States, United Kingdom, Canada, India, and the Netherlands (and all EU member states).',
            ),

            // ── 2. Data We Collect ───────────────────────────────────────
            _buildSection(context, '2. Data We Collect',
              'Account Information:\n'
              '• Email address (for authentication and account recovery)\n'
              '• Date of birth (for age verification only — not stored after verification)\n'
              '• Account creation date and subscription status\n\n'
              'Usage Metadata (non-content):\n'
              '• Number of entries created (not their content)\n'
              '• App feature usage (e.g. voice recording, export, AI features)\n'
              '• Device type, operating system version, app version\n'
              '• Crash reports and error logs\n\n'
              'Mood & Wellbeing Data (special category — separate consent required):\n'
              '• Mood ratings you optionally attach to your entries\n'
              '• Check-in responses\n\n'
              'Voice Data (only with your explicit consent):\n'
              '• Voice recordings are transcribed on your device by default\n'
              '• If you choose "Use AI Transcription", your audio is sent to OpenAI for transcription and immediately deleted — we do not retain the audio file\n\n'
              'What We Do NOT Collect:\n'
              '• Your Content (encrypted; we cannot read it)\n'
              '• Photos (encrypted on device before upload)\n'
              '• Precise location data\n'
              '• Contacts, calendar, or other device data\n'
              '• Browsing history or advertising identifiers',
            ),

            // ── 3. Legal Basis for Processing ────────────────────────────
            _buildSection(context, '3. Legal Basis for Processing (GDPR / UK GDPR)',
              'For users in the EU, UK, and countries applying GDPR-equivalent laws, we process your data on the following legal bases:\n\n'
              '• Contract performance (Art. 6(1)(b)): Account management, service delivery, subscription billing\n'
              '• Legitimate interest (Art. 6(1)(f)): App security, fraud prevention, crash reporting, aggregate usage analytics\n'
              '• Consent (Art. 6(1)(a)): AI features, marketing communications, mood/health data processing\n'
              '• Consent — Special Category (Art. 9(2)(a)): Mood and wellbeing data (you give this separately during onboarding)\n\n'
              'You may withdraw any consent at any time via Settings → Privacy. Withdrawal does not affect processing already carried out.',
            ),

            // ── 4. How We Use Your Data ──────────────────────────────────
            _buildSection(context, '4. How We Use Your Data',
              '• Authentication: To verify your identity and protect your account\n'
              '• Service delivery: To sync your encrypted data across your devices\n'
              '• Billing: To manage your subscription via Apple App Store or Google Play\n'
              '• Support: To respond to your help and privacy requests\n'
              '• Safety: To detect abuse, fraud, or security incidents\n'
              '• Improvement: Aggregate, anonymised usage patterns only — never individual content\n\n'
              'We never use your data for advertising. We never sell your data to third parties.',
            ),

            // ── 5. Encryption & Security ─────────────────────────────────
            _buildSection(context, '5. Encryption & Security',
              'All Your Content is encrypted at rest using AES-256 before it leaves your device. Our servers store only ciphertext — we cannot read your entries.\n\n'
              '• Row Level Security (RLS) ensures only your account can access your data\n'
              '• All data is encrypted in transit via HTTPS/TLS 1.2+\n'
              '• Authentication credentials are stored locally using iOS Keychain / Android Keystore\n'
              '• We perform regular security reviews and maintain access logs\n\n'
              'In the event of a security breach affecting your personal data, we will notify the relevant supervisory authority within 72 hours and affected users without undue delay, as required by GDPR Art. 33–34.',
            ),

            // ── 6. Third-Party Sub-Processors ────────────────────────────
            _buildSection(context, '6. Third-Party Sub-Processors',
              'We share data only with the following trusted sub-processors, each bound by a Data Processing Agreement (DPA):\n\n'
              '• Supabase Inc. (USA) — database, authentication, file storage\n'
              '• OpenAI LLC (USA) — voice transcription (Whisper, only with your explicit consent) and optional AI features\n'
              '• Anthropic PBC (USA) — optional AI features (if active)\n'
              '• Google LLC (USA) — optional AI features via Gemini (if active); Google Fonts typography\n'
              '• RevenueCat Inc. (USA) — subscription management\n'
              '• Apple Inc. / Google LLC — payment processing for in-app subscriptions\n\n'
              'We do not use advertising networks, social media trackers, or analytics SDKs.\n\n'
              'Voice transcription via OpenAI only occurs when you explicitly tap "Use AI Transcription". Your audio is never sent to any server without your active choice.',
            ),

            // ── 7. International Data Transfers ──────────────────────────
            _buildSection(context, '7. International Data Transfers',
              'Our sub-processors are based in the United States. For users in the EU, UK, and countries with transfer restrictions, we ensure adequate protection through:\n\n'
              '• EU Standard Contractual Clauses (SCCs, Commission Decision 2021/914) — covering transfers to Supabase, OpenAI, RevenueCat, and Google\n'
              '• UK International Data Transfer Agreements (IDTA) — for UK users post-Brexit\n'
              '• Additional safeguard: Your Content is encrypted before transfer, so even in transit it is unreadable to sub-processors\n\n'
              'For Indian users, data processing complies with the Digital Personal Data Protection Act 2023. Cross-border transfers occur to the US under your explicit consent per DPDPA Section 16.',
            ),

            // ── 8. Mood & Health Data ────────────────────────────────────
            _buildSection(context, '8. Mood & Health Data',
              'Mood data may constitute health-related special category data under GDPR Article 9 and comparable laws (UK GDPR, Washington My Health My Data Act).\n\n'
              'We process mood data only with your separate, explicit consent given during onboarding. You can withdraw this consent at any time in Settings → Privacy → Mood Data Consent.\n\n'
              '• We never sell, share, or use mood data for advertising or profiling\n'
              '• Mood data is encrypted along with Your Content\n'
              '• Withdrawal of consent stops future mood data collection; existing data is deleted on request',
            ),

            // ── 9. Your Rights ───────────────────────────────────────────
            _buildSection(context, '9. Your Rights',
              'Depending on your country, you have some or all of the following rights:\n\n'
              'Right to Access — Request a copy of all data we hold about you\n'
              'Right to Rectification — Correct inaccurate personal data\n'
              'Right to Erasure — Delete your account and all associated data\n'
              'Right to Portability — Export your data in JSON or PDF format\n'
              'Right to Restriction — Limit how we process your data\n'
              'Right to Object — Opt out of processing based on legitimate interest\n'
              'Right to Withdraw Consent — For any consent-based processing\n\n'
              'Response times:\n'
              '• EU / UK / Netherlands / Canada: within 30 days\n'
              '• US (CCPA): within 45 days\n'
              '• India (DPDPA): within 30 days\n\n'
              'To exercise any right: use Settings → Privacy, or email privacy@deardays.app.',
            ),

            // ── 10. CCPA / CPRA — US Users ──────────────────────────────
            _buildSection(context, '10. US Users — CCPA / CPRA (California)',
              'DearDays does not sell or share your personal information as defined by the California Consumer Privacy Act (CCPA) and California Privacy Rights Act (CPRA).\n\n'
              'Categories of personal information collected: Identifiers (email), usage data, mood data (sensitive), device information.\n\n'
              'Your California rights:\n'
              '• Know what personal information is collected and how it is used\n'
              '• Delete your personal information\n'
              '• Opt out of the sale or sharing of personal information (we do not sell, but you can enable the toggle in Settings → Privacy → Do Not Sell My Data)\n'
              '• Limit use of sensitive personal information\n'
              '• Non-discrimination for exercising your rights\n\n'
              'To submit a verifiable consumer request: privacy@deardays.app. We respond within 45 days.\n\n'
              'Under the Washington My Health My Data Act and similar state health privacy laws: we collect mood/health data only with affirmative consent and never use it for advertising.',
            ),

            // ── 11. UK Users ─────────────────────────────────────────────
            _buildSection(context, '11. UK Users — UK GDPR',
              'DearDays complies with the UK General Data Protection Regulation (UK GDPR) and the Data Protection Act 2018.\n\n'
              'Your UK rights mirror those in Section 9 above. To lodge a complaint with the UK supervisory authority:\n\n'
              'Information Commissioner\'s Office (ICO)\n'
              'ico.org.uk/make-a-complaint\n'
              'Telephone: 0303 123 1113\n\n'
              'Data transfers from the UK to the US are covered by UK International Data Transfer Agreements (IDTA) with each sub-processor.',
            ),

            // ── 12. Canadian Users ───────────────────────────────────────
            _buildSection(context, '12. Canadian Users — PIPEDA & Quebec Law 25',
              'DearDays complies with Canada\'s Personal Information Protection and Electronic Documents Act (PIPEDA) and Quebec\'s Law 25 (Act respecting the protection of personal information in the private sector).\n\n'
              'Under PIPEDA, you have the right to access and correct your personal information. Contact: privacy@deardays.app.\n\n'
              'Under Quebec Law 25 (effective September 2023):\n'
              '• You have the right to data portability (export your data in a structured format)\n'
              '• You have the right to be informed of any automated decision-making\n'
              '• You may withdraw consent at any time\n'
              '• This policy is available in French (Politique de confidentialité) upon request\n\n'
              'Our sub-processors processing Canadian user data are listed in Section 6. All are located in the United States; transfers occur under contractual safeguards.\n\n'
              'Marketing communications (push notifications, emails) are sent only with your express consent, in compliance with Canada\'s Anti-Spam Legislation (CASL). You may withdraw marketing consent at any time in Settings → Privacy → Marketing Preferences.',
            ),

            // ── 13. Indian Users ─────────────────────────────────────────
            _buildSection(context, '13. Indian Users — DPDPA 2023',
              'DearDays complies with India\'s Digital Personal Data Protection Act 2023 (DPDPA). We act as a Data Fiduciary in relation to Indian users\' personal data.\n\n'
              'Minimum age: You must be at least 18 years old to use DearDays in India. Users under 18 require verifiable parental consent.\n\n'
              'Your rights as a Data Principal under DPDPA:\n'
              '• Right to access information about your personal data\n'
              '• Right to correction and erasure\n'
              '• Right to grievance redressal (see Grievance Officer below)\n'
              '• Right to nominate another person to exercise rights on your behalf\n\n'
              'Grievance Officer (India):\n'
              'Name: DearDays Privacy Team\n'
              'Email: grievance@deardays.app\n'
              'Grievances are acknowledged within 48 hours and resolved within 30 days.\n\n'
              'Cross-border data transfer: Your personal data is processed in the United States under your explicit consent per DPDPA Section 16.',
            ),

            // ── 14. Netherlands & EU Users ───────────────────────────────
            _buildSection(context, '14. Netherlands & EU Users — GDPR',
              'As a Netherlands-based company, DearDays is directly subject to the EU General Data Protection Regulation (GDPR). Our lead supervisory authority is:\n\n'
              'Autoriteit Persoonsgegevens (AP)\n'
              'autoriteitpersoonsgegevens.nl\n'
              'Telephone: +31 (0)70 888 85 00\n\n'
              'Minimum age in the Netherlands: You must be at least 16 years old to use DearDays (the Netherlands set the GDPR digital consent age at 16).\n\n'
              'You have the right to lodge a complaint with the AP at any time. We encourage you to contact us first at privacy@deardays.app so we can resolve your concern directly.',
            ),

            // ── 15. Data Retention ───────────────────────────────────────
            _buildSection(context, '15. Data Retention',
              '• Active accounts: Data is retained for as long as your account is active\n'
              '• Deleted accounts: All personal data is permanently purged within 30 days of account deletion\n'
              '• Expired subscriptions: Encrypted content is retained for 12 months, then deleted if the account remains inactive\n'
              '• Consent audit logs: Retained for 5 years (legal obligation to demonstrate consent)\n'
              '• Crash logs and error reports: Retained for 90 days\n\n'
              'You can export your data at any time regardless of subscription status via Settings → Export.',
            ),

            // ── 16. Age Requirements ─────────────────────────────────────
            _buildSection(context, '16. Age Requirements',
              '• United States, United Kingdom, Canada: 13 years minimum (COPPA / UK GDPR / PIPEDA)\n'
              '• Netherlands and EU: 16 years minimum (GDPR, as set by the Netherlands)\n'
              '• India: 18 years minimum, or verifiable parental consent (DPDPA 2023)\n\n'
              'We verify age during account creation. If you believe a child has created an account without meeting the minimum age, contact privacy@deardays.app immediately.',
            ),

            // ── 17. Children's Privacy ───────────────────────────────────
            _buildSection(context, '17. Children\'s Privacy',
              'DearDays does not knowingly collect personal data from anyone below the minimum age for their country. If we discover an underage account, we will delete it promptly without retention.\n\n'
              'Parents or guardians who believe their child has provided personal data without consent should contact privacy@deardays.app.',
            ),

            // ── 18. Cookies & Tracking ───────────────────────────────────
            _buildSection(context, '18. Cookies & Tracking',
              'DearDays is a mobile app. We do not use browser cookies.\n\n'
              'On-device identifiers used:\n'
              '• RevenueCat anonymous device ID — used solely to manage your subscription; not linked to advertising\n'
              '• Crash reporting identifier — used only to group crash reports from the same device\n\n'
              'We do not use advertising identifiers (IDFA/GAID), social media pixels, or cross-app tracking. See our Cookie & Tracking Policy in Settings for full details.',
            ),

            // ── 19. Changes to This Policy ───────────────────────────────
            _buildSection(context, '19. Changes to This Policy',
              'We will notify you of material changes via in-app notification or email at least 30 days before they take effect. The "Last updated" date at the top of this policy reflects the most recent revision.\n\n'
              'If changes are material (new purposes, new data types, new third parties), we will ask for your fresh consent where required by law.',
            ),

            // ── 20. Contact ──────────────────────────────────────────────
            _buildSection(context, '20. Contact Us',
              'For all privacy-related questions, data subject requests, or complaints:\n\n'
              'Email: privacy@deardays.app\n'
              'Grievances (India): grievance@deardays.app\n\n'
              'We aim to respond to all privacy enquiries within 72 hours and to resolve them within the legally required timeframe for your country.',
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

  Widget _buildHighlight(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 28, color: AppColors.success),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your memories are private by design',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your memories are encrypted with AES-256 before leaving your device. We cannot read your content. Voice is transcribed on-device by default — AI transcription is always your choice.',
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
