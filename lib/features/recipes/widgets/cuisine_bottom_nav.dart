import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cuisine.dart';

/// Bottom navigation bar showing cuisines grouped by continent
class CuisineBottomNav extends ConsumerWidget {
  final String? selectedCuisine; // null = "All"
  final Function(String?) onCuisineSelected;

  const CuisineBottomNav({
    super.key,
    this.selectedCuisine,
    required this.onCuisineSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        children: [
          // "All" option
          _CuisineChip(
            flag: '🌍',
            code: 'All',
            isSelected: selectedCuisine == null,
            onTap: () => onCuisineSelected(null),
          ),
          const SizedBox(width: 4),
          // Separator
          Container(
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: theme.colorScheme.outlineVariant,
          ),
          // Cuisines by continent
          ...CuisineGroup.all.expand((group) {
            return [
              // Continent label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Text(
                    group.continent.substring(0, 2).toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Cuisines in this continent
              ...group.cuisines.map((cuisine) {
                return _CuisineChip(
                  flag: cuisine.flag,
                  code: cuisine.code,
                  name: cuisine.name,
                  colour: cuisine.colour,
                  isSelected: selectedCuisine == cuisine.code,
                  onTap: () => onCuisineSelected(cuisine.code),
                );
              }),
              const SizedBox(width: 8),
            ];
          }),
        ],
      ),
    );
  }
}

class _CuisineChip extends StatelessWidget {
  final String flag;
  final String code;
  final String? name;
  final Color? colour;
  final bool isSelected;
  final VoidCallback onTap;

  const _CuisineChip({
    required this.flag,
    required this.code,
    this.name,
    this.colour,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: name ?? code,
      child: Material(
        color: isSelected
            ? (colour ?? theme.colorScheme.primary).withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? (colour ?? theme.colorScheme.primary)
                    : theme.colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(flag, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  code,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? (colour ?? theme.colorScheme.primary)
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Expanded cuisine selector as a modal bottom sheet
class CuisineSelectorSheet extends StatelessWidget {
  final String? selectedCuisine;
  final Function(String?) onCuisineSelected;

  const CuisineSelectorSheet({
    super.key,
    this.selectedCuisine,
    required this.onCuisineSelected,
  });

  static void show(
    BuildContext context, {
    String? selectedCuisine,
    required Function(String?) onCuisineSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CuisineSelectorSheet(
        selectedCuisine: selectedCuisine,
        onCuisineSelected: onCuisineSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Select Cuisine',
                      style: theme.textTheme.titleLarge,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        onCuisineSelected(null);
                        Navigator.pop(context);
                      },
                      child: const Text('Show All'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Cuisine list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: CuisineGroup.all.length,
                  itemBuilder: (context, index) {
                    final group = CuisineGroup.all[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Continent header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            group.continent,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Cuisines
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: group.cuisines.map((cuisine) {
                            final isSelected = selectedCuisine == cuisine.code;
                            return ActionChip(
                              avatar: Text(cuisine.flag),
                              label: Text(cuisine.name),
                              backgroundColor: isSelected
                                  ? cuisine.colour.withOpacity(0.2)
                                  : null,
                              side: BorderSide(
                                color: isSelected
                                    ? cuisine.colour
                                    : theme.colorScheme.outlineVariant,
                              ),
                              onPressed: () {
                                onCuisineSelected(cuisine.code);
                                Navigator.pop(context);
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
