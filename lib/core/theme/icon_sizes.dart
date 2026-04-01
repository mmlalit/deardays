/// Standardized icon sizes used throughout the app.
///
/// Replaces 25+ ad-hoc icon sizes with 5 consistent values.
/// Map existing sizes to the nearest standard:
///   12-13 → xs (14)
///   14-16 → sm (16)
///   17-19 → md (20)
///   20-22 → lg (24)
///   24-32 → xl (28)
class AppIconSize {
  AppIconSize._();

  /// Extra small — inline text icons, badges, close buttons in chips.
  static const double xs = 14;

  /// Small — secondary actions, metadata icons, status indicators.
  static const double sm = 16;

  /// Medium — standard action icons, nav icons, list item icons.
  static const double md = 20;

  /// Large — primary action icons, header icons, card actions.
  static const double lg = 24;

  /// Extra large — empty state icons, hero illustrations, feature icons.
  static const double xl = 28;
}
