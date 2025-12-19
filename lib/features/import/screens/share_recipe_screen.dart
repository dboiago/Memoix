import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../recipes/models/recipe.dart';
import '../../recipes/models/category.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../sharing/services/share_service.dart';
import '../../../core/widgets/memoix_snackbar.dart';

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
  bool _qrCodeTooLong = false; // Track if QR code data exceeds capacity
  String _searchQuery = '';
  String _selectedCourse = 'All';
  final _searchController = TextEditingController();

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

    setState(() {
      _isGenerating = true;
      _qrCodeTooLong = false;
    });

    try {
      final shareService = ref.read(shareServiceProvider);
      final link = shareService.generateShareLink(_selectedRecipe!);
      
      // QR codes have a max capacity - version 40 can hold ~2953 alphanumeric chars
      // Base64 is less efficient, so check if link is too long (roughly 2KB is safe)
      final isTooLong = link.length > 2000;
      
      setState(() {
        _shareLink = link;
        _qrCodeTooLong = isTooLong;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      MemoixSnackBar.showError('Failed to generate link: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: _selectedRecipe == null, // Only pop if no recipe selected
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedRecipe != null) {
          // Go back to recipe selector instead of leaving screen
          setState(() {
            _selectedRecipe = null;
            _shareLink = null;
            _qrCodeTooLong = false;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Share Recipe'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_selectedRecipe != null) {
                // Go back to recipe selector
                setState(() {
                  _selectedRecipe = null;
                  _shareLink = null;
                  _qrCodeTooLong = false;
                });
              } else {
                // Leave the screen
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: _selectedRecipe == null
            ? _buildRecipeSelector()
            : _buildShareOptions(theme),
      ),
    );
    );
  }

  Widget _buildRecipeSelector() {
    final recipesAsync = ref.watch(allRecipesProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select a recipe to share',
            style: theme.textTheme.titleMedium,
          ),
        ),
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search recipes...',
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          ),
        ),
        const SizedBox(height: 8),
        // Course filter chips - use Category.defaults for proper ordering
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: recipesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (recipes) {
              // Get courses that have recipes, ordered by Category.defaults
              final recipeCourses = recipes.map((r) => r.course.toLowerCase()).toSet();
              final orderedCourses = Category.defaults
                  .where((c) => recipeCourses.contains(c.slug) || recipeCourses.contains(c.name.toLowerCase()))
                  .map((c) => c.name)
                  .toList();
              
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // "All" chip first
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: _selectedCourse == 'All',
                        onSelected: (selected) {
                          setState(() => _selectedCourse = 'All');
                        },
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        selectedColor: theme.colorScheme.secondary.withOpacity(0.15),
                        showCheckmark: false,
                        side: BorderSide(
                          color: _selectedCourse == 'All'
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.outline.withOpacity(0.2),
                          width: _selectedCourse == 'All' ? 1.5 : 1.0,
                        ),
                        labelStyle: TextStyle(
                          color: _selectedCourse == 'All'
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    // Course chips in Category.defaults order
                    ...orderedCourses.map((course) {
                      final isSelected = _selectedCourse.toLowerCase() == course.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(course),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedCourse = course);
                          },
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          selectedColor: theme.colorScheme.secondary.withOpacity(0.15),
                          showCheckmark: false,
                          side: BorderSide(
                            color: isSelected
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.outline.withOpacity(0.2),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.secondary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        Expanded(
          child: recipesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (recipes) {
              // Filter recipes
              final filtered = recipes.where((r) {
                // Course filter - match by slug or name (case-insensitive)
                if (_selectedCourse != 'All') {
                  final courseLower = r.course.toLowerCase();
                  final selectedLower = _selectedCourse.toLowerCase();
                  // Match exact course or Category slug/name
                  if (courseLower != selectedLower) {
                    // Check if it matches a Category's slug
                    final matchingCategory = Category.defaults.firstWhere(
                      (c) => c.name.toLowerCase() == selectedLower,
                      orElse: () => Category.create(slug: '', name: '', colorValue: 0),
                    );
                    if (matchingCategory.slug.isEmpty || courseLower != matchingCategory.slug) {
                      return false;
                    }
                  }
                }
                // Search filter
                if (_searchQuery.isNotEmpty) {
                  final nameLower = r.name.toLowerCase();
                  final cuisineLower = (r.cuisine ?? '').toLowerCase();
                  if (!nameLower.contains(_searchQuery) &&
                      !cuisineLower.contains(_searchQuery)) {
                    return false;
                  }
                }
                return true;
              }).toList();
              
              // Sort alphabetically by name
              filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 48, color: theme.colorScheme.outline),
                      const SizedBox(height: 8),
                      Text(
                        'No recipes found',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Group by course, maintaining Category.defaults order
              final grouped = <String, List<Recipe>>{};
              // Initialize groups in Category.defaults order
              for (final cat in Category.defaults) {
                final matchingRecipes = filtered.where((r) {
                  final courseLower = r.course.toLowerCase();
                  return courseLower == cat.slug || courseLower == cat.name.toLowerCase();
                }).toList();
                if (matchingRecipes.isNotEmpty) {
                  grouped[cat.name] = matchingRecipes;
                }
              }
              // Add any recipes with courses not in Category.defaults
              for (final recipe in filtered) {
                final courseLower = recipe.course.toLowerCase();
                final isKnownCourse = Category.defaults.any(
                  (c) => c.slug == courseLower || c.name.toLowerCase() == courseLower,
                );
                if (!isKnownCourse) {
                  final displayCourse = recipe.course.isNotEmpty 
                      ? recipe.course[0].toUpperCase() + recipe.course.substring(1)
                      : 'Other';
                  grouped.putIfAbsent(displayCourse, () => []).add(recipe);
                }
              }

              return ListView.builder(
                itemCount: grouped.length,
                itemBuilder: (context, index) {
                  final course = grouped.keys.elementAt(index);
                  final courseRecipes = grouped[course]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedCourse == 'All') ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            course,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                      ...courseRecipes.map((recipe) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          child: Text(
                            recipe.name.isNotEmpty ? recipe.name[0].toUpperCase() : '?',
                          ),
                        ),
                        title: Text(recipe.name),
                        subtitle: recipe.cuisine != null ? Text(recipe.cuisine!) : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          setState(() => _selectedRecipe = recipe);
                          _generateShareLink();
                        },
                      ),),
                    ],
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
                    _qrCodeTooLong = false;
                  });
                },
                child: const Text('Change'),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // QR Code - only show if not too long
          if (_shareLink != null && !_qrCodeTooLong) ...[
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
          ] else if (_qrCodeTooLong) ...[
            // Recipe too large for QR code
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 48,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Recipe too large for QR code',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This recipe has too many ingredients or directions to fit in a QR code. Use "Share Link" or "As Text" instead.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
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
    Clipboard.setData(ClipboardData(text: _shareLink!));
    MemoixSnackBar.show('Link copied to clipboard');
  }

  void _shareAsText() {
    if (_selectedRecipe == null) return;

    final buffer = StringBuffer();
    buffer.writeln('📖 ${_selectedRecipe!.name}');
    buffer.writeln();

    buffer.writeln('Course: ${_selectedRecipe!.course}');
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
    MemoixSnackBar.show('Image sharing coming soon');
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
