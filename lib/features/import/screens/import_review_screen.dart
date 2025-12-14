import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../recipes/models/recipe.dart';
import '../../recipes/models/category.dart';
import '../../recipes/models/cuisine.dart';
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
                        color: theme.colorScheme.secondary,
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

  // Fields that are optional and shouldn't show "Needs input"
  static const _optionalFields = {'Cuisine', 'Servings', 'Time'};
  
  Widget _buildSectionTitle(
    ThemeData theme,
    String title,
    IconData icon, {
    double confidence = 1.0,
  }) {
    final Color indicatorColor;
    final String label;
    
    // For optional fields with low confidence, show "Optional" instead of "Needs input"
    final isOptional = _optionalFields.contains(title);
    
    if (confidence >= 0.7) {
      indicatorColor = theme.colorScheme.primary;
      label = 'Good';
    } else if (confidence >= 0.4) {
      indicatorColor = theme.colorScheme.secondary;
      label = 'Review';
    } else if (isOptional) {
      // Optional fields with no data - subtle indicator
      indicatorColor = theme.colorScheme.outline;
      label = 'Optional';
    } else {
      // Required fields with no data - use secondary color
      indicatorColor = theme.colorScheme.secondary;
      label = 'Needs input';
    }

    return Row(
      children: [
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
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: indicatorColor),
        ),
      ],
    );
  }

  /// Convert course code to display name
  String _courseDisplayName(String course) {
    switch (course.toLowerCase()) {
      case 'modernist':
        return 'Modernist';
      default:
        return course;
    }
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
              Text(_courseDisplayName(course)),
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
    return InkWell(
      onTap: () => _showCuisineSheet(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Cuisine',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          _selectedCuisine != null
              ? '${Cuisine.byCode(_selectedCuisine!)?.flag ?? ''} ${Cuisine.byCode(_selectedCuisine!)?.name ?? _selectedCuisine}'
              : 'Select cuisine (optional)',
          style: TextStyle(
            color: _selectedCuisine != null
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
  
  void _showCuisineSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CuisinePickerSheet(
        selectedCuisine: _selectedCuisine,
        onChanged: (code) {
          setState(() => _selectedCuisine = code);
          Navigator.pop(ctx);
        },
        onClear: () {
          setState(() => _selectedCuisine = null);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _buildIngredientsList(ThemeData theme, RecipeImportResult result) {
    if (result.rawIngredients.isEmpty) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No ingredients found in source. You can add them after saving.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Select all row
        Row(
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
        const SizedBox(height: 8),
        
        // Check if any ingredient has baker's percentage
        Builder(builder: (context) {
          final hasBakerPercent = result.rawIngredients.any((i) => i.bakerPercent != null);
          
          return Column(
            children: [
              // Column headers - matching edit screen style
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    // Space for checkbox
                    const SizedBox(width: 32),
                    Expanded(
                      flex: hasBakerPercent ? 2 : 3,
                      child: Text('Ingredient', 
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (hasBakerPercent) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: Text('BK%', 
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text('Amount', 
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text('Notes/Prep', 
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Ingredient rows in bordered container
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Column(
                  children: result.rawIngredients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ingredient = entry.value;
                    final isSelected = _selectedIngredientIndices.contains(index);
                    final isLast = index == result.rawIngredients.length - 1;
                    
                    // Clean the name - remove colons and trim
                    final cleanName = ingredient.name.replaceAll(':', '').trim();
                    
                    // Skip empty entries (no meaningful name and no section)
                    // Also skip if name is just punctuation or the same as section name
                    final isEmptyOrDuplicate = cleanName.isEmpty || 
                        (ingredient.sectionName != null && 
                         cleanName.toLowerCase() == ingredient.sectionName!.toLowerCase());
                    if (isEmptyOrDuplicate && ingredient.sectionName == null) {
                      return const SizedBox.shrink();
                    }
                    
                    // Check if this is a section-only header (empty/duplicate name, has section)
                    final isSectionHeader = isEmptyOrDuplicate && ingredient.sectionName != null;

                    // Section header row - spans full width
                    if (isSectionHeader) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                          border: isLast 
                              ? null 
                              : Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
                        ),
                        child: Row(
                          children: [
                            // Checkbox for section
                            SizedBox(
                              width: 32,
                              child: Checkbox(
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
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            Text(
                              ingredient.sectionName!,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected 
                                    ? theme.colorScheme.primary 
                                    : theme.colorScheme.outline,
                                decoration: isSelected ? null : TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        border: isLast 
                            ? null 
                            : Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Checkbox
                          SizedBox(
                            width: 32,
                            child: Checkbox(
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
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          // Ingredient name
                          Expanded(
                            flex: hasBakerPercent ? 2 : 3,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                ingredient.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  decoration: isSelected ? null : TextDecoration.lineThrough,
                                  color: isSelected ? null : theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          ),
                          // Baker's percentage (conditional)
                          if (hasBakerPercent) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  ingredient.bakerPercent ?? '',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    decoration: isSelected ? null : TextDecoration.lineThrough,
                                    color: isSelected ? null : theme.colorScheme.outline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          // Amount
                          SizedBox(
                            width: 80,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                ingredient.amount ?? '',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  decoration: isSelected ? null : TextDecoration.lineThrough,
                                  color: isSelected ? null : theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Notes/Prep
                          Expanded(
                            flex: 2,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                ingredient.preparation ?? '',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  decoration: isSelected ? null : TextDecoration.lineThrough,
                                  color: isSelected ? null : theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildDirectionsList(ThemeData theme, RecipeImportResult result) {
    if (result.rawDirections.isEmpty) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No directions found in source. You can add them after saving.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Select/Deselect all header
        Row(
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
        const SizedBox(height: 8),
        
        // Direction rows - matching edit screen style
        ...result.rawDirections.asMap().entries.map((entry) {
          final index = entry.key;
          final direction = entry.value;
          final isSelected = _selectedDirectionIndices.contains(index);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox and step number
                Column(
                  children: [
                    Checkbox(
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
                      visualDensity: VisualDensity.compact,
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.secondary, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                
                // Direction text - using InputDecorator to match TextField
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(
                      direction,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: isSelected ? null : TextDecoration.lineThrough,
                        color: isSelected ? null : theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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
    // Section headers (empty name) are tracked to assign sections to following ingredients
    final ingredients = <Ingredient>[];
    String? currentSection;
    for (final index in _selectedIngredientIndices.toList()..sort()) {
      if (index < widget.importResult.rawIngredients.length) {
        final rawIngredient = widget.importResult.rawIngredients[index];
        
        // If this is a section header (empty name with section), track it but don't add
        if (rawIngredient.name.isEmpty && rawIngredient.sectionName != null) {
          currentSection = rawIngredient.sectionName;
          continue;
        }
        
        // Add the ingredient with current section
        ingredients.add(rawIngredient.toIngredient(section: currentSection));
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
    // First image becomes the header, rest go to step images gallery
    if (widget.importResult.imagePaths != null &&
        widget.importResult.imagePaths!.isNotEmpty) {
      recipe.headerImage = widget.importResult.imagePaths!.first;
      if (widget.importResult.imagePaths!.length > 1) {
        recipe.stepImages = widget.importResult.imagePaths!.sublist(1);
      }
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

/// Bottom sheet with searchable cuisine list grouped by continent
class _CuisinePickerSheet extends StatefulWidget {
  final String? selectedCuisine;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _CuisinePickerSheet({
    required this.selectedCuisine,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_CuisinePickerSheet> createState() => _CuisinePickerSheetState();
}

class _CuisinePickerSheetState extends State<_CuisinePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Cuisine> get _filteredCuisines {
    if (_searchQuery.isEmpty) return [];
    final query = _searchQuery.toLowerCase();
    return Cuisine.all.where((c) => 
      c.name.toLowerCase().contains(query) ||
      c.continent.toLowerCase().contains(query) ||
      c.code.toLowerCase().contains(query)
    ).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Select Cuisine',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onClear,
                  child: const Text('Clear'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search cuisines...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults(controller)
                : _buildGroupedList(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ScrollController controller) {
    final results = _filteredCuisines;
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No cuisines found for "$_searchQuery"',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: controller,
      itemCount: results.length,
      itemBuilder: (context, index) {
        final cuisine = results[index];
        final isSelected = widget.selectedCuisine == cuisine.code;
        return ListTile(
          leading: Text(cuisine.flag, style: const TextStyle(fontSize: 24)),
          title: Text(cuisine.name),
          subtitle: Text(cuisine.continent, 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          trailing: isSelected
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
          selected: isSelected,
          onTap: () => widget.onChanged(cuisine.code),
        );
      },
    );
  }

  Widget _buildGroupedList(ScrollController controller) {
    return ListView(
      controller: controller,
      children: CuisineGroup.all.map((group) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                group.continent,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                ),
              ),
            ),
            ...group.cuisines.map((cuisine) {
              final isSelected = widget.selectedCuisine == cuisine.code;
              return ListTile(
                leading: Text(cuisine.flag, style: const TextStyle(fontSize: 24)),
                title: Text(cuisine.name),
                trailing: isSelected
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                selected: isSelected,
                onTap: () => widget.onChanged(cuisine.code),
              );
            }),
          ],
        );
      }).toList(),
    );
  }
}
