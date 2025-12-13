import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/smoking_url_importer.dart';
import '../screens/smoking_edit_screen.dart';

class SmokingURLImportScreen extends ConsumerStatefulWidget {
  const SmokingURLImportScreen({super.key});

  @override
  ConsumerState<SmokingURLImportScreen> createState() =>
      _SmokingURLImportScreenState();
}

class _SmokingURLImportScreenState
    extends ConsumerState<SmokingURLImportScreen> {
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
        title: const Text('Import Smoking Recipe'),
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
                        Icon(Icons.outdoor_grill,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Import from BBQ Site',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Paste a URL from a BBQ/smoking recipe website and we\'ll extract the smoking details automatically.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We\'ll detect temperature, time, wood type, seasonings, and cooking steps.',
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
                hintText: 'https://amazingribs.com/...',
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
              'Works Great With',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _SiteBadge(label: 'Amazing Ribs'),
                _SiteBadge(label: 'Serious Eats'),
                _SiteBadge(label: 'Hey Grill Hey'),
                _SiteBadge(label: 'Smoked BBQ Source'),
                _SiteBadge(label: 'Traeger'),
                _SiteBadge(label: 'Weber'),
                _SiteBadge(label: '+ any site with recipe data'),
              ],
            ),
            const SizedBox(height: 24),

            // Info about what gets extracted
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What we extract:',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                        Icons.thermostat, 'Temperature', 'Smoking temp'),
                    _buildInfoRow(
                        Icons.timer, 'Time', 'Total cooking duration'),
                    _buildInfoRow(
                        Icons.park, 'Wood', 'Type of wood for smoking'),
                    _buildInfoRow(
                        Icons.restaurant, 'Seasonings', 'Rubs and spices'),
                    _buildInfoRow(
                        Icons.format_list_numbered, 'Directions', 'Steps'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          Text(
            description,
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    // Basic URL validation
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _errorMessage =
          'Please enter a valid URL starting with http:// or https://');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final importer = ref.read(smokingUrlImporterProvider);
      final recipe = await importer.importFromUrl(url);

      if (!mounted) return;

      if (recipe == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not extract a smoking recipe from this URL';
        });
        return;
      }

      // Navigate to edit screen with imported recipe
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SmokingEditScreen(importedRecipe: recipe),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to import recipe: ${e.toString().replaceAll('Exception: ', '')}';
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
