import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The DearDays "dd" logomark — two lowercase d's with an indigo→pink gradient.
///
/// [DdLogo] — bare text mark, use inline or on coloured backgrounds.
/// [DdLogoIcon] — rounded-square icon container (login screen, app icon).
/// [DdLogoWhite] — white version for use on dark/gradient backgrounds.

const _kGradientColors = [Color(0xFF6366F1), Color(0xFFEC4899)];

class DdLogo extends StatelessWidget {
  final double size;
  const DdLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: _kGradientColors,
      ).createShader(bounds),
      child: Text(
        'dd',
        style: GoogleFonts.nunito(
          fontSize: size,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.0,
          letterSpacing: size * -0.04,
        ),
      ),
    );
  }
}

/// White "dd" mark — for use on dark/gradient hero backgrounds.
class DdLogoWhite extends StatelessWidget {
  final double size;
  const DdLogoWhite({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Text(
      'dd',
      style: GoogleFonts.nunito(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        height: 1.0,
        letterSpacing: size * -0.04,
      ),
    );
  }
}

/// Horizontal wordmark: gradient "dd" + "DearDays" text side by side.
/// Use [DdWordmark] on light backgrounds, [DdWordmarkWhite] on dark/gradient.
class DdWordmark extends StatelessWidget {
  final double size; // controls the "dd" height; name scales proportionally
  const DdWordmark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DdLogo(size: size),
        SizedBox(width: size * 0.25),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: _kGradientColors,
          ).createShader(bounds),
          child: Text(
            'DearDays',
            style: GoogleFonts.nunito(
              fontSize: size * 0.52,
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
        SizedBox(width: size * 0.25),
        Text(
          'DearDays',
          style: GoogleFonts.nunito(
            fontSize: size * 0.52,
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

/// Rounded-square app-icon variant — white card with gradient "dd" inside.
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
            color: const Color(0xFF6366F1).withAlpha(50),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(child: DdLogo(size: size * 0.52)),
    );
  }
}
