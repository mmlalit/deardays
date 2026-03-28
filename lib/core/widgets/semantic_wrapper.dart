import 'package:flutter/material.dart';

/// Wraps an icon button with proper semantic label for screen readers.
class SemanticIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final double? size;
  final Color? color;

  const SemanticIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: IconButton(
        icon: ExcludeSemantics(
          child: Icon(icon, size: size, color: color),
        ),
        onPressed: onPressed,
      ),
    );
  }
}

/// Wraps a custom toggle (GestureDetector+AnimatedContainer) with switch semantics.
class SemanticToggle extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  const SemanticToggle({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      toggled: value,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: value
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).dividerColor,
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
