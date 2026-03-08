import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/widgets/dear_days_header.dart';
import 'package:deardays/core/providers/subscription_providers.dart';
import 'package:deardays/features/journal/data/repositories/profile_repository.dart';
import 'package:deardays/features/journal/data/models/user_profile.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

enum _Plan { monthly, yearly }

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  late final ProfileRepository _profileRepo = ProfileRepository(
    client: Supabase.instance.client,
  );

  bool _isLoadingProfile = true;
  UserProfile? _profile;
  _Plan _selectedPlan = _Plan.yearly;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileRepo.getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  String get _statusLabel {
    final sub = ref.read(subscriptionProvider);
    if (sub.isPremium) return 'Active';
    if (_profile == null) return 'Unknown';
    if (_profile!.isInTrial) return 'Free Trial';
    return 'Expired';
  }

  Color get _statusColor {
    final sub = ref.read(subscriptionProvider);
    if (sub.isPremium) return Colors.green.shade600;
    if (_profile == null) return Colors.grey;
    if (_profile!.isInTrial) return AppColors.primary;
    return Colors.red.shade600;
  }

  String _planName(bool isPremium, String? activePlan) {
    if (isPremium && activePlan != null) {
      final sub = ref.read(subscriptionProvider);
      return activePlan == 'yearly'
          ? 'Annual (${sub.yearlyPrice}/year)'
          : 'Monthly (${sub.monthlyPrice}/month)';
    }
    if (_profile != null && _profile!.isInTrial) return '30-Day Free Trial';
    return 'No Plan';
  }

  String _expiresLabel(bool isPremium, DateTime? expiresAt) {
    if (isPremium && expiresAt != null) {
      return '${_monthName(expiresAt.month)} ${expiresAt.day}, ${expiresAt.year}';
    }
    if (_profile != null && _profile!.isInTrial) {
      final trialEnd = _profile!.trialStartedAt.add(const Duration(days: 30));
      final remaining = trialEnd.difference(DateTime.now()).inDays;
      return '$remaining days remaining';
    }
    return '--';
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month];
  }

  Future<void> _handleSubscribe() async {
    final notifier = ref.read(subscriptionProvider.notifier);

    bool success;
    if (_selectedPlan == _Plan.yearly) {
      success = await notifier.purchaseYearly();
    } else {
      success = await notifier.purchaseMonthly();
    }

    if (success && mounted) {
      _showInfo('Welcome to DearDays Premium!');
      await _loadProfile();
    }

    final error = ref.read(subscriptionProvider).error;
    if (error != null && mounted) {
      _showError(error);
    }
  }

  Future<void> _handleRestore() async {
    final notifier = ref.read(subscriptionProvider.notifier);
    final restored = await notifier.restorePurchases();

    if (mounted) {
      if (restored) {
        _showInfo('Purchases restored successfully!');
        await _loadProfile();
      } else {
        final error = ref.read(subscriptionProvider).error;
        _showInfo(error ?? 'No previous purchases found.');
      }
    }
  }

  Future<void> _handleCancelSubscription() async {
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Subscription?',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'To cancel, manage your subscription in your device\'s app store settings. '
          'You will keep access until the end of your current billing period.',
          style: GoogleFonts.manrope(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: DearDaysHeader.appBar(
        context: context,
        title: 'Subscription',
      ),
      body: (_isLoadingProfile || sub.isLoading)
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentPlanCard(sub),
                  const SizedBox(height: 28),

                  if (!sub.isPremium) ...[
                    Text(
                      'CHOOSE A PLAN',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade500,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPlanOption(
                      plan: _Plan.yearly,
                      title: '${sub.yearlyPrice} / year',
                      subtitle: 'Save 37% — billed annually',
                      badge: 'BEST VALUE',
                    ),
                    const SizedBox(height: 10),
                    _buildPlanOption(
                      plan: _Plan.monthly,
                      title: '${sub.monthlyPrice} / month',
                      subtitle: 'Billed monthly',
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: sub.isLoading ? null : _handleSubscribe,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary.withAlpha(128),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                                'Subscribe Now',
                                style: GoogleFonts.manrope(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Center(
                      child: TextButton(
                        onPressed: sub.isLoading ? null : _handleRestore,
                        child: Text(
                          'Restore Purchases',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  _buildFeaturesSection(),
                  const SizedBox(height: 28),

                  if (sub.isPremium) ...[
                    Center(
                      child: TextButton(
                        onPressed: _handleCancelSubscription,
                        child: Text(
                          'Cancel Subscription',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  Center(
                    child: Text(
                      'Your existing entries are always readable, free forever.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Manage subscriptions in your device\'s app store settings.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentPlanCard(sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Plan',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _planName(sub.isPremium, sub.activePlan),
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade100),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text(
                sub.isPremium ? 'Renews: ' : 'Trial: ',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                _expiresLabel(sub.isPremium, sub.expiresAt),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOption({
    required _Plan plan,
    required String title,
    required String subtitle,
    String? badge,
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
            color: selected ? AppColors.primary : Colors.grey.shade300,
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
                  color: selected ? AppColors.primary : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(26),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection() {
    const features = [
      {'icon': Icons.all_inclusive, 'text': 'Unlimited journal entries'},
      {'icon': Icons.picture_as_pdf, 'text': 'PDF & print-ready exports'},
      {'icon': Icons.fingerprint, 'text': 'Biometric, PIN & pattern lock'},
      {'icon': Icons.sync, 'text': 'Cross-device sync'},
      {'icon': Icons.auto_awesome, 'text': 'AI writing insights & prompts'},
      {'icon': Icons.shield_outlined, 'text': 'Zero-knowledge encryption'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT\'S INCLUDED',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade500,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(f['icon'] as IconData, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    f['text'] as String,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
