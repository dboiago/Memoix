import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../models/recipe.dart';
import '../models/cuisine.dart';
import '../models/spirit.dart';
import '../repository/recipe_repository.dart';

/// Converts text fractions and decimals to unicode fraction symbols
String _normalizeFractions(String input) {
  var result = input;
  
  // Map of text fractions to unicode symbols
  const fractionMap = {
    '1/2': '½',
    '1/3': '⅓',
    '2/3': '⅔',
    '1/4': '¼',
    '3/4': '¾',
    '1/5': '⅕',
    '2/5': '⅖',
    '3/5': '⅗',
    '4/5': '⅘',
    '1/6': '⅙',
    '5/6': '⅚',
    '1/8': '⅛',
    '3/8': '⅜',
    '5/8': '⅝',
    '7/8': '⅞',
  };
  
  // Map of decimal values to unicode symbols
  const decimalMap = {
    '0.5': '½',
    '.5': '½',
    '0.25': '¼',
    '.25': '¼',
    '0.75': '¾',
    '.75': '¾',
    '0.33': '⅓',
    '.33': '⅓',
    '0.67': '⅔',
    '.67': '⅔',
  };
  
  // Replace text fractions (with optional spaces around /)
  for (final entry in fractionMap.entries) {
    // Match with optional spaces: "1 / 2" or "1/2"
    final pattern = entry.key.replaceAll('/', r'\s*/\s*');
    result = result.replaceAll(RegExp(pattern), entry.value);
  }
  
  // Replace decimal values
  for (final entry in decimalMap.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  
  return result;
}

class RecipeEditScreen extends ConsumerStatefulWidget {
  final String? recipeId;
  final Recipe? initialRecipe;
  final Recipe? importedRecipe;
  final String? ocrText;
  final String? defaultCourse;

  const RecipeEditScreen({
    super.key,
    this.recipeId,
    this.initialRecipe,
    this.importedRecipe,
    this.ocrText,
    this.defaultCourse,
  });

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  static const _uuid = Uuid();

  late final TextEditingController _nameController;
  late final TextEditingController _servesController;
  late final TextEditingController _timeController;
  late final TextEditingController _notesController;
  late final TextEditingController _directionsController;
  late final TextEditingController _regionController;

  // Nutrition controllers
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;

  // 3-column ingredient editing: list of (name, amount, notes) controllers
  final List<_IngredientRow> _ingredientRows = [];

  String _selectedCourse = 'mains';
  String? _selectedCuisine;
  String? _imagePath; // Local file path or URL
  bool _isSaving = false;
  bool _isLoading = true;
  Recipe? _existingRecipe;

  bool get _isEditing => _existingRecipe != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _servesController = TextEditingController();
    _timeController = TextEditingController();
    _notesController = TextEditingController();
    _directionsController = TextEditingController();
    _regionController = TextEditingController();
    _caloriesController = TextEditingController();
    _proteinController = TextEditingController();
    _carbsController = TextEditingController();
    _fatController = TextEditingController();

    if (widget.defaultCourse != null) {
      _selectedCourse = widget.defaultCourse!;
    }

    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    Recipe? recipe;

    if (widget.initialRecipe != null) {
      recipe = widget.initialRecipe;
    } else if (widget.importedRecipe != null) {
      recipe = widget.importedRecipe;
    } else if (widget.recipeId != null) {
      final repo = ref.read(recipeRepositoryProvider);
      recipe = await repo.getRecipeByUuid(widget.recipeId!);
    }

    if (recipe != null) {
      _existingRecipe = recipe;
      _nameController.text = recipe.name;
      _servesController.text = recipe.serves ?? '';
      _timeController.text = recipe.time ?? '';
      _notesController.text = recipe.notes ?? '';
      _regionController.text = recipe.subcategory ?? '';
      
      // Load nutrition data if present
      if (recipe.nutrition != null) {
        _caloriesController.text = recipe.nutrition!.calories?.toString() ?? '';
        _proteinController.text = recipe.nutrition!.proteinContent?.toString() ?? '';
        _carbsController.text = recipe.nutrition!.carbohydrateContent?.toString() ?? '';
        _fatController.text = recipe.nutrition!.fatContent?.toString() ?? '';
      }
      
      // Normalize course to slug form (lowercase) to match dropdown values
      _selectedCourse = _normaliseCourseSlug(recipe.course?.toLowerCase() ?? _selectedCourse);
      _selectedCuisine = recipe.cuisine;

      // Convert ingredients to 3-column row controllers
      // Track sections to insert section headers
      String? lastSection;
      for (final ingredient in recipe.ingredients) {
        // If this ingredient has a different section, add a section header
        if (ingredient.section != null && ingredient.section != lastSection) {
          _addIngredientRow(name: ingredient.section!, isSection: true);
          lastSection = ingredient.section;
        }
        _addIngredientRow(
          name: ingredient.name,
          amount: ingredient.displayAmount,
          notes: ingredient.preparation ?? '',
        );
      }

      // Convert directions to editable text
      _directionsController.text = recipe.directions.join('\n\n');
      
      // Load existing image
      _imagePath = recipe.imageUrl;
    } else if (widget.ocrText != null) {
      // Pre-populate with OCR text for manual extraction
      _notesController.text = 'OCR Text:\n${widget.ocrText}';
    }

    // Always have at least one empty row for adding ingredients
    if (_ingredientRows.isEmpty) {
      // For salads, add a Dressing section after initial ingredients
      if (_selectedCourse == 'salad') {
        _addIngredientRow(); // Empty row for salad ingredients
        _addIngredientRow(name: 'Dressing', isSection: true);
        _addIngredientRow(); // Empty row for dressing ingredients
      } else {
        _addIngredientRow();
      }
    }

    setState(() => _isLoading = false);
  }

  /// Normalise course slug to match dropdown values
  String _normaliseCourseSlug(String course) {
    const mapping = {
      'soups': 'soup',
      'salads': 'salad',
      'not-meat': 'vegan',
      'not meat': 'vegan',
      'vegetarian': 'vegan',
    };
    return mapping[course] ?? course;
  }

  void _addIngredientRow({String name = '', String amount = '', String notes = '', bool isSection = false}) {
    _ingredientRows.add(_IngredientRow(
      nameController: TextEditingController(text: name),
      amountController: TextEditingController(text: amount),
      notesController: TextEditingController(text: notes),
      isSection: isSection,
    ));
  }

  void _addSectionHeader() {
    _ingredientRows.add(_IngredientRow(
      nameController: TextEditingController(),
      amountController: TextEditingController(),
      notesController: TextEditingController(),
      isSection: true,
    ));
    setState(() {});
  }

  void _removeIngredientRow(int index) {
    if (_ingredientRows.length > 1) {
      final row = _ingredientRows.removeAt(index);
      row.dispose();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servesController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    _directionsController.dispose();
    _regionController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    super.dispose();
  }

  /// Build NutritionInfo from form fields, returns null if all empty
  NutritionInfo? _buildNutritionInfo() {
    final calories = int.tryParse(_caloriesController.text.trim());
    final protein = double.tryParse(_proteinController.text.trim());
    final carbs = double.tryParse(_carbsController.text.trim());
    final fat = double.tryParse(_fatController.text.trim());
    
    // Return null if no nutrition data entered
    if (calories == null && protein == null && carbs == null && fat == null) {
      return null;
    }
    
    return NutritionInfo.create(
      calories: calories,
      proteinContent: protein,
      carbohydrateContent: carbs,
      fatContent: fat,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          if (widget.ocrText != null)
            IconButton(
              icon: const Icon(Icons.text_snippet),
              tooltip: 'View OCR Text',
              onPressed: () => _showOcrText(context),
            ),
          TextButton.icon(
            onPressed: _isSaving ? null : _saveRecipe,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recipe image (optional)
            _buildImagePicker(theme),
            
            const SizedBox(height: 16),

            // Recipe name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Recipe Name *',
                hintText: 'e.g., Korean Fried Chicken',
              ),
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            // Course dropdown
            DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: const InputDecoration(
                labelText: 'Category *',
              ),
              items: const [
                DropdownMenuItem(value: 'apps', child: Text('Apps')),
                DropdownMenuItem(value: 'soup', child: Text('Soup')),
                DropdownMenuItem(value: 'mains', child: Text('Mains')),
                DropdownMenuItem(value: 'vegan', child: Text("Veg'n")),
                DropdownMenuItem(value: 'sides', child: Text('Sides')),
                DropdownMenuItem(value: 'salad', child: Text('Salad')),
                DropdownMenuItem(value: 'desserts', child: Text('Desserts')),
                DropdownMenuItem(value: 'brunch', child: Text('Brunch')),
                DropdownMenuItem(value: 'drinks', child: Text('Drinks')),
                DropdownMenuItem(value: 'breads', child: Text('Breads')),
                DropdownMenuItem(value: 'sauces', child: Text('Sauces')),
                DropdownMenuItem(value: 'rubs', child: Text('Rubs')),
                DropdownMenuItem(value: 'pickles', child: Text('Pickles/Brines')),
                DropdownMenuItem(value: 'molecular', child: Text('Modernist')),
                DropdownMenuItem(value: 'pizzas', child: Text('Pizzas')),
                DropdownMenuItem(value: 'sandwiches', child: Text('Sandwiches')),
                DropdownMenuItem(value: 'smoking', child: Text('Smoking')),
                DropdownMenuItem(value: 'cheese', child: Text('Cheese')),
                DropdownMenuItem(value: 'scratch', child: Text('Scratch')),
              ],
              onChanged: (value) {
                if (value != null) {
                  final previousCourse = _selectedCourse;
                  setState(() => _selectedCourse = value);
                  
                  // If switching TO salad from non-salad with empty ingredients, add Dressing section
                  if (value == 'salad' && previousCourse != 'salad') {
                    final hasOnlyEmptyRows = _ingredientRows.every((row) => 
                        row.nameController.text.isEmpty && 
                        row.amountController.text.isEmpty);
                    if (hasOnlyEmptyRows && _ingredientRows.length <= 1) {
                      // Clear and add dressing section
                      for (final row in _ingredientRows) {
                        row.dispose();
                      }
                      _ingredientRows.clear();
                      _addIngredientRow();
                      _addIngredientRow(name: 'Dressing', isSection: true);
                      _addIngredientRow();
                      setState(() {});
                    }
                  }
                }
              },
            ),

            const SizedBox(height: 16),

            // Cuisine and Region/Spirit row (stacked on narrow screens)
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 400;
                final isDrink = _selectedCourse == 'drinks';
                
                if (isNarrow) {
                  // Stacked layout for phone
                  return Column(
                    children: [
                      _CuisineSelector(
                        selectedCuisine: _selectedCuisine,
                        onChanged: (cuisine) => setState(() => _selectedCuisine = cuisine),
                      ),
                      const SizedBox(height: 12),
                      if (isDrink)
                        _SpiritSelector(
                          controller: _regionController,
                          onChanged: (spirit) {
                            setState(() {
                              _regionController.text = spirit ?? '';
                            });
                          },
                        )
                      else
                        TextField(
                          controller: _regionController,
                          decoration: const InputDecoration(
                            labelText: 'Region (optional)',
                            hintText: 'e.g., Szechuan, Cantonese',
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                    ],
                  );
                } else {
                  // Side-by-side for tablet/desktop
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _CuisineSelector(
                          selectedCuisine: _selectedCuisine,
                          onChanged: (cuisine) => setState(() => _selectedCuisine = cuisine),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: isDrink
                          ? _SpiritSelector(
                              controller: _regionController,
                              onChanged: (spirit) {
                                setState(() {
                                  _regionController.text = spirit ?? '';
                                });
                              },
                            )
                          : TextField(
                              controller: _regionController,
                              decoration: const InputDecoration(
                                labelText: 'Region (optional)',
                                hintText: 'e.g., Szechuan',
                              ),
                              textCapitalization: TextCapitalization.words,
                            ),
                      ),
                    ],
                  );
                }
              },
            ),

            const SizedBox(height: 16),

            // Serves and Time row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _servesController,
                    decoration: const InputDecoration(
                      labelText: 'Serves',
                      hintText: 'e.g., 4-6',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _timeController,
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      hintText: 'e.g., 40 min',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Ingredients (3-column spreadsheet layout)
            Row(
              children: [
                Text(
                  'Ingredients',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addSectionHeader,
                  icon: const Icon(Icons.title, size: 18),
                  label: const Text('Section'),
                ),
                TextButton.icon(
                  onPressed: () {
                    _addIngredientRow();
                    setState(() {});
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Column headers
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  // Space for drag handle
                  const SizedBox(width: 32),
                  SizedBox(
                    width: 120,
                    child: Text('Ingredient', 
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
                    child: Text('Notes/Prep', 
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // Space for delete button
                ],
              ),
            ),
            
            // Ingredient rows (reorderable)
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _ingredientRows.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _ingredientRows.removeAt(oldIndex);
                    _ingredientRows.insert(newIndex, item);
                  });
                },
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return Material(
                        elevation: 4,
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  return _buildIngredientRowWidget(index, key: ValueKey(_ingredientRows[index]));
                },
              ),
            ),

            const SizedBox(height: 24),

            // Directions
            Text(
              'Directions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Separate steps with blank lines. Use [Section Name] for subsections.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _directionsController,
              decoration: const InputDecoration(
                hintText: 'Melt butter in a large pot...\n\nAdd onions and sauté...\n\n...',
                alignLabelWithHint: true,
              ),
              maxLines: 15,
              minLines: 8,
            ),

            const SizedBox(height: 24),

            // Comments (previously called Notes)
            Text(
              'Comments',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Optional tips, variations, etc.',
              ),
              maxLines: 4,
              minLines: 2,
            ),

            const SizedBox(height: 16),

            // Nutrition Information (optional, collapsible)
            ExpansionTile(
              title: Text(
                'Nutrition Info',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: _caloriesController.text.isNotEmpty
                  ? Text('${_caloriesController.text} cal', style: theme.textTheme.bodySmall)
                  : null,
              initiallyExpanded: _caloriesController.text.isNotEmpty,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
              shape: const Border(),  // Removes top/bottom divider lines
              collapsedShape: const Border(),  // Removes lines when collapsed too
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _caloriesController,
                        decoration: const InputDecoration(
                          labelText: 'Calories',
                          suffixText: 'cal',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _proteinController,
                        decoration: const InputDecoration(
                          labelText: 'Protein',
                          suffixText: 'g',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _carbsController,
                        decoration: const InputDecoration(
                          labelText: 'Carbs',
                          suffixText: 'g',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _fatController,
                        decoration: const InputDecoration(
                          labelText: 'Fat',
                          suffixText: 'g',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Per serving. Values are estimates.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRecipe() async {
    // Validate
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipe name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Parse ingredients from the 3-column rows
      // Parse ingredients from the 3-column rows
      // Track current section for grouping
      String? currentSection;
      final ingredients = <Ingredient>[];
      
      for (final row in _ingredientRows) {
        final name = row.nameController.text.trim();
        if (name.isEmpty) continue;
        
        if (row.isSection) {
          // This is a section header - update current section
          currentSection = name;
          continue;
        }
        
        // Parse the amount field for amount and unit
        final amountText = row.amountController.text.trim();
        String? amount;
        String? unit;
        if (amountText.isNotEmpty) {
          // Normalize fractions first
          final normalized = _normalizeFractions(amountText);
          // Try to separate amount from unit (e.g., "2 tbsp" -> amount: "2", unit: "tbsp")
          final parts = normalized.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            amount = parts.first;
            unit = parts.sublist(1).join(' ');
          } else {
            amount = normalized;
          }
        }
        
        ingredients.add(Ingredient()
          ..name = name
          ..amount = amount
          ..unit = unit
          ..preparation = row.notesController.text.trim().isEmpty 
              ? null 
              : row.notesController.text.trim()
          ..section = currentSection);
      }

      // Parse directions from text
      final directions = _directionsController.text
          .split(RegExp(r'\n\s*\n'))
          .map((step) => step.trim())
          .where((step) => step.isNotEmpty)
          .toList();

      // Create or update recipe
      final recipe = _existingRecipe ?? Recipe();
      
      recipe
        ..uuid = (() {
          try {
            return recipe.uuid.isEmpty ? _uuid.v4() : recipe.uuid;
          } catch (_) {
            return _uuid.v4();
          }
        })()
        ..name = _nameController.text.trim()
        ..course = _selectedCourse
        ..cuisine = _selectedCuisine
        ..subcategory = _regionController.text.trim().isEmpty 
            ? null 
            : _regionController.text.trim()
        ..serves = _servesController.text.trim().isEmpty 
            ? null 
            : _servesController.text.trim()
        ..time = _timeController.text.trim().isEmpty 
            ? null 
            : _timeController.text.trim()
        ..notes = _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim()
        ..ingredients = ingredients
        ..directions = directions
        ..source = _existingRecipe?.source ?? 
            (widget.importedRecipe != null ? RecipeSource.imported : 
             widget.ocrText != null ? RecipeSource.ocr : RecipeSource.personal)
        ..nutrition = _buildNutritionInfo()
        ..imageUrl = _imagePath
        ..updatedAt = DateTime.now();

      // Save to database
      final repository = ref.read(recipeRepositoryProvider);
      await repository.saveRecipe(recipe);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${recipe.name} saved!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving recipe: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildIngredientRowWidget(int index, {Key? key}) {
    final theme = Theme.of(context);
    final row = _ingredientRows[index];
    final isLast = index == _ingredientRows.length - 1;
    
    // Section header row - spans full width with different styling
    if (row.isSection) {
      return Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
          border: isLast 
              ? null 
              : Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
        ),
        child: Row(
          children: [
            // Drag handle for reordering (touch-friendly)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            Icon(Icons.label_outline, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: row.nameController,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  border: const OutlineInputBorder(),
                  hintText: 'Section name (e.g., For the Glaze)',
                  hintStyle: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.outline,
                  ),
                  fillColor: theme.colorScheme.surface,
                  filled: true,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // More options menu for section
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: theme.colorScheme.outline,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'to_ingredient',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, size: 18),
                      SizedBox(width: 8),
                      Text('Convert to ingredient'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'insert_ingredient_above',
                  child: Row(
                    children: [
                      Icon(Icons.vertical_align_top, size: 18),
                      SizedBox(width: 8),
                      Text('Insert ingredient above'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'insert_ingredient_below',
                  child: Row(
                    children: [
                      Icon(Icons.vertical_align_bottom, size: 18),
                      SizedBox(width: 8),
                      Text('Insert ingredient below'),
                    ],
                  ),
                ),
                if (_ingredientRows.length > 1)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                      ],
                    ),
                  ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'to_ingredient':
                    setState(() => row.isSection = false);
                    break;
                  case 'insert_ingredient_above':
                    _insertIngredientAt(index);
                    break;
                  case 'insert_ingredient_below':
                    _insertIngredientAt(index + 1);
                    break;
                  case 'delete':
                    _removeIngredientRow(index);
                    break;
                }
              },
            ),
          ],
        ),
      );
    }
    
    // Regular ingredient row
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        border: isLast 
            ? null 
            : Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle for reordering (touch-friendly)
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Icon(
                Icons.drag_indicator,
                size: 20,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          // Ingredient name
          SizedBox(
            width: 120,
            child: TextField(
              controller: row.nameController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(),
                hintText: 'Ingredient',
                hintStyle: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.outline,
                ),
              ),
              style: theme.textTheme.bodyMedium,
              onChanged: (value) {
                // Auto-add new row when typing in last row
                if (isLast && value.isNotEmpty && !row.isSection) {
                  _addIngredientRow();
                  setState(() {});
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          
          // Amount
          SizedBox(
            width: 80,
            child: TextField(
              controller: row.amountController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(),
                hintText: 'Amount',
                hintStyle: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.outline,
                ),
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          
          // Notes/Prep
          Expanded(
            child: TextField(
              controller: row.notesController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(),
                hintText: 'Notes (optional)',
                hintStyle: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.outline,
                ),
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          
          // More options menu (convert to section, insert section, delete)
          SizedBox(
            width: 40,
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: theme.colorScheme.outline,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'to_section',
                  child: Row(
                    children: [
                      Icon(Icons.label_outline, size: 18),
                      SizedBox(width: 8),
                      Text('Convert to section'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'insert_section_above',
                  child: Row(
                    children: [
                      Icon(Icons.vertical_align_top, size: 18),
                      SizedBox(width: 8),
                      Text('Insert section above'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'insert_section_below',
                  child: Row(
                    children: [
                      Icon(Icons.vertical_align_bottom, size: 18),
                      SizedBox(width: 8),
                      Text('Insert section below'),
                    ],
                  ),
                ),
                if (_ingredientRows.length > 1)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                        const SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                      ],
                    ),
                  ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'to_section':
                    setState(() => row.isSection = true);
                    break;
                  case 'insert_section_above':
                    _insertSectionAt(index);
                    break;
                  case 'insert_section_below':
                    _insertSectionAt(index + 1);
                    break;
                  case 'delete':
                    _removeIngredientRow(index);
                    break;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _insertSectionAt(int index) {
    setState(() {
      _ingredientRows.insert(index, _IngredientRow(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
        notesController: TextEditingController(),
        isSection: true,
      ));
    });
  }

  void _insertIngredientAt(int index) {
    setState(() {
      _ingredientRows.insert(index, _IngredientRow(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
        notesController: TextEditingController(),
      ));
    });
  }

  // ============ IMAGE PICKER ============

  Widget _buildImagePicker(ThemeData theme) {
    final hasImage = _imagePath != null && _imagePath!.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipe Photo',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showImageSourceDialog,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: _buildImageWidget(),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _imageActionButton(
                              icon: Icons.edit,
                              onTap: _showImageSourceDialog,
                              theme: theme,
                            ),
                            const SizedBox(width: 8),
                            _imageActionButton(
                              icon: Icons.delete,
                              onTap: _removeImage,
                              theme: theme,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to add photo',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _imageActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Material(
      color: theme.colorScheme.surface.withOpacity(0.9),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (_imagePath == null) return const SizedBox.shrink();
    
    // Check if it's a URL or local file
    if (_imagePath!.startsWith('http://') || _imagePath!.startsWith('https://')) {
      return Image.network(
        _imagePath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, size: 48),
        ),
      );
    } else {
      // Local file
      return Image.file(
        File(_imagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, size: 48),
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imagePath != null && _imagePath!.startsWith('http'))
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Keep URL Image'),
                subtitle: Text(_imagePath!, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.pop(ctx),
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Copy to app documents directory for persistence
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/recipe_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final fileName = '${const Uuid().v4()}${path.extension(pickedFile.path)}';
        final savedFile = await File(pickedFile.path).copy('${imagesDir.path}/$fileName');

        setState(() {
          _imagePath = savedFile.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imagePath = null;
    });
  }

  void _showOcrText(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Scanned Text',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: SelectableText(
                    widget.ocrText ?? '',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spirit type selector for drinks/cocktails
class _SpiritSelector extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String?> onChanged;

  const _SpiritSelector({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currentValue = controller.text.isNotEmpty ? controller.text : null;
    final spirit = currentValue != null ? Spirit.lookup(currentValue) : null;
    
    return InkWell(
      onTap: () => _showSpiritSheet(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Spirit Type',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          spirit != null
              ? '${spirit.icon} ${spirit.name}'
              : currentValue ?? 'Select spirit (optional)',
          style: TextStyle(
            color: currentValue != null
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _showSpiritSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SpiritPickerSheet(
        selectedSpirit: controller.text.isNotEmpty ? controller.text : null,
        onChanged: (name) {
          onChanged(name);
          Navigator.pop(ctx);
        },
        onClear: () {
          onChanged(null);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

/// Bottom sheet with spirit list grouped by category
class _SpiritPickerSheet extends StatelessWidget {
  final String? selectedSpirit;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SpiritPickerSheet({
    required this.selectedSpirit,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = Spirit.byCategory;
    
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
                  'Select Spirit Type',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: ListView(
              controller: controller,
              children: grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    ...entry.value.map((spirit) {
                      final isSelected = selectedSpirit == spirit.name;
                      return ListTile(
                        leading: Text(spirit.icon, style: const TextStyle(fontSize: 24)),
                        title: Text(spirit.name),
                        trailing: isSelected
                            ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                            : null,
                        selected: isSelected,
                        onTap: () => onChanged(spirit.name),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuisine selector dropdown with grouped cuisines by continent
class _CuisineSelector extends StatelessWidget {
  final String? selectedCuisine;
  final ValueChanged<String?> onChanged;

  const _CuisineSelector({
    required this.selectedCuisine,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showCuisineSheet(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Cuisine',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedCuisine != null
              ? '${Cuisine.byCode(selectedCuisine!)?.flag ?? ''} ${Cuisine.byCode(selectedCuisine!)?.name ?? selectedCuisine}'
              : 'Select cuisine (optional)',
          style: TextStyle(
            color: selectedCuisine != null
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
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
        selectedCuisine: selectedCuisine,
        onChanged: (code) {
          onChanged(code);
          Navigator.pop(ctx);
        },
        onClear: () {
          onChanged(null);
          Navigator.pop(ctx);
        },
      ),
    );
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

/// Helper class to hold controllers for a single ingredient row
class _IngredientRow {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController notesController;
  bool isSection; // True if this is a section header (e.g., "For the Glaze")

  _IngredientRow({
    required this.nameController,
    required this.amountController,
    required this.notesController,
    this.isSection = false,
  });

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    notesController.dispose();
  }
}
