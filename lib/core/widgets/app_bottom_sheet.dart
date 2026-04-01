import 'package:flutter/material.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/theme/app_tokens.dart';

/// Standard border radius for all bottom sheets.
const _sheetRadius = BorderRadius.vertical(top: Radius.circular(AppRadius.lg));

/// Shows a modal bottom sheet with standardized styling:
/// - Rounded top corners (20px)
/// - Theme-aware background color
/// - Optional drag handle
/// - SafeArea wrapping
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool showDragHandle = true,
  bool useRootNavigator = true,
  bool isScrollControlled = false,
  bool isDismissible = true,
}) {
  final colors = AppColors.of(context);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    backgroundColor: colors.card,
    shape: const RoundedRectangleBorder(borderRadius: _sheetRadius),
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) const _DragHandle(),
          Flexible(child: builder(sheetCtx)),
        ],
      ),
    ),
  );
}

/// Standard drag handle for bottom sheets.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: colors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
