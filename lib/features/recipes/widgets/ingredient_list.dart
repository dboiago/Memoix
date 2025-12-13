import 'package:flutter/material.dart';
import '../models/recipe.dart';

/// Capitalize the first letter of each word in a string
String _capitalizeWords(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    // Don't capitalize common lowercase words in the middle
    final lower = word.toLowerCase();
    if (lower == 'of' || lower == 'and' || lower == 'or' || lower == 'the' || lower == 'a' || lower == 'an' || lower == 'to' || lower == 'for') {
      return lower;
    }
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

/// Format amount to clean up decimals and display fractions
String _formatAmount(String amount) {
  var result = amount.trim();
  
  // Remove trailing .0 from whole numbers (e.g., "2.0" -> "2")
  result = result.replaceAllMapped(
    RegExp(r'(\d+)\.0(?=\s|$|-|–)'),
    (match) => match.group(1)!,
  );
  // Handle standalone .0
  if (result.endsWith('.0')) {
    result = result.substring(0, result.length - 2);
  }
  
  // Convert common decimal fractions to unicode fractions
  final fractionMap = {
    '.5': '½',
    '.25': '¼',
    '.75': '¾',
    '.33': '⅓',
    '.333': '⅓',
    '.67': '⅔',
    '.667': '⅔',
    '.125': '⅛',
    '.375': '⅜',
    '.625': '⅝',
    '.875': '⅞',
  };
  
  // Replace decimal fractions with unicode
  for (final entry in fractionMap.entries) {
    // Handle "1.5" -> "1½"
    result = result.replaceAllMapped(
      RegExp('(\\d+)${RegExp.escape(entry.key)}(?=\\s|\$|-|–)'),
      (match) => '${match.group(1)}${entry.value}',
    );
    // Handle standalone ".5" -> "½"
    if (result == entry.key || result.startsWith('${entry.key} ')) {
      result = result.replaceFirst(entry.key, entry.value);
    }
  }
  
  // Also convert text fractions like "1/2" to "½"
  final textFractionMap = {
    '1/2': '½',
    '1/4': '¼',
    '3/4': '¾',
    '1/3': '⅓',
    '2/3': '⅔',
    '1/8': '⅛',
    '3/8': '⅜',
    '5/8': '⅝',
    '7/8': '⅞',
  };
  
  for (final entry in textFractionMap.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  
  return result;
}

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
    final ingredient = item.ingredient;

    // Build the amount string with proper formatting
    String amountText = '';
    if (ingredient.amount != null && ingredient.amount!.isNotEmpty) {
      amountText = _formatAmount(ingredient.amount!);
      if (ingredient.unit != null && ingredient.unit!.isNotEmpty) {
        amountText += ' ${ingredient.unit}';
      }
    }
    
    // Get preparation and alternative separately
    final hasPreparation = ingredient.preparation != null && ingredient.preparation!.isNotEmpty;
    final hasAlternative = ingredient.alternative != null && ingredient.alternative!.isNotEmpty;
    final hasNotes = hasPreparation || hasAlternative;
    
    final notesText = [
      if (hasPreparation) ingredient.preparation!,
      if (hasAlternative) ingredient.alternative!,
    ].where((s) => s.isNotEmpty).join(' · ');

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

            // Ingredient name
            Text(
              _capitalizeWords(ingredient.name),
              style: TextStyle(
                decoration: isChecked ? TextDecoration.lineThrough : null,
                color: isChecked
                    ? theme.colorScheme.onSurface.withOpacity(0.5)
                    : null,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            // Amount (with minimal spacing)
            if (amountText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                amountText,
                style: TextStyle(
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  color: isChecked
                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            // Optional badge
            if (ingredient.isOptional) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'optional',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            // Notes/alternatives - Expanded ensures it fills remaining space
            // and textAlign: right pushes text to the right edge
            Expanded(
              child: hasNotes
                  ? Text(
                      notesText,
                      style: TextStyle(
                        decoration: isChecked ? TextDecoration.lineThrough : null,
                        color: isChecked
                            ? theme.colorScheme.onSurface.withOpacity(0.5)
                            : theme.colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.right,
                    )
                  : const SizedBox.shrink(),
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
