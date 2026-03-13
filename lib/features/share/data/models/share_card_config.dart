import 'package:flutter/material.dart';

/// Target social platform for the share card.
enum SharePlatform {
  instagram('Instagram Story', 1080, 1920, Icons.camera_alt_rounded),
  whatsapp('WhatsApp', 1080, 1080, Icons.chat_rounded);

  const SharePlatform(this.label, this.width, this.height, this.icon);

  final String label;
  final int width;
  final int height;
  final IconData icon;

  /// Aspect ratio (width / height).
  double get aspectRatio => width / height;

  /// Preview width scaled down to fit on screen (logical pixels).
  double get previewWidth {
    switch (this) {
      case SharePlatform.instagram:
        return 280;
      case SharePlatform.whatsapp:
        return 300;
    }
  }

  double get previewHeight => previewWidth / aspectRatio;
}

/// Visual style for the share card.
enum CardStyle {
  minimal,
  vibrant,
  dark,
  nature,
}

class ShareCardConfig {
  final SharePlatform platform;
  final CardStyle style;
  final String displayText;
  final String? photoUrl;
  final bool showDate;
  final bool showMood;
  final bool showLocation;

  const ShareCardConfig({
    this.platform = SharePlatform.instagram,
    this.style = CardStyle.minimal,
    this.displayText = '',
    this.photoUrl,
    this.showDate = true,
    this.showMood = true,
    this.showLocation = false,
  });

  ShareCardConfig copyWith({
    SharePlatform? platform,
    CardStyle? style,
    String? displayText,
    String? photoUrl,
    bool? showDate,
    bool? showMood,
    bool? showLocation,
  }) {
    return ShareCardConfig(
      platform: platform ?? this.platform,
      style: style ?? this.style,
      displayText: displayText ?? this.displayText,
      photoUrl: photoUrl ?? this.photoUrl,
      showDate: showDate ?? this.showDate,
      showMood: showMood ?? this.showMood,
      showLocation: showLocation ?? this.showLocation,
    );
  }
}
