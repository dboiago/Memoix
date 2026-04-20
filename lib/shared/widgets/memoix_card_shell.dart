import 'package:flutter/material.dart';

/// A shared card shell used by all entity list cards (Recipe, Cellar, Cheese,
/// Pizza, Sandwich, Smoking, Modernist).
///
/// Encapsulates the hover/press border animation, InkWell gesture handling,
/// and the standard zero-elevation card appearance. The [child] is placed
/// inside a [Padding] whose insets default to the canonical card value
/// (`horizontal: 12, vertical: isCompact ? 6 : 10`) but can be overridden
/// via [padding].
class MemoixCardShell extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool isCompact;

  /// Override the default inner padding. When null, defaults to:
  ///   `EdgeInsets.symmetric(horizontal: 12, vertical: isCompact ? 6 : 10)`
  final EdgeInsetsGeometry? padding;

  /// Optional outer margin applied to the [Card]. Typically null (no extra
  /// margin), but SmokingCard uses `symmetric(horizontal: 16, vertical: 4)`.
  final EdgeInsetsGeometry? margin;

  const MemoixCardShell({
    super.key,
    required this.child,
    this.onTap,
    this.isCompact = false,
    this.padding,
    this.margin,
  });

  @override
  State<MemoixCardShell> createState() => _MemoixCardShellState();
}

class _MemoixCardShellState extends State<MemoixCardShell> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _hovered || _pressed;

    final effectivePadding = widget.padding ??
        EdgeInsets.symmetric(
          horizontal: 12,
          vertical: widget.isCompact ? 6 : 10,
        );

    return Card(
      elevation: 0,
      margin: widget.margin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active
              ? theme.colorScheme.secondary
              : theme.colorScheme.outline.withValues(alpha: 0.12),
          width: active ? 1.5 : 1.0,
        ),
      ),
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hovered = h),
        onHighlightChanged: (p) => setState(() => _pressed = p),
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: effectivePadding,
          child: widget.child,
        ),
      ),
    );
  }
}
