import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';
import 'package:deardays/core/providers/subscription_providers.dart';
import 'package:deardays/features/settings/presentation/screens/terms_screen.dart';
import 'package:deardays/features/settings/presentation/screens/privacy_screen.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

enum _Plan { yearly, monthly }

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  _Plan _selectedPlan = _Plan.yearly;

  Future<void> _handleSubscribe() async {
    final notifier = ref.read(subscriptionProvider.notifier);

    bool success;
    if (_selectedPlan == _Plan.yearly) {
      success = await notifier.purchaseYearly();
    } else {
      success = await notifier.purchaseMonthly();
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Welcome to DearDays Premium!'),
          backgroundColor: const Color(0xFF111111),
        ),
      );
      Navigator.of(context).pop(true);
    }

    final error = ref.read(subscriptionProvider).error;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    final notifier = ref.read(subscriptionProvider.notifier);
    final restored = await notifier.restorePurchases();

    if (mounted) {
      if (restored) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Purchases restored!'),
            backgroundColor: const Color(0xFF111111),
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No previous purchases found.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close, size: 24, color: AppColors.of(context).textPrimary),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  ),
                  Text(
                    'DearDays',
                    style: GoogleFonts.manrope(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.of(context).textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // Headline
                    Text(
                      'Your story has\n30 pages.\nKeep writing?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: AppColors.of(context).textPrimary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Book preview mockup
                    _buildBookPreview(),
                    const SizedBox(height: 32),

                    // Feature checkmarks
                    _buildFeatureGrid(),
                    const SizedBox(height: 32),

                    // Pricing cards — use real prices from RevenueCat
                    _buildPricingCard(
                      plan: _Plan.yearly,
                      title: '${sub.yearlyPrice} / year',
                      subtitle: 'Billed annually',
                      badgeText: 'BEST VALUE',
                      label: 'MOST POPULAR',
                    ),
                    const SizedBox(height: 12),
                    _buildPricingCard(
                      plan: _Plan.monthly,
                      title: '${sub.monthlyPrice} / month',
                      subtitle: 'Billed monthly',
                    ),
                    const SizedBox(height: 28),

                    // CTA button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: sub.isLoading ? null : _handleSubscribe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111111),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.of(context).accent.withAlpha(128),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: sub.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Continue my story \u2192',
                                style: GoogleFonts.manrope(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Restore purchases
                    TextButton(
                      onPressed: sub.isLoading ? null : _handleRestore,
                      child: Text(
                        'Restore Purchases',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.of(context).accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Footer
                    Text(
                      'Your existing entries are always readable, free forever.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppColors.of(context).textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const TermsScreen()),
                          ),
                          child: Text(
                            'Terms',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppColors.of(context).textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'and',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppColors.of(context).textMuted,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PrivacyScreen()),
                          ),
                          child: Text(
                            'Privacy Policy',
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: AppColors.of(context).textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Book preview mockup
  Widget _buildBookPreview() {
    return Center(
      child: Transform.rotate(
        angle: -0.06,
        child: Container(
          width: 200,
          height: 260,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                blurRadius: 20,
                offset: const Offset(4, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _placeholderLine(0.9),
              const SizedBox(height: 8),
              _placeholderLine(0.75),
              const SizedBox(height: 8),
              _placeholderLine(0.85),
              const SizedBox(height: 8),
              _placeholderLine(0.6),
              const Spacer(),
              Text(
                'Chapter 3: The Golden Hour',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppColors.of(context).textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Page 30',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: AppColors.of(context).textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderLine(double widthFactor) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  // Feature grid
  Widget _buildFeatureGrid() {
    const features = [
      'Unlimited entries',
      'PDF exports',
      'Biometric lock',
      'Device sync',
    ];
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      children: features.map((f) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 24 * 2 - 16) / 2,
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  f,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.of(context).textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Pricing card
  Widget _buildPricingCard({
    required _Plan plan,
    required String title,
    required String subtitle,
    String? badgeText,
    String? label,
  }) {
    final selected = _selectedPlan == plan;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.of(context).accent : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.of(context).accent : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.of(context).accent,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.of(context).textPrimary,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.of(context).accent.withAlpha(38),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.of(context).accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.of(context).textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (label != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.of(context).accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
