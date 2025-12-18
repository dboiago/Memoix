import 'package:flutter/material.dart';
import '../models/recipe.dart';

/// Result of parsing ingredient notes for special patterns
class _ParsedNotes {
  final bool isOptional;
  final String? alternative;
  final String remainingNotes;

  _ParsedNotes({
    required this.isOptional,
    this.alternative,
    required this.remainingNotes,
  });
}

/// Parse notes text to extract optional markers and alternatives
_ParsedNotes _parseNotes(String notes) {
  if (notes.isEmpty) {
    return _ParsedNotes(isOptional: false, remainingNotes: '');
  }

  var remaining = notes;
  var isOptional = false;
  String? alternative;

  // Patterns for optional markers (including common abbreviations)
  final optionalPatterns = [
    RegExp(r'\(optional\)', caseSensitive: false),
    RegExp(r'\(opt\.?\)', caseSensitive: false),
    RegExp(r'^optional$', caseSensitive: false),
    RegExp(r'^opt\.?$', caseSensitive: false),
    RegExp(r',?\s*optional\s*,?', caseSensitive: false),
    RegExp(r',?\s*opt\.?\s*,?', caseSensitive: false),
    RegExp(r';\s*optional\s*;?', caseSensitive: false),
    RegExp(r';\s*opt\.?\s*;?', caseSensitive: false),
  ];

  // Check and remove optional markers
  for (final pattern in optionalPatterns) {
    if (pattern.hasMatch(remaining)) {
      isOptional = true;
      remaining = remaining.replaceAll(pattern, ' ').trim();
    }
  }

  // Patterns for alternative ingredients
  // Matches: "alt: butter", "alternative: butter", "or butter", "or use butter", "substitute: butter"
  final altPatterns = [
    RegExp(r',?\s*alt(?:ernative)?:\s*([^,;]+)', caseSensitive: false),
    RegExp(r',?\s*sub(?:stitute)?:\s*([^,;]+)', caseSensitive: false),
    RegExp(r',?\s*or\s+(?:use\s+)?([^,;]+)', caseSensitive: false),
    RegExp(r'\(or\s+([^)]+)\)', caseSensitive: false),
  ];

  for (final pattern in altPatterns) {
    final match = pattern.firstMatch(remaining);
    if (match != null) {
      alternative = match.group(1)?.trim();
      remaining = remaining.replaceFirst(pattern, ' ').trim();
      break;
    }
  }

  // Clean up remaining text
  // Remove leading/trailing punctuation and separators
  remaining = remaining
      .replaceAll(RegExp(r'^[\s·,;:\-–—]+'), '')  // Leading
      .replaceAll(RegExp(r'[\s·,;:\-–—]+$'), '')  // Trailing
      .replaceAll(RegExp(r'\s*[·]\s*[·]\s*'), ' · ')  // Double separators
      .replaceAll(RegExp(r',\s*,'), ',')  // Double commas
      .replaceAll(RegExp(r';\s*;'), ';')  // Double semicolons
      .replaceAll(RegExp(r'\s{2,}'), ' ')  // Multiple spaces
      .trim();
  
  // Final cleanup: remove any remaining leading/trailing punctuation
  remaining = remaining
      .replaceAll(RegExp(r'^[,;:\s]+'), '')
      .replaceAll(RegExp(r'[,;:\s]+$'), '')
      .trim();

  return _ParsedNotes(
    isOptional: isOptional,
    alternative: alternative,
    remainingNotes: remaining,
  );
}

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
  final bool isCompact;

  const IngredientList({super.key, required this.ingredients, this.isCompact = false});

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
    
    // Compact sizing
    final checkboxSize = widget.isCompact ? 18.0 : 24.0;
    final verticalPadding = widget.isCompact ? 3.0 : 6.0;
    final textStyle = widget.isCompact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium;

    // Build the amount string with proper formatting
    String amountText = '';
    if (ingredient.amount != null && ingredient.amount!.isNotEmpty) {
      amountText = _formatAmount(ingredient.amount!);
      if (ingredient.unit != null && ingredient.unit!.isNotEmpty) {
        amountText += ' ${ingredient.unit}';
      }
    }
    
    // Check for baker's percentage
    final hasBakerPercent = ingredient.bakerPercent != null && ingredient.bakerPercent!.isNotEmpty;
    
    // Combine preparation and alternative fields into raw notes
    final rawNotes = [
      if (ingredient.preparation != null && ingredient.preparation!.isNotEmpty) ingredient.preparation!,
      if (ingredient.alternative != null && ingredient.alternative!.isNotEmpty) ingredient.alternative!,
    ].where((s) => s.isNotEmpty).join(' · ');
    
    // Parse notes to extract optional markers and alternatives
    final parsedNotes = _parseNotes(rawNotes);
    
    // Determine if ingredient is optional (from field OR parsed from notes)
    final isOptional = ingredient.isOptional || parsedNotes.isOptional;
    
    // Get parsed alternative (from notes) or keep the model's alternative field if it's a proper value
    final extractedAlt = parsedNotes.alternative;
    
    // Final notes text after removing optional/alt patterns
    final notesText = parsedNotes.remainingNotes;
    final hasNotes = notesText.isNotEmpty;

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
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            SizedBox(
              width: checkboxSize,
              height: checkboxSize,
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
            SizedBox(width: widget.isCompact ? 4 : 8),

            // Main content - Column for ingredient row + alternative below
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First row: name, amount, badges inline with notes right-aligned
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side: name, amount, and badges (wraps when needed)
                      Expanded(
                        child: Wrap(
                          spacing: widget.isCompact ? 4 : 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Ingredient name
                            Text(
                              _capitalizeWords(ingredient.name),
                              style: textStyle?.copyWith(
                                decoration: isChecked ? TextDecoration.lineThrough : null,
                                color: isChecked
                                    ? theme.colorScheme.onSurface.withOpacity(0.5)
                                    : null,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            
                            // Amount
                            if (amountText.isNotEmpty)
                              Text(
                                amountText,
                                style: textStyle?.copyWith(
                                  decoration: isChecked ? TextDecoration.lineThrough : null,
                                  color: isChecked
                                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),

                            // Baker's percentage badge
                            if (hasBakerPercent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: theme.colorScheme.secondary,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  ingredient.bakerPercent!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                            // Optional badge (from field or parsed from notes)
                            if (isOptional)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: theme.colorScheme.secondary,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'optional',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Right side: Notes (right-justified, wraps when needed)
                      if (hasNotes)
                        Flexible(
                          child: Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                notesText,
                                style: textStyle?.copyWith(
                                  decoration: isChecked ? TextDecoration.lineThrough : null,
                                  color: isChecked
                                      ? theme.colorScheme.onSurface.withOpacity(0.5)
                                      : theme.colorScheme.primary,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  // Second row: Alternative chip (below the ingredient, left-aligned)
                  if (extractedAlt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'alt: $extractedAlt',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
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
