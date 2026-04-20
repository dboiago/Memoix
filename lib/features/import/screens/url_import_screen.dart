import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/recipe_import_result.dart';
import '../../../core/services/url_importer.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../modernist/screens/modernist_edit_screen.dart';
import '../../pizzas/screens/pizza_edit_screen.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
import '../../sharing/services/share_service.dart';
import '../../smoking/screens/smoking_edit_screen.dart';
import 'import_review_screen.dart';

/// Courses that have specialized edit screens
/// Add new specialized courses here as they are created
/// 
/// Smoking IS included - routes to SmokingEditScreen with type=recipe for full BBQ recipes.
/// SmokingRecipe has two types: pitNote (quick reference) and recipe (full recipes).
class SpecializedCourses {
  SpecializedCourses._();
  
  static const modernist = 'modernist';
  static const pizzas = 'pizzas';
  static const smoking = 'smoking';
  
  /// Check if a course has a specialized edit screen
  static bool hasSpecializedScreen(String? course) {
    if (course == null) return false;
    final lower = course.toLowerCase();
    return lower == modernist || lower == pizzas || lower == smoking;
  }
  
  /// Route to the appropriate edit screen based on course
  /// Returns the MaterialPageRoute for the specialized screen, or null if should use default
  static Widget? getEditScreen(RecipeImportResult result, String uuid) {
    final course = result.course?.toLowerCase();
    
    switch (course) {
      case modernist:
        return ModernistEditScreen(importedRecipe: result.toModernistRecipe(uuid));
      case pizzas:
        return PizzaEditScreen(importedRecipe: result.toPizzaRecipe(uuid));
      case smoking:
        return SmokingEditScreen(importedRecipe: result.toSmokingRecipeAsFullRecipe(uuid));
      default:
        return null; // Use default RecipeEditScreen
    }
  }
}

class URLImportScreen extends ConsumerStatefulWidget {
  final String? defaultCourse;
  
  /// If true, after saving, navigate to the saved recipe's course list screen.
  /// If false, just pop back to wherever the user came from.
  final bool redirectOnSave;
  
  const URLImportScreen({
    super.key, 
    this.defaultCourse,
    this.redirectOnSave = false,
  });

  @override
  ConsumerState<URLImportScreen> createState() => _URLImportScreenState();
}

class _URLImportScreenState extends ConsumerState<URLImportScreen> {
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from URL'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Import from URL or Share Link',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Paste a recipe website URL or a Memoix share link to import automatically.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Web imports work best with structured recipe data.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // URL input
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Recipe URL',
                hintText: 'https://example.com/recipe/... or memoix://recipe/...',
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _urlController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Error message
            if (_errorMessage != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: InkWell(
                  onTap: () {
                    // Copy error message to clipboard on tap
                    Clipboard.setData(ClipboardData(text: _errorMessage!));
                    MemoixSnackBar.show('Error message copied to clipboard');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.copy,
                          size: 18,
                          color: theme.colorScheme.onErrorContainer.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Import button
            FilledButton.icon(
              onPressed: _isLoading || _urlController.text.isEmpty
                  ? null
                  : _importFromUrl,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_isLoading ? 'Importing...' : 'Import Recipe'),
            ),
            const SizedBox(height: 32),

            // Import Targets
            Text(
              'Import Targets',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SiteBadge(label: 'Editorial Recipe Sites'),
                _SiteBadge(label: 'Chef Blogs'),
                _SiteBadge(label: 'Technique References'),
                _SiteBadge(label: 'Structured Food Articles'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromMemoixLink(String link) async {
    // SECURITY: Enforce QR/deep link max payload size (per AGENTS.md: 4,096 chars)
    if (link.length > 4096) {
      setState(() => _errorMessage = 'Memoix link is too long to be valid (max 4,096 characters).');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shareService = ref.read(shareServiceProvider);
      final recipe = shareService.parseShareLink(link);

      if (!mounted) return;

      if (recipe == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not decode Memoix link. It may be corrupt or from an incompatible version.';
        });
        return;
      }

      // Validate content before navigating (per AGENTS.md recipe validation)
      if (recipe.name.trim().isEmpty && recipe.ingredients.isEmpty && recipe.directions.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'The Memoix link does not contain a valid recipe.';
        });
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecipeEditScreen(importedRecipe: recipe),
        ),
      );

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to decode Memoix link: $e';
        });
      }
    }
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Intercept Memoix proprietary deep links — do NOT attempt web scraping
    if (url.startsWith('memoix://')) {
      await _importFromMemoixLink(url);
      return;
    }

    // Standard web URL validation
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _errorMessage = 'Please enter a valid URL starting with http://, https://, or memoix://');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final importer = UrlRecipeImporter();
      final rawResult = await importer.importFromUrl(url, context: context);
      
      // Apply default course if provided and no course was detected
      final result = widget.defaultCourse != null && rawResult.course == null
          ? rawResult.copyWith(course: widget.defaultCourse)
          : rawResult;

      if (!mounted) return;
      
      // Route based on confidence
      if (result.needsUserReview) {
        // Low confidence - show review screen for manual mapping
        // Use push (not pushReplacement) so back button returns to URL input
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImportReviewScreen(
              importResult: result,
              redirectOnSave: widget.redirectOnSave,
            ),
          ),
        );
      } else {
        // High confidence - go directly to edit screen
        // Route to appropriate screen based on course type
        final uuid = const Uuid().v4();
        final specializedScreen = SpecializedCourses.getEditScreen(result, uuid);
        
        if (specializedScreen != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => specializedScreen),
          );
        } else {
          // Default: use regular RecipeEditScreen
          final recipe = result.toRecipe(uuid);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RecipeEditScreen(importedRecipe: recipe),
            ),
          );
        }
      }
      
      // Reset loading state after navigation so it's ready if user comes back
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to import recipe: $e';
      });
    }
  }
}

class _SiteBadge extends StatelessWidget {
  final String label;

  const _SiteBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
