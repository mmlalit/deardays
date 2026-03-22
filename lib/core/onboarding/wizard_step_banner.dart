import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';

/// Shown at the top of entry screens during the guided first-entry wizard.
class WizardStepBanner extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;
  final String instruction;

  const WizardStepBanner({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.instruction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.accent.withAlpha(12),
        border: Border(
            bottom: BorderSide(color: colors.accent.withAlpha(40))),
      ),
      child: Row(
        children: [
          // Step dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(totalSteps, (i) {
              final filled = i < stepNumber;
              return Container(
                margin: const EdgeInsets.only(right: 4),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? colors.accent
                      : colors.accent.withAlpha(40),
                ),
              );
            }),
          ),
          const SizedBox(width: 10),
          // Instruction text
          Expanded(
            child: Text(
              instruction,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.accent,
              ),
            ),
          ),
          // Step counter
          Text(
            '$stepNumber/$totalSteps',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.accent.withAlpha(160),
            ),
          ),
        ],
      ),
    );
  }
}
