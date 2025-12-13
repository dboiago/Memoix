import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../services/url_importer.dart';
import '../models/recipe_import_result.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
import 'import_review_screen.dart';

class URLImportScreen extends ConsumerStatefulWidget {
  const URLImportScreen({super.key});

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
                          'Import from Website',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Paste a URL from a recipe website and we\'ll try to extract the recipe details automatically.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Works best with sites that use structured recipe data.',
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
                hintText: 'https://example.com/recipe/...',
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
                    ],
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

            // Supported sites
            Text(
              'Supported Sites',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SiteBadge(label: 'AllRecipes'),
                _SiteBadge(label: 'Food Network'),
                _SiteBadge(label: 'Serious Eats'),
                _SiteBadge(label: 'Bon Appétit'),
                _SiteBadge(label: 'NYT Cooking'),
                _SiteBadge(label: 'BBC Good Food'),
                _SiteBadge(label: 'Epicurious'),
                _SiteBadge(label: '+ many more'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Basic URL validation
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _errorMessage = 'Please enter a valid URL starting with http:// or https://');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final importer = ref.read(urlImporterProvider);
      final result = await importer.importFromUrl(url);

      if (!mounted) return;

      // Route based on confidence
      if (result.needsUserReview) {
        // Low confidence - show review screen for manual mapping
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ImportReviewScreen(importResult: result),
          ),
        );
      } else {
        // High confidence - go directly to edit screen
        final recipe = result.toRecipe(const Uuid().v4());
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RecipeEditScreen(importedRecipe: recipe),
          ),
        );
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
