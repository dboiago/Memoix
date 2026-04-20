import 'package:flutter/material.dart';

/// A styled filter chip used by list screens to filter entries by category.
///
/// Passing [value] as `null` renders an "All" chip. Passing a non-null string
/// renders a chip labelled with that string.
class MemoixFilterChip extends StatelessWidget {
  /// The filter value this chip represents. `null` means "All".
  final String? value;

  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const MemoixFilterChip({
    super.key,
    required this.value,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = value ?? 'All';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: onSelected,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        selectedColor: theme.colorScheme.secondary.withValues(alpha: 0.15),
        showCheckmark: false,
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.secondary
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: isSelected ? 1.5 : 1.0,
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          color: isSelected
              ? theme.colorScheme.secondary
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
