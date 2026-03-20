import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';

class CookiePolicyScreen extends StatelessWidget {
  const CookiePolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DearDaysHeader.appBar(
        context: context,
        title: 'Cookie & Tracking Policy',
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

            _buildSection(context, '1. About This Policy',
              'This Cookie & Tracking Policy explains how DearDays uses cookies, device identifiers, and similar tracking technologies. It applies to the DearDays mobile application and, where applicable, any web presence.\n\n'
              'This policy is required under the EU ePrivacy Directive, UK PECR (Privacy and Electronic Communications Regulations), and is relevant to users in all countries we serve: US, UK, Canada, India, and the Netherlands.',
            ),

            _buildSection(context, '2. DearDays Is a Mobile App — No Browser Cookies',
              'DearDays is a native mobile application for iOS and Android. We do not use browser cookies.\n\n'
              'Instead of cookies, mobile apps use device-level identifiers and local storage. This policy covers all such technologies used in DearDays.',
            ),

            _buildSection(context, '3. Technologies We Use',
              'We use only the following — no advertising or tracking technologies:\n\n'
              '── Strictly Necessary (no consent required) ──\n\n'
              'Supabase Auth Token\n'
              'Purpose: Keeps you logged in between sessions\n'
              'Storage: iOS Keychain / Android Keystore (secure, on-device)\n'
              'Duration: Until you log out or the session expires (30 days)\n'
              'Third party: Supabase Inc. (USA)\n\n'
              'Hive Local Storage\n'
              'Purpose: Stores your app preferences, offline queue, and cached data locally on your device\n'
              'Storage: On-device only — never transmitted\n'
              'Duration: Until you uninstall the app or clear app data\n'
              'Third party: None — local storage only\n\n'
              'RevenueCat Anonymous Device ID\n'
              'Purpose: Links your subscription status to your device; required for subscription management\n'
              'Storage: On-device; shared with RevenueCat servers\n'
              'Duration: Persistent while the app is installed\n'
              'Third party: RevenueCat Inc. (USA)\n\n'
              '── Functional (consent required for special category data) ──\n\n'
              'AI Response Cache (Hive)\n'
              'Purpose: Caches AI-generated writing prompts and cover images locally to avoid redundant network calls\n'
              'Storage: On-device only\n'
              'Duration: Until app data is cleared\n'
              'Third party: None\n\n'
              '── What We Do NOT Use ──\n\n'
              '• No advertising identifiers (IDFA, GAID)\n'
              '• No cross-app tracking\n'
              '• No social media pixels or SDKs\n'
              '• No analytics SDKs (e.g. Firebase Analytics, Mixpanel, Amplitude)\n'
              '• No third-party crash reporters with PII exposure (Sentry, if used, is configured to scrub PII)\n'
              '• No browser cookies',
            ),

            _buildSection(context, '4. Crash Reporting',
              'If we use a crash reporting service (e.g. Sentry), it collects:\n\n'
              '• Device type and OS version\n'
              '• App version at time of crash\n'
              '• Stack trace of the error\n'
              '• An anonymous session identifier\n\n'
              'Crash reports never contain journal content, email addresses, or any personally identifiable information. PII scrubbing is applied before any data is transmitted.',
            ),

            _buildSection(context, '5. Legal Basis for Each Technology',
              'Under the EU ePrivacy Directive and UK PECR, we require consent for non-essential tracking technologies. Under GDPR, each processing activity needs a lawful basis:\n\n'
              '• Auth token (Supabase): Strictly necessary for the service — no consent required\n'
              '• Local storage (Hive): Strictly necessary — no consent required\n'
              '• RevenueCat device ID: Strictly necessary for subscription management — no consent required\n'
              '• AI cache (Hive): Functional / legitimate interest — improves performance with no privacy impact\n'
              '• Crash reporting: Legitimate interest — essential for service quality; no PII transmitted',
            ),

            _buildSection(context, '6. Your Controls',
              'Since DearDays does not use advertising or tracking technologies, there is no cookie consent banner required.\n\n'
              'You can control data at these levels:\n\n'
              '• Log out: Clears your auth session token\n'
              '• Delete account: Permanently removes all server-side data (Settings → Privacy → Delete My Account)\n'
              '• Uninstall app: Removes all on-device local storage\n'
              '• Disable AI features: Prevents AI cache from being populated (Settings → AI Features)\n'
              '• Opt out of marketing: Settings → Privacy → Marketing Preferences\n\n'
              'There is no option to "reject non-essential cookies" because we do not use any non-essential tracking technologies.',
            ),

            _buildSection(context, '7. Third-Party Links',
              'The App may contain links to external websites (e.g. our Privacy Policy hosted online, App Store pages). These external sites have their own cookie policies, which we do not control. We recommend reviewing the privacy policy of any external site you visit.',
            ),

            _buildSection(context, '8. Netherlands & EU — ePrivacy',
              'DearDays is based in the Netherlands and directly subject to the EU ePrivacy Directive (2002/58/EC) as implemented in Dutch law (Telecommunicatiewet).\n\n'
              'Because we only use strictly necessary and functional technologies with no advertising or profiling purpose, we do not display a cookie consent banner for the mobile app. This is consistent with guidance from the Dutch Data Protection Authority (Autoriteit Persoonsgegevens) and the Article 29 Working Party Opinion 04/2012.',
            ),

            _buildSection(context, '9. UK — PECR',
              'DearDays complies with the UK Privacy and Electronic Communications Regulations (PECR). The same analysis as Section 8 applies: only strictly necessary and functional storage technologies are used, so no explicit consent banner is required for the mobile app.',
            ),

            _buildSection(context, '10. Canada — PIPEDA & Quebec Law 25',
              'Under PIPEDA and Quebec Law 25, we are required to disclose what data we collect and obtain consent for non-essential collection. As described in Section 3, all technologies used are strictly necessary or functional. No additional consent is required beyond account creation.\n\n'
              'Cette politique est disponible en français sur demande à privacy@deardays.app.',
            ),

            _buildSection(context, '11. US — State Privacy Laws',
              'Under CCPA/CPRA, "cookies" that constitute "sharing" personal information for cross-context behavioural advertising require an opt-out mechanism. DearDays does not use any such technologies.\n\n'
              'The "Do Not Sell or Share My Personal Information" toggle in Settings → Privacy applies to any future changes in data practices.',
            ),

            _buildSection(context, '12. India — DPDPA 2023',
              'Under the Digital Personal Data Protection Act 2023, we are required to obtain consent for processing personal data. The device identifiers described in Section 3 are processed under the "necessary for the purposes of the contract" basis. No separate consent is required for these technologies.\n\n'
              'For any tracking-related queries, contact: grievance@deardays.app',
            ),

            _buildSection(context, '13. Changes to This Policy',
              'If we introduce new technologies (e.g. analytics, advertising), we will update this policy and, where required by law, obtain your consent before activating them.\n\n'
              'We will notify you of material changes via in-app notification at least 30 days in advance.',
            ),

            _buildSection(context, '14. Contact',
              'For questions about this policy:\n\n'
              'Email: privacy@deardays.app\n'
              'India Grievance: grievance@deardays.app\n\n'
              'Supervisory authority (Netherlands/EU): Autoriteit Persoonsgegevens — autoriteitpersoonsgegevens.nl\n'
              'Supervisory authority (UK): Information Commissioner\'s Office — ico.org.uk',
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
          const Icon(Icons.block, size: 28, color: AppColors.success),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No advertising or tracking',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DearDays uses no advertising identifiers, analytics SDKs, or cross-app tracking. Only the technologies strictly needed to run the app.',
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
