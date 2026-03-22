import 'package:flutter/material.dart';

/// Paints a dark overlay with a rounded-rect cutout revealing [targetRect].
/// Uses PathFillType.evenOdd to punch the hole through the overlay.
class SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final double padding;
  final double radius;
  final Color overlayColor;

  const SpotlightPainter({
    this.targetRect,
    this.padding = 12,
    this.radius = 16,
    this.overlayColor = const Color(0xCC000000),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()..addRect(fullRect);

    if (targetRect != null) {
      final spotlight = targetRect!.inflate(padding);
      path.addRRect(
          RRect.fromRectAndRadius(spotlight, Radius.circular(radius)));
      path.fillType = PathFillType.evenOdd;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect;
}
