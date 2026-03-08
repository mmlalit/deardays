import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';

/// EU AI Act Article 50 compliant badge for AI-generated/modified content.
class AiBadge extends StatelessWidget {
  final String label;
  final bool compact;

  const AiBadge({
    super.key,
    this.label = 'AI Generated',
    this.compact = false,
  });

  const AiBadge.polished({super.key})
      : label = 'AI Polished',
        compact = false;

  const AiBadge.generated({super.key})
      : label = 'AI Generated',
        compact = false;

  const AiBadge.compact({super.key})
      : label = 'AI',
        compact = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
        border: Border.all(color: Colors.purple.shade200, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: compact ? 10 : 12,
            color: Colors.purple.shade600,
          ),
          SizedBox(width: compact ? 2 : 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w600,
              color: Colors.purple.shade700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
