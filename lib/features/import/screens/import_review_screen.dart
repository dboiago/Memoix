import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../recipes/models/recipe.dart';
import '../../recipes/models/category.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
import '../models/recipe_import_result.dart';

/// Screen for reviewing and mapping imported recipe data
/// Shown when confidence is below threshold or user wants to review
class ImportReviewScreen extends ConsumerStatefulWidget {
  final RecipeImportResult importResult;

  const ImportReviewScreen({
    super.key,
    required this.importResult,
  });

  @override
  ConsumerState<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends ConsumerState<ImportReviewScreen> {
  late TextEditingController _nameController;
  late TextEditingController _servesController;
  late TextEditingController _timeController;

  // Track selections
  String _selectedCourse = 'Mains';
  String? _selectedCuisine;

  // Track which raw ingredients to include
  late Set<int> _selectedIngredientIndices;

  // Track which directions to include
  late Set<int> _selectedDirectionIndices;

  @override
  void initState() {
    super.initState();
    final result = widget.importResult;

    _nameController = TextEditingController(text: result.name ?? '');
    _servesController = TextEditingController(text: result.serves ?? '');
    _timeController = TextEditingController(text: result.time ?? '');

    _selectedCourse = result.course ?? 'Mains';
    _selectedCuisine = result.cuisine;

    // Pre-select all ingredients
    _selectedIngredientIndices =
        Set.from(List.generate(result.rawIngredients.length, (i) => i));

    // Pre-select all directions
    _selectedDirectionIndices =
        Set.from(List.generate(result.rawDirections.length, (i) => i));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servesController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.importResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Import'),
        actions: [
          TextButton(
            onPressed: _saveRecipe,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Confidence overview
          _buildConfidenceCard(theme, result),
          const SizedBox(height: 16),

          // Raw text preview (for OCR)
          if (result.rawText != null) ...[
            _buildRawTextCard(theme, result.rawText!),
            const SizedBox(height: 16),
          ],

          // Recipe name
          _buildSectionTitle(theme, 'Recipe Name', Icons.restaurant,
              confidence: result.nameConfidence),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter recipe name',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 24),

          // Course selection
          _buildSectionTitle(theme, 'Course', Icons.category,
              confidence: result.courseConfidence),
          const SizedBox(height: 8),
          _buildCourseSelector(theme, result),
          const SizedBox(height: 24),

          // Cuisine selection
          _buildSectionTitle(theme, 'Cuisine', Icons.public,
              confidence: result.cuisineConfidence),
          const SizedBox(height: 8),
          _buildCuisineSelector(theme, result),
          const SizedBox(height: 24),

          // Servings and time
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(theme, 'Servings', Icons.people,
                        confidence: result.servesConfidence),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _servesController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 4',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(theme, 'Time', Icons.timer,
                        confidence: result.timeConfidence),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _timeController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 30 min',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Ingredients
          _buildSectionTitle(theme, 'Ingredients', Icons.kitchen,
              confidence: result.ingredientsConfidence),
          const SizedBox(height: 8),
          _buildIngredientsList(theme, result),
          const SizedBox(height: 24),

          // Directions
          _buildSectionTitle(theme, 'Directions', Icons.format_list_numbered,
              confidence: result.directionsConfidence),
          const SizedBox(height: 8),
          _buildDirectionsList(theme, result),
          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _openInEditScreen,
                  child: const Text('Edit More Details'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _saveRecipe,
                  child: const Text('Save Recipe'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildConfidenceCard(ThemeData theme, RecipeImportResult result) {
    final confidence = result.overallConfidence;
    final Color cardColor;
    final IconData icon;
    final String message;

    if (confidence >= 0.8) {
      cardColor = Colors.green.withOpacity(0.1);
      icon = Icons.check_circle;
      message = 'High confidence import! Review and save.';
    } else if (confidence >= 0.5) {
      cardColor = Colors.orange.withOpacity(0.1);
      icon = Icons.warning;
      message = 'Some fields need your attention.';
    } else {
      cardColor = Colors.red.withOpacity(0.1);
      icon = Icons.error_outline;
      message = 'Low confidence. Please review all fields.';
    }

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: confidence,
                    backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (result.fieldsNeedingAttention.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Check: ${result.fieldsNeedingAttention.join(", ")}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawTextCard(ThemeData theme, String rawText) {
    return ExpansionTile(
      leading: const Icon(Icons.text_fields),
      title: const Text('Raw Extracted Text'),
      subtitle: const Text('Tap to view original OCR text'),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: theme.colorScheme.surfaceContainerHighest,
          width: double.infinity,
          child: SelectableText(
            rawText,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    ThemeData theme,
    String title,
    IconData icon, {
    double confidence = 1.0,
  }) {
    final Color indicatorColor;
    if (confidence >= 0.7) {
      indicatorColor = Colors.green;
    } else if (confidence >= 0.4) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = Colors.red;
    }

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: indicatorColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          confidence >= 0.7
              ? 'Good'
              : confidence >= 0.4
                  ? 'Review'
                  : 'Needs input',
          style: theme.textTheme.bodySmall?.copyWith(color: indicatorColor),
        ),
      ],
    );
  }

  Widget _buildCourseSelector(ThemeData theme, RecipeImportResult result) {
    // Get all available courses
    final allCourses = Category.defaults.map((c) => c.name).toList();
    
    // Combine detected + all available
    final courses = <String>{
      ...result.detectedCourses,
      ...allCourses,
    }.toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: courses.map((course) {
        final isSelected = _selectedCourse == course;
        final isDetected = result.detectedCourses.contains(course);
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(course),
              if (isDetected) ...[
                const SizedBox(width: 4),
                Icon(Icons.auto_awesome, size: 14, color: theme.colorScheme.primary),
              ],
            ],
          ),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedCourse = course),
          selectedColor: theme.colorScheme.primary.withOpacity(0.2),
        );
      }).toList(),
    );
  }

  Widget _buildCuisineSelector(ThemeData theme, RecipeImportResult result) {
    // Common cuisines + detected ones
    final cuisines = <String>{
      if (_selectedCuisine != null) _selectedCuisine!,
      ...result.detectedCuisines,
      'USA',
      'France',
      'Italy',
      'Mexico',
      'China',
      'Japan',
      'India',
      'Thailand',
      'Korea',
      'Mediterranean',
    }.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cuisines.map((cuisine) {
            final isSelected = _selectedCuisine == cuisine;
            final isDetected = result.detectedCuisines.contains(cuisine);
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cuisine),
                  if (isDetected) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.auto_awesome, size: 14, color: theme.colorScheme.primary),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _selectedCuisine = isSelected ? null : cuisine;
                });
              },
              selectedColor: theme.colorScheme.primary.withOpacity(0.2),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectedCuisine = null),
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIngredientsList(ThemeData theme, RecipeImportResult result) {
    if (result.rawIngredients.isEmpty) {
      return Card(
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No ingredients found. You can add them after saving.'),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          // Select/Deselect all
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_selectedIngredientIndices.length} of ${result.rawIngredients.length} selected',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _selectedIngredientIndices = Set.from(
                        List.generate(result.rawIngredients.length, (i) => i));
                  }),
                  child: const Text('All'),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _selectedIngredientIndices.clear()),
                  child: const Text('None'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...result.rawIngredients.asMap().entries.map((entry) {
            final index = entry.key;
            final ingredient = entry.value;
            final isSelected = _selectedIngredientIndices.contains(index);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedIngredientIndices.add(index);
                  } else {
                    _selectedIngredientIndices.remove(index);
                  }
                });
              },
              title: Text(
                ingredient.name,
                style: TextStyle(
                  decoration: isSelected ? null : TextDecoration.lineThrough,
                  color: isSelected ? null : theme.colorScheme.outline,
                ),
              ),
              subtitle: ingredient.amount != null
                  ? Text(
                      ingredient.amount!,
                      style: theme.textTheme.bodySmall,
                    )
                  : null,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDirectionsList(ThemeData theme, RecipeImportResult result) {
    if (result.rawDirections.isEmpty) {
      return Card(
        color: theme.colorScheme.errorContainer.withOpacity(0.3),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No directions found. You can add them after saving.'),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          // Select/Deselect all
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_selectedDirectionIndices.length} of ${result.rawDirections.length} steps',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _selectedDirectionIndices = Set.from(
                        List.generate(result.rawDirections.length, (i) => i));
                  }),
                  child: const Text('All'),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _selectedDirectionIndices.clear()),
                  child: const Text('None'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...result.rawDirections.asMap().entries.map((entry) {
            final index = entry.key;
            final direction = entry.value;
            final isSelected = _selectedDirectionIndices.contains(index);

            return CheckboxListTile(
              value: isSelected,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedDirectionIndices.add(index);
                  } else {
                    _selectedDirectionIndices.remove(index);
                  }
                });
              },
              title: Text(
                '${index + 1}. ${direction.length > 100 ? '${direction.substring(0, 100)}...' : direction}',
                style: TextStyle(
                  decoration: isSelected ? null : TextDecoration.lineThrough,
                  color: isSelected ? null : theme.colorScheme.outline,
                ),
              ),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            );
          }),
        ],
      ),
    );
  }

  void _openInEditScreen() {
    final recipe = _buildRecipe();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RecipeEditScreen(importedRecipe: recipe),
      ),
    );
  }

  Recipe _buildRecipe() {
    // Build ingredients from selected
    final ingredients = <Ingredient>[];
    for (final index in _selectedIngredientIndices.toList()..sort()) {
      if (index < widget.importResult.rawIngredients.length) {
        ingredients.add(widget.importResult.rawIngredients[index].toIngredient());
      }
    }

    // Build directions from selected
    final directions = <String>[];
    for (final index in _selectedDirectionIndices.toList()..sort()) {
      if (index < widget.importResult.rawDirections.length) {
        directions.add(widget.importResult.rawDirections[index]);
      }
    }

    final recipe = Recipe.create(
      uuid: const Uuid().v4(),
      name: _nameController.text.trim().isEmpty
          ? 'Untitled Recipe'
          : _nameController.text.trim(),
      course: _selectedCourse,
      cuisine: _selectedCuisine,
      subcategory: widget.importResult.subcategory,
      serves: _servesController.text.trim().isEmpty
          ? null
          : _servesController.text.trim(),
      time: _timeController.text.trim().isEmpty
          ? null
          : _timeController.text.trim(),
      ingredients: ingredients,
      directions: directions,
      notes: widget.importResult.notes,
      imageUrl: widget.importResult.imageUrl,
      sourceUrl: widget.importResult.sourceUrl,
      source: widget.importResult.source,
      nutrition: widget.importResult.nutrition,
    );

    // Add multiple images if available (from multi-image import)
    if (widget.importResult.imagePaths != null &&
        widget.importResult.imagePaths!.isNotEmpty) {
      recipe.imageUrls = widget.importResult.imagePaths!;
    }

    return recipe;
  }

  Future<void> _saveRecipe() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipe name')),
      );
      return;
    }

    final recipe = _buildRecipe();
    await ref.read(recipeRepositoryProvider).saveRecipe(recipe);

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${recipe.name}')),
      );
    }
  }
}
