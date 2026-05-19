import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../recipes/models/course.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/repository/recipe_repository.dart';

/// Batch review screen for external-format imports (Mela, Paprika, etc.).
///
/// Presents every parsed recipe as a row with:
///   - A checkbox to include or exclude the recipe from the import.
///   - An editable course dropdown pre-populated from the parser's suggestion.
///   - The recipe name.
///
/// A Select All / None control appears in the app bar.
/// The Import button at the bottom runs deduplication and saves only the
/// checked recipes, then pops with the count of successfully saved recipes.
///
/// [parseSkipped] reflects entries that failed during parsing (not
/// user-deselected rows) and is displayed as an informational banner.
class ExternalImportReviewScreen extends ConsumerStatefulWidget {
  final List<Recipe> recipes;
  final int parseSkipped;

  const ExternalImportReviewScreen({
    super.key,
    required this.recipes,
    required this.parseSkipped,
  });

  @override
  ConsumerState<ExternalImportReviewScreen> createState() =>
      _ExternalImportReviewScreenState();
}

class _ExternalImportReviewScreenState
    extends ConsumerState<ExternalImportReviewScreen> {
  late List<bool> _checked;
  late List<String> _courses;
  bool _isSaving = false;

  static final _courseOptions = Course.defaults;

  @override
  void initState() {
    super.initState();
    _checked = List.filled(widget.recipes.length, true);
    _courses = widget.recipes.map((r) => r.course).toList();
  }

  int get _selectedCount => _checked.where((v) => v).length;

  void _selectAll() =>
      setState(() => _checked = List.filled(widget.recipes.length, true));

  void _deselectAll() =>
      setState(() => _checked = List.filled(widget.recipes.length, false));

  Future<void> _import() async {
    setState(() => _isSaving = true);

    final repo = ref.read(recipeRepositoryProvider);
    int imported = 0;

    for (int i = 0; i < widget.recipes.length; i++) {
      if (!_checked[i]) continue;

      // Apply the user's course selection before saving
      final recipe = widget.recipes[i];
      recipe.course = _courses[i];

      try {
        final existing = await repo.getRecipeByUuid(recipe.uuid);
        if (existing != null) {
          recipe.version = existing.version + 1;
          recipe.id = existing.id;
        }
        await repo.saveRecipe(recipe, preserveSource: true);
        imported++;
      } catch (e) {
        debugPrint(
          'ExternalImportReviewScreen: failed to save "${recipe.name}" — $e',
        );
        // Continue saving remaining recipes
      }
    }

    if (mounted) Navigator.pop(context, imported);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _selectedCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Review Import (${widget.recipes.length})'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _selectAll,
            child: const Text('All'),
          ),
          TextButton(
            onPressed: _isSaving ? null : _deselectAll,
            child: const Text('None'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.parseSkipped > 0)
            Container(
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${widget.parseSkipped} '
                '${widget.parseSkipped == 1 ? 'entry' : 'entries'} '
                'could not be parsed and will be skipped.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.recipes.length,
              itemBuilder: (context, index) {
                return _RecipeRow(
                  recipe: widget.recipes[index],
                  checked: _checked[index],
                  course: _courses[index],
                  courseOptions: _courseOptions,
                  enabled: !_isSaving,
                  onChecked: (v) =>
                      setState(() => _checked[index] = v ?? false),
                  onCourseChanged: (v) {
                    if (v != null) setState(() => _courses[index] = v);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: (_isSaving || selectedCount == 0) ? null : _import,
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Import $selectedCount '
                    '${selectedCount == 1 ? 'Recipe' : 'Recipes'}',
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row widget
// ---------------------------------------------------------------------------

class _RecipeRow extends StatelessWidget {
  final Recipe recipe;
  final bool checked;
  final String course;
  final List<Course> courseOptions;
  final bool enabled;
  final ValueChanged<bool?> onChecked;
  final ValueChanged<String?> onCourseChanged;

  const _RecipeRow({
    required this.recipe,
    required this.checked,
    required this.course,
    required this.courseOptions,
    required this.enabled,
    required this.onChecked,
    required this.onCourseChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Resolve the dropdown value; fall back to the first available course if
    // the suggested slug is not present in Course.defaults (shouldn't happen,
    // but guards against stale data).
    final validSlug = courseOptions.any((c) => c.slug == course)
        ? course
        : courseOptions.first.slug;

    return CheckboxListTile(
      value: checked,
      onChanged: enabled ? onChecked : null,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        recipe.name.isNotEmpty ? recipe.name : '(Untitled)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: checked
            ? null
            : theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: DropdownButtonFormField<String>(
          value: validSlug,
          isDense: true,
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            border: OutlineInputBorder(),
          ),
          items: courseOptions
              .map(
                (c) => DropdownMenuItem(
                  value: c.slug,
                  child: Text(c.name),
                ),
              )
              .toList(),
          // Disable when row is unchecked or save is in progress
          onChanged: (enabled && checked) ? onCourseChanged : null,
        ),
      ),
    );
  }
}
