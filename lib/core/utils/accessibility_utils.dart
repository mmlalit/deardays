import 'package:flutter/material.dart';

/// Minimum touch target size per WCAG guidelines (44x44 logical pixels).
const double kMinTouchTarget = 44.0;

/// Wraps a widget to ensure minimum touch target size.
class MinTouchTarget extends StatelessWidget {
  final Widget child;
  final double minSize;

  const MinTouchTarget({
    super.key,
    required this.child,
    this.minSize = kMinTouchTarget,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      child: child,
    );
  }
}

/// Checks if the user has enabled reduced motion.
bool shouldReduceMotion(BuildContext context) {
  return MediaQuery.of(context).disableAnimations;
}
