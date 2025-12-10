import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../sharing/services/share_service.dart';

class ShareRecipeScreen extends ConsumerStatefulWidget {
  final String? recipeId;

  const ShareRecipeScreen({super.key, this.recipeId});

  @override
  ConsumerState<ShareRecipeScreen> createState() => _ShareRecipeScreenState();
}

class _ShareRecipeScreenState extends ConsumerState<ShareRecipeScreen> {
  Recipe? _selectedRecipe;
  String? _shareLink;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    if (widget.recipeId != null) {
      _loadRecipe(widget.recipeId!);
    }
  }

  Future<void> _loadRecipe(String recipeId) async {
    final repo = ref.read(recipeRepositoryProvider);
    final recipe = await repo.getRecipeByUuid(recipeId);
    if (recipe != null) {
      setState(() => _selectedRecipe = recipe);
      _generateShareLink();
    }
  }

  Future<void> _generateShareLink() async {
    if (_selectedRecipe == null) return;

    setState(() => _isGenerating = true);

    try {
      final shareService = ref.read(shareServiceProvider);
      final link = await shareService.generateShareLink(_selectedRecipe!);
      setState(() {
        _shareLink = link;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate link: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Recipe'),
      ),
      body: _selectedRecipe == null
          ? _buildRecipeSelector()
          : _buildShareOptions(theme),
    );
  }

  Widget _buildRecipeSelector() {
    final recipesAsync = ref.watch(allRecipesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select a recipe to share',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: recipesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (recipes) {
              if (recipes.isEmpty) {
                return const Center(child: Text('No recipes to share'));
              }
              return ListView.builder(
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  return ListTile(
                    title: Text(recipe.name),
                    subtitle: Text(recipe.course ?? ''),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      setState(() => _selectedRecipe = recipe);
                      _generateShareLink();
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShareOptions(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Recipe preview
          Card(
            child: ListTile(
              title: Text(
                _selectedRecipe!.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(_selectedRecipe!.course ?? ''),
              trailing: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedRecipe = null;
                    _shareLink = null;
                  });
                },
                child: const Text('Change'),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // QR Code
          if (_shareLink != null) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _shareLink!,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan this QR code to import the recipe',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ] else if (_isGenerating) ...[
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Share options
          Text(
            'Share via',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ShareButton(
                  icon: Icons.share,
                  label: 'Share Link',
                  onTap: _shareLink == null ? null : _shareViaLink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShareButton(
                  icon: Icons.copy,
                  label: 'Copy Link',
                  onTap: _shareLink == null ? null : _copyLink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ShareButton(
                  icon: Icons.text_snippet,
                  label: 'As Text',
                  onTap: _shareAsText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShareButton(
                  icon: Icons.image,
                  label: 'As Image',
                  onTap: _shareAsImage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _shareViaLink() {
    if (_shareLink == null) return;
    Share.share(
      'Check out this recipe: ${_selectedRecipe!.name}\n\n$_shareLink',
      subject: _selectedRecipe!.name,
    );
  }

  void _copyLink() {
    if (_shareLink == null) return;
    // Copy to clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard!')),
    );
  }

  void _shareAsText() {
    if (_selectedRecipe == null) return;

    final buffer = StringBuffer();
    buffer.writeln('📖 ${_selectedRecipe!.name}');
    buffer.writeln();

    if (_selectedRecipe!.course != null) {
      buffer.writeln('Course: ${_selectedRecipe!.course}');
    }
    if (_selectedRecipe!.cuisine != null) {
      buffer.writeln('Cuisine: ${_selectedRecipe!.cuisine}');
    }
    if (_selectedRecipe!.serves != null) {
      buffer.writeln('Serves: ${_selectedRecipe!.serves}');
    }
    if (_selectedRecipe!.time != null) {
      buffer.writeln('Time: ${_selectedRecipe!.time}');
    }
    buffer.writeln();

    buffer.writeln('🥕 Ingredients:');
    for (final ingredient in _selectedRecipe!.ingredients) {
      final amount = ingredient.amount != null ? '${ingredient.amount} ' : '';
      final unit = ingredient.unit != null ? '${ingredient.unit} ' : '';
      buffer.writeln('• $amount$unit${ingredient.name}');
    }
    buffer.writeln();

    buffer.writeln('👨‍🍳 Directions:');
    for (var i = 0; i < _selectedRecipe!.directions.length; i++) {
      buffer.writeln('${i + 1}. ${_selectedRecipe!.directions[i]}');
    }

    buffer.writeln();
    buffer.writeln('Shared from Memoix 🍳');

    Share.share(buffer.toString(), subject: _selectedRecipe!.name);
  }

  void _shareAsImage() {
    // TODO: Generate and share recipe as image
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image sharing coming soon!')),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ShareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
