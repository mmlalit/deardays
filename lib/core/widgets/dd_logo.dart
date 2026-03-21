import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The DearDays sparkle logomark — a 4-pointed star with a purple→teal gradient.
///
/// [DdLogo]          — coloured sparkle, use on light backgrounds.
/// [DdLogoWhite]     — white sparkle, use on dark/gradient backgrounds.
/// [DdWordmark]      — horizontal wordmark: sparkle + "DearDays" text.
/// [DdWordmarkWhite] — white wordmark variant for dark/gradient backgrounds.
/// [DdLogoIcon]      — rounded-square app icon container.

const _kGradientColors = [Color(0xFF7C3AED), Color(0xFF06B6D4)];

class _SparklePainter extends CustomPainter {
  final bool white;
  const _SparklePainter({this.white = false});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width * 0.5;
    final innerR = size.width * 0.10;

    // 4-pointed star via quadratic bezier curves
    final path = Path()
      ..moveTo(cx, cy - outerR)
      ..quadraticBezierTo(cx + innerR, cy - innerR, cx + outerR, cy)
      ..quadraticBezierTo(cx + innerR, cy + innerR, cx, cy + outerR)
      ..quadraticBezierTo(cx - innerR, cy + innerR, cx - outerR, cy)
      ..quadraticBezierTo(cx - innerR, cy - innerR, cx, cy - outerR)
      ..close();

    final paint = Paint()..style = PaintingStyle.fill;
    if (white) {
      paint.color = Colors.white;
    } else {
      paint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _kGradientColors,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    canvas.drawPath(path, paint);

    // Centre dot (coloured version only)
    if (!white) {
      canvas.drawCircle(
        Offset(cx, cy),
        size.width * 0.08,
        Paint()..color = const Color(0xFF2DD4BF),
      );
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.white != white;
}

/// Sparkle logomark with purple→teal gradient. [size] is icon width/height in logical px.
class DdLogo extends StatelessWidget {
  final double size;
  const DdLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _SparklePainter(),
    );
  }
}

/// White sparkle — for use on dark/gradient hero backgrounds.
class DdLogoWhite extends StatelessWidget {
  final double size;
  const DdLogoWhite({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: const _SparklePainter(white: true),
    );
  }
}

/// Horizontal wordmark: gradient sparkle + "DearDays" text side by side.
/// Use on light backgrounds.
class DdWordmark extends StatelessWidget {
  final double size; // controls the sparkle height; text scales proportionally
  const DdWordmark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DdLogo(size: size),
        SizedBox(width: size * 0.35),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: _kGradientColors,
          ).createShader(bounds),
          child: Text(
            'DearDays',
            style: GoogleFonts.nunito(
              fontSize: size * 0.78,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.0,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// White wordmark variant for dark/gradient backgrounds.
class DdWordmarkWhite extends StatelessWidget {
  final double size;
  const DdWordmarkWhite({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DdLogoWhite(size: size),
        SizedBox(width: size * 0.35),
        Text(
          'DearDays',
          style: GoogleFonts.nunito(
            fontSize: size * 0.78,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1.0,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

/// Rounded-square app-icon variant — white card with gradient sparkle inside.
class DdLogoIcon extends StatelessWidget {
  final double size;
  const DdLogoIcon({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withAlpha(50),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(child: DdLogo(size: size * 0.52)),
    );
  }
}
