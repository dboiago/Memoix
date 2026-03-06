/// Bottom sheet that displays AI-generated reference information for an
/// ingredient. Handles loading (shimmer), error (snackbar + dismiss), and
/// cached-hit (instant render) states.
///
/// Called from ingredient row long-press in both normal and side-by-side views.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/amount_utils.dart';
import '../../../core/utils/ingredient_categorizer.dart';
import '../../../app/app.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../models/ingredient_reference.dart';
import '../models/recipe.dart';
import '../providers/ingredient_reference_provider.dart';
import '../services/ingredient_reference_service.dart';

/// Units that use 0.25 rounding increments.
const _quarterUnits = {'tsp', 'Tsp', 'tbsp', 'Tbsp'};

/// Units that use 0.5 rounding increments.
const _halfUnits = {'c', 'C', 'cup', 'Cup', 'cups', 'Cups'};

/// Round a substitute amount to the nearest practical cooking increment.
double _roundToPractical(double value, String unit) {
  final lower = unit.toLowerCase();
  if (_quarterUnits.any((u) => u.toLowerCase() == lower)) {
    return (value * 4).round() / 4.0;
  }
  if (_halfUnits.any((u) => u.toLowerCase() == lower)) {
    return (value * 2).round() / 2.0;
  }
  // g/ml over 10: round to whole numbers
  if ((lower == 'g' || lower == 'ml' || lower == 'oz') && value > 10) {
    return value.roundToDouble();
  }
  // Default: round to 1 decimal
  return (value * 10).round() / 10.0;
}

/// Compute display text for a substitution with amount annotation.
///
/// Returns `"Name (2 Tbsp)"` when ratio AND amount AND unit are available,
/// or just `"Name"` otherwise.
String _substitutionDisplay(
  IngredientSubstitution sub,
  Ingredient ingredient,
) {
  if (sub.ratio == null) return sub.name;

  final parsedAmount = AmountUtils.parse(ingredient.amount);
  if (parsedAmount <= 0) return sub.name;

  final unit = ingredient.unit?.trim() ?? '';
  if (unit.isEmpty) return sub.name;

  final computed = parsedAmount * sub.ratio!;
  final rounded = _roundToPractical(computed, unit);
  final formatted = AmountUtils.format(rounded);

  return '${sub.name} ($formatted $unit)';
}

/// Show the ingredient reference bottom sheet.
///
/// On cache hit, opens immediately with data.
/// On cache miss, fetches first — opens sheet only on success; shows snackbar
/// only on error (sheet never opens on error, preventing the flash).
Future<void> showIngredientReferenceSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Ingredient ingredient,
  String? cuisine,
}) async {
  final cache = ref.read(ingredientReferenceCacheProvider.notifier);
  final cached = cache.lookup(ingredient.name);

  if (cached != null && cached.isSuccess) {
    // Cache hit — open sheet immediately with no fetch needed
    _openSheet(context, ingredient, cached.data!);
    return;
  }

  // Cache miss — fetch first, then decide
  final result = await _fetchAndCache(ref, ingredient, cuisine);

  if (!context.mounted) return;

  if (result.isSuccess) {
    _openSheet(context, ingredient, result.data!);
  } else {
    _showErrorSnackbar(context, result);
  }
}

/// Open a bottom sheet that shows shimmer while fetching, then replaces
/// content with data or dismisses on error.
void _openSheetWithLoading(
  BuildContext context,
  WidgetRef ref,
  Ingredient ingredient,
  String? cuisine,
) {
  // Use a ValueNotifier so the StatefulBuilder can react to the fetch result
  final resultNotifier = ValueNotifier<IngredientReferenceResult?>(null);
  final errorNotifier = ValueNotifier<IngredientReferenceResult?>(null);

  // Start the fetch
  _fetchAndCache(ref, ingredient, cuisine).then((result) {
    if (result.isSuccess) {
      resultNotifier.value = result;
    } else {
      errorNotifier.value = result;
    }
  });

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return ValueListenableBuilder<IngredientReferenceResult?>(
        valueListenable: errorNotifier,
        builder: (_, error, __) {
          if (error != null) {
            // Dismiss the sheet and show error snackbar
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(ctx).pop();
              _showErrorSnackbar(context, error);
            });
            // Return empty container while dismissing
            return const SizedBox.shrink();
          }

          return ValueListenableBuilder<IngredientReferenceResult?>(
            valueListenable: resultNotifier,
            builder: (_, result, __) {
              if (result != null && result.isSuccess) {
                return _IngredientReferenceContent(
                  ingredient: ingredient,
                  reference: result.data!,
                );
              }
              // Still loading — show shimmer
              return const _ShimmerLoading();
            },
          );
        },
      );
    },
  );
}

/// Fetch from the service and store in cache.
Future<IngredientReferenceResult> _fetchAndCache(
  WidgetRef ref,
  Ingredient ingredient,
  String? cuisine,
) async {
  final service = ref.read(ingredientReferenceServiceProvider);

  // Classify the ingredient for the category field
  String? category;
  try {
    final cat = IngredientService().classify(ingredient.name);
    if (cat != IngredientCategory.unknown) {
      category = cat.name;
    }
  } catch (_) {
    // Ignore classification errors
  }

  final result = await service.fetchReference(
    ingredientName: ingredient.name,
    category: category,
    cuisine: cuisine,
  );

  // Cache the result (success only)
  if (result.isSuccess) {
    ref.read(ingredientReferenceCacheProvider.notifier)
        .store(ingredient.name, result);
  }

  return result;
}

/// Open the sheet directly with data (cache hit path).
void _openSheet(
  BuildContext context,
  Ingredient ingredient,
  IngredientReference reference,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return _IngredientReferenceContent(
        ingredient: ingredient,
        reference: reference,
      );
    },
  );
}

/// Show error snackbar with copy action — mirrors AI import error pattern.
void _showErrorSnackbar(BuildContext context, IngredientReferenceResult error) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(error.errorMessage ?? 'Unable to fetch ingredient reference'),
      duration: const Duration(seconds: 4),
      action: error.rawError != null
          ? SnackBarAction(
              label: 'Copy',
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: error.rawError!),
                );
              },
            )
          : null,
    ),
  );
}

/// The actual content of the bottom sheet once data is loaded.
class _IngredientReferenceContent extends StatelessWidget {
  final Ingredient ingredient;
  final IngredientReference reference;

  const _IngredientReferenceContent({
    required this.ingredient,
    required this.reference,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAliases = reference.aliases.isNotEmpty;
    final hasSubs = reference.substitutions.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Ingredient name
            Text(
              _capitalizeWords(ingredient.name),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // 2. Description
            Text(
              reference.description,
              style: theme.textTheme.bodyMedium,
            ),

            // 3. Aliases
            if (hasAliases) ...[
              const SizedBox(height: 4),
              Text(
                'Also called: ${reference.aliases.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            // 4. Divider before Flavour
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outline.withOpacity(0.3)),
            const SizedBox(height: 8),

            // 5. Flavour section
            Text(
              'Flavour',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // 6. Flavour text
            Text(
              reference.flavor,
              style: theme.textTheme.bodyMedium,
            ),

            // 7. Divider before Substitutions
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outline.withOpacity(0.3)),
            const SizedBox(height: 8),

            // 8. Substitutions section
            Text(
              'Substitutions',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // 9. Each substitution
            if (hasSubs)
              ...reference.substitutions.map((sub) {
                final display = _substitutionDisplay(sub, ingredient);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('  \u2022  ', style: theme.textTheme.bodyMedium),
                          Expanded(
                            child: Text(
                              display,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (sub.note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 24),
                          child: Text(
                            sub.note,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

            // 10. No substitutions message
            if (!hasSubs)
              Text(
                'No close substitute.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),

            // 11. Disclaimer
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Text(
                'AI suggestions — verify before substituting',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer / skeleton loading placeholder shown while data is being fetched.
class _ShimmerLoading extends StatelessWidget {
  const _ShimmerLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerColor = theme.colorScheme.onSurface.withOpacity(0.08);
    final shimmerHighlight = theme.colorScheme.onSurface.withOpacity(0.04);

    Widget bar(double width, double height) {
      return Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: shimmerColor,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title skeleton
            bar(180, 24),
            const SizedBox(height: 8),
            // Description skeleton
            bar(double.infinity, 14),
            bar(240, 14),
            const SizedBox(height: 4),
            // Aliases skeleton
            bar(200, 12),
            const SizedBox(height: 12),
            Divider(color: shimmerHighlight),
            const SizedBox(height: 8),
            // Section label
            bar(80, 16),
            const SizedBox(height: 4),
            bar(double.infinity, 14),
            bar(180, 14),
            const SizedBox(height: 12),
            Divider(color: shimmerHighlight),
            const SizedBox(height: 8),
            // Section label
            bar(120, 16),
            const SizedBox(height: 4),
            // Substitution skeletons
            bar(200, 14),
            bar(160, 12),
            const SizedBox(height: 4),
            bar(180, 14),
            bar(140, 12),
            const SizedBox(height: 16),
            // Disclaimer skeleton
            bar(220, 10),
          ],
        ),
      ),
    );
  }
}

/// Capitalize the first letter of each word.
String _capitalizeWords(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    final lower = word.toLowerCase();
    if (lower == 'of' ||
        lower == 'and' ||
        lower == 'or' ||
        lower == 'the' ||
        lower == 'a' ||
        lower == 'an' ||
        lower == 'to' ||
        lower == 'for') {
      return lower;
    }
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}
