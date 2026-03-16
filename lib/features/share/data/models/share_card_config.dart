import 'package:flutter/material.dart';

/// Target social platform for the share card.
enum SharePlatform {
  instagram('Instagram Story', Icons.camera_alt_rounded, 9, 16),
  whatsapp('WhatsApp Status', Icons.chat_rounded, 1, 1),
  memoryCard('Memory Card', Icons.photo_album_rounded, 4, 5);

  const SharePlatform(this.label, this.icon, this._wRatio, this._hRatio);

  final String label;
  final IconData icon;
  final int _wRatio;
  final int _hRatio;

  /// Aspect ratio (width / height).
  double get aspectRatio => _wRatio / _hRatio;

  /// Render dimensions in logical pixels.
  /// At pixelRatio 3.0, renderWidth = 360 → 1080px output.
  double get renderWidth => 360;
  double get renderHeight => renderWidth / aspectRatio;

  /// Display dimensions on screen (inside phone mockup / card frame).
  double get displayWidth {
    switch (this) {
      case SharePlatform.instagram:
        return 248;
      case SharePlatform.whatsapp:
        return 220;
      case SharePlatform.memoryCard:
        return 200;
    }
  }

  double get displayHeight => displayWidth / aspectRatio;
}

/// Visual style / template for the share card.
enum CardStyle {
  minimal,
  scrapbook,
  dark,
  classic,
}

class ShareCardConfig {
  final SharePlatform platform;
  final CardStyle style;
  final String displayText;
  final String? photoUrl;
  final bool showDate;
  final bool showMood;
  final bool showLocation;
  final Alignment photoAlignment;

  const ShareCardConfig({
    this.platform = SharePlatform.instagram,
    this.style = CardStyle.minimal,
    this.displayText = '',
    this.photoUrl,
    this.showDate = true,
    this.showMood = true,
    this.showLocation = false,
    this.photoAlignment = Alignment.center,
  });

  ShareCardConfig copyWith({
    SharePlatform? platform,
    CardStyle? style,
    String? displayText,
    String? photoUrl,
    bool? showDate,
    bool? showMood,
    bool? showLocation,
    Alignment? photoAlignment,
  }) {
    return ShareCardConfig(
      platform: platform ?? this.platform,
      style: style ?? this.style,
      displayText: displayText ?? this.displayText,
      photoUrl: photoUrl ?? this.photoUrl,
      showDate: showDate ?? this.showDate,
      showMood: showMood ?? this.showMood,
      showLocation: showLocation ?? this.showLocation,
      photoAlignment: photoAlignment ?? this.photoAlignment,
    );
  }
}
