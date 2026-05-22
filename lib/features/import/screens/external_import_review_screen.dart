import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recipes/models/course.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../models/recipe_import_result.dart';
import '../screens/import_review_screen.dart';
import '../services/external_recipe_importer.dart';

// ---------------------------------------------------------------------------
// Row model
// ---------------------------------------------------------------------------

/// Discriminated union for a row in the review list.
sealed class _Row {}

class _SuccessRow extends _Row {
  final Recipe recipe;
  bool checked;
  String course;

  _SuccessRow(this.recipe)
      : checked = true,
        course = recipe.course;
}

class _FailureRow extends _Row {
  final ExternalParseFailure failure;

  _FailureRow(this.failure);
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// Batch review screen for external-format imports (Mela, Paprika, etc.).
///
/// Presents every parsed recipe as a row with:
///   - A checkbox to include or exclude the recipe from the import.
///   - An editable course dropdown pre-populated from the parser's suggestion.
///   - The recipe name.
///
/// Entries that failed during parsing are shown as non-selectable failure rows.
/// If a failure row carries raw text, a "Fix" button launches [ImportReviewScreen]
/// so the user can manually map the entry.  Otherwise a warning icon shows a
/// dialog with the failure reason.
///
/// A Select All / None control appears in the app bar.
/// The Import button at the bottom runs deduplication and saves only the
/// checked recipes, then pops with the count of successfully saved recipes.
class ExternalImportReviewScreen extends ConsumerStatefulWidget {
  final List<Recipe> recipes;
  final int parseSkipped;
  final List<ExternalParseFailure> failures;
  final Uint8List fileBytes;
  final String detectedParserName;

  // ignore: prefer_const_constructors_in_immutables
  ExternalImportReviewScreen({
    super.key,
    required this.recipes,
    required this.parseSkipped,
    required this.fileBytes,
    required this.detectedParserName,
    this.failures = const [],
  });

  @override
  ConsumerState<ExternalImportReviewScreen> createState() =>
      _ExternalImportReviewScreenState();
}

class _ExternalImportReviewScreenState
    extends ConsumerState<ExternalImportReviewScreen> {
  late List<_Row> _rows;
  bool _isSaving = false;
  bool _isReparsing = false;
  bool _noResultsAfterReparse = false;
  int _fixedCount = 0;
  late String _activeParserName;

  static final _courseOptions = Course.defaults;

  @override
  void initState() {
    super.initState();
    _activeParserName = widget.detectedParserName;
    _rows = [
      for (final r in widget.recipes) _SuccessRow(r),
      for (final f in widget.failures) _FailureRow(f),
    ];
  }

  @override
  void dispose() {
    ExternalRecipeImporter.cleanupTempImages(
      _rows.whereType<_SuccessRow>().map((r) => r.recipe).toList(),
    );
    super.dispose();
  }

  int get _selectedCount =>
      _rows.whereType<_SuccessRow>().where((r) => r.checked).length;

  void _selectAll() => setState(() {
        for (final r in _rows.whereType<_SuccessRow>()) {
          r.checked = true;
        }
      });

  void _deselectAll() => setState(() {
        for (final r in _rows.whereType<_SuccessRow>()) {
          r.checked = false;
        }
      });

  Future<void> _import() async {
    setState(() => _isSaving = true);

    final repo = ref.read(recipeRepositoryProvider);
    int imported = 0;
    final notImported = <Recipe>[];

    for (final row in _rows.whereType<_SuccessRow>()) {
      if (!row.checked) {
        notImported.add(row.recipe);
        continue;
      }
      final recipe = row.recipe;
      recipe.course = row.course;

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
      }
    }

    ExternalRecipeImporter.cleanupTempImages(notImported);
    if (mounted) Navigator.pop(context, (imported, _fixedCount));
  }

  Future<void> _reparse(String parserName) async {
    setState(() {
      _isReparsing = true;
      _noResultsAfterReparse = false;
    });
    try {
      final summary = await ExternalRecipeImporter.parseByName(
          parserName, widget.fileBytes);
      if (!mounted) return;
      setState(() {
        _activeParserName = parserName;
        _isReparsing = false;
        _noResultsAfterReparse =
            summary.recipes.isEmpty && summary.failures.isEmpty;
        _fixedCount = 0;
        _rows = [
          for (final r in summary.recipes) _SuccessRow(r),
          for (final f in summary.failures) _FailureRow(f),
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeParserName = parserName;
        _isReparsing = false;
        _noResultsAfterReparse = true;
        _rows = [];
      });
    }
  }

  /// Launch [ImportReviewScreen] for a failure row that has a
  /// [ExternalParseFailure.partialResult] with pre-populated data.
  Future<void> _launchFix(_FailureRow row) async {
    final failure = row.failure;
    if (failure.partialResult == null) return;

    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ImportReviewScreen(importResult: failure.partialResult!),
      ),
    );

    if (!mounted) return;
    if (saved == true) {
      // Recipe was saved — remove the failure row and tally it
      setState(() {
        _rows.remove(row);
        _fixedCount++;
      });
    }
    // null or false: user cancelled — leave row unchanged
  }

  /// Show a dialog with the failure reason for entries without raw text.
  void _showFailureDialog(ExternalParseFailure failure) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(failure.name ?? 'Parse Failure'),
        content: Text(failure.reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final successCount = _rows.whereType<_SuccessRow>().length;
    final failureCount = _rows.whereType<_FailureRow>().length;
    final selectedCount = _selectedCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Review Import ($successCount)'),
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
          _buildFormatOverrideBar(theme),
          if (failureCount > 0 && !_noResultsAfterReparse)
            Container(
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '$failureCount '
                '${failureCount == 1 ? 'entry' : 'entries'} '
                'could not be parsed - shown below.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: _isReparsing
                ? const Center(child: CircularProgressIndicator())
                : _noResultsAfterReparse
                    ? _buildNoResultsMessage(theme)
                    : ListView.builder(
                        itemCount: _rows.length,
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          return switch (row) {
                            _SuccessRow() => _SuccessRowWidget(
                                row: row,
                                courseOptions: _courseOptions,
                                enabled: !_isSaving,
                                onChecked: (v) =>
                                    setState(() => row.checked = v ?? false),
                                onCourseChanged: (v) {
                                  if (v != null) setState(() => row.course = v);
                                },
                              ),
                            _FailureRow() => _FailureRowWidget(
                                row: row,
                                enabled: !_isSaving,
                                onFix: () => _launchFix(row),
                                onWarning: () =>
                                    _showFailureDialog(row.failure),
                              ),
                          };
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

  Widget _buildFormatOverrideBar(ThemeData theme) {
    final names = ExternalRecipeImporter.parserNames;
    final selected = names.contains(_activeParserName) ? _activeParserName : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Text('Detected as', style: theme.textTheme.bodySmall),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: selected,
              isDense: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                border: OutlineInputBorder(),
              ),
              items: names
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (_isReparsing || _isSaving)
                  ? null
                  : (v) {
                      if (v != null && v != _activeParserName) _reparse(v);
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsMessage(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No recipes found with $_activeParserName.',
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This file may not match the selected format. '
              'Select a different format above.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success row widget
// ---------------------------------------------------------------------------

class _SuccessRowWidget extends StatelessWidget {
  final _SuccessRow row;
  final List<Course> courseOptions;
  final bool enabled;
  final ValueChanged<bool?> onChecked;
  final ValueChanged<String?> onCourseChanged;

  const _SuccessRowWidget({
    required this.row,
    required this.courseOptions,
    required this.enabled,
    required this.onChecked,
    required this.onCourseChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final validSlug = courseOptions.any((c) => c.slug == row.course)
        ? row.course
        : courseOptions.first.slug;

    return CheckboxListTile(
      value: row.checked,
      onChanged: enabled ? onChecked : null,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        row.recipe.name.isNotEmpty ? row.recipe.name : '(Untitled)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: row.checked
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
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          onChanged: (enabled && row.checked) ? onCourseChanged : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Failure row widget
// ---------------------------------------------------------------------------

class _FailureRowWidget extends StatelessWidget {
  final _FailureRow row;
  final bool enabled;
  final VoidCallback onFix;
  final VoidCallback onWarning;

  const _FailureRowWidget({
    required this.row,
    required this.enabled,
    required this.onFix,
    required this.onWarning,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure = row.failure;
    final canFix = failure.partialResult != null;
    final muted = theme.colorScheme.onSurfaceVariant;

    return ListTile(
      leading: const SizedBox(width: 24), // align with CheckboxListTile
      title: Text(
        failure.name ?? 'Unknown Recipe',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(color: muted),
      ),
      subtitle: Text(
        failure.reason,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: muted),
      ),
      trailing: canFix
          ? TextButton(
              onPressed: enabled ? onFix : null,
              child: Text(
                'Fix',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            )
          : IconButton(
              icon: Icon(Icons.warning_amber_outlined, color: muted),
              tooltip: 'View failure reason',
              onPressed: onWarning,
            ),
    );
  }
}
