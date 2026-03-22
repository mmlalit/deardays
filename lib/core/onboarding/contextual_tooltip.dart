import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:deardays/core/theme/app_colors.dart';

enum TooltipDirection { above, below, left, right }

/// Small floating tooltip that auto-dismisses after [duration].
/// Calls [onDismiss] with the tooltip ID when dismissed so the notifier can
/// mark it as seen — never re-shows after that.
class ContextualTooltip extends StatefulWidget {
  final String tooltipId;
  final String message;
  final TooltipDirection direction;
  final Duration duration;
  final VoidCallback onDismiss;

  const ContextualTooltip({
    super.key,
    required this.tooltipId,
    required this.message,
    required this.onDismiss,
    this.direction = TooltipDirection.above,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<ContextualTooltip> createState() => _ContextualTooltipState();
}

class _ContextualTooltipState extends State<ContextualTooltip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(widget.duration, () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() {
    _ctrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: _dismiss,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border(
                left: BorderSide(color: colors.accent, width: 3),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.textPrimary.withAlpha(20),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.message,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
