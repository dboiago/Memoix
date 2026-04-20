import 'package:flutter/material.dart';

/// A consistently styled search [TextField] used across list screens.
///
/// Renders a filled, borderless field with a search prefix icon, hint text,
/// and optional suffix widget (typically a clear button). All colours come
/// from the theme so the widget automatically adapts to light/dark mode.
///
/// For screens that wrap this inside an [Autocomplete.fieldViewBuilder], pass
/// the provided [controller] and [focusNode] through directly.
class MemoixSearchBar extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  /// Optional controller — required when used inside Autocomplete.fieldViewBuilder.
  final TextEditingController? controller;

  /// Optional focus node — required when used inside Autocomplete.fieldViewBuilder.
  final FocusNode? focusNode;

  /// Optional suffix widget, e.g. a clear [IconButton].
  final Widget? suffixIcon;

  const MemoixSearchBar({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      onChanged: onChanged,
    );
  }
}
