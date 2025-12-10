import 'package:flutter/material.dart';
import '../models/recipe.dart';

class IngredientList extends StatefulWidget {
  final List<Ingredient> ingredients;

  const IngredientList({super.key, required this.ingredients});

  @override
  State<IngredientList> createState() => _IngredientListState();
}

class _IngredientListState extends State<IngredientList> {
  final Set<int> _checkedItems = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.ingredients.isEmpty) {
      return const Text(
        'No ingredients listed',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }

    // Group by section if available
    final grouped = _groupBySection(widget.ingredients);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        final section = entry.key;
        final items = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            if (section.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Text(
                  section,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
            // Ingredients
            ...items.map((item) => _buildIngredientRow(context, item)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildIngredientRow(BuildContext context, _IndexedIngredient item) {
    final theme = Theme.of(context);
    final isChecked = _checkedItems.contains(item.index);

    return InkWell(
      onTap: () {
        setState(() {
          if (isChecked) {
            _checkedItems.remove(item.index);
          } else {
            _checkedItems.add(item.index);
          }
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isChecked,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _checkedItems.add(item.index);
                    } else {
                      _checkedItems.remove(item.index);
                    }
                  });
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),

            // Ingredient text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.ingredient.displayText,
                    style: TextStyle(
                      decoration: isChecked ? TextDecoration.lineThrough : null,
                      color: isChecked
                          ? theme.colorScheme.onSurface.withOpacity(0.5)
                          : null,
                    ),
                  ),
                  // Alternative
                  if (item.ingredient.alternative != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.ingredient.alternative!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<_IndexedIngredient>> _groupBySection(List<Ingredient> ingredients) {
    final Map<String, List<_IndexedIngredient>> grouped = {};
    
    for (int i = 0; i < ingredients.length; i++) {
      final ingredient = ingredients[i];
      final section = ingredient.section ?? '';
      grouped.putIfAbsent(section, () => []);
      grouped[section]!.add(_IndexedIngredient(i, ingredient));
    }

    return grouped;
  }
}

class _IndexedIngredient {
  final int index;
  final Ingredient ingredient;

  _IndexedIngredient(this.index, this.ingredient);
}
