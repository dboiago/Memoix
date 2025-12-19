import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../core/widgets/memoix_snackbar.dart';
import '../../../core/utils/text_normalizer.dart';
import '../models/category.dart';
import '../models/recipe.dart';
import '../models/cuisine.dart';
import '../models/spirit.dart';
import '../repository/recipe_repository.dart';
import 'recipe_detail_screen.dart';

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
  late final TextEditingController _regionController;

  // Nutrition controllers
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;

  // 3-column ingredient editing: list of (name, amount, notes) controllers
  final List<_IngredientRow> _ingredientRows = [];
  
  // Direction rows for individual step editing with images
  final List<_DirectionRow> _directionRows = [];
  final List<String> _stepImages = [];
  final Map<int, int> _stepImageMap = {}; // stepIndex -> imageIndex in _stepImages

  String _selectedCourse = 'mains';
  String? _selectedCuisine;
  List<String> _imagePaths = []; // Header images - local file paths or URLs
  bool _isSaving = false;
  bool _isLoading = true;
  Recipe? _existingRecipe;
  bool _showBakerPercent = false; // Toggle for showing baker's percentage column

  // Drinks-specific fields
  String? _glass;
  final List<String> _garnish = [];
  TextEditingController? _garnishFieldController;

  // Pickles-specific fields
  String? _pickleMethod;

  // Paired recipe IDs (for linking related recipes)
  final List<String> _pairedRecipeIds = [];

  bool get _isEditing => _existingRecipe != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _servesController = TextEditingController();
    _timeController = TextEditingController();
    _notesController = TextEditingController();
    _regionController = TextEditingController();
    _caloriesController = TextEditingController();
    _proteinController = TextEditingController();
    _carbsController = TextEditingController();
    _fatController = TextEditingController();

    if (widget.defaultCourse != null) {
      _selectedCourse = _normaliseCourseSlug(widget.defaultCourse!.toLowerCase());
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
      _selectedCourse = _normaliseCourseSlug(recipe.course.toLowerCase() ?? _selectedCourse);
      _selectedCuisine = recipe.cuisine;

      // Check if any ingredient has baker's percentage - auto-show column if so
      if (recipe.ingredients.any((i) => i.bakerPercent != null && i.bakerPercent!.isNotEmpty)) {
        _showBakerPercent = true;
      }

      // Convert ingredients to 3-column row controllers
      // Track sections to insert section headers
      String? lastSection;
      for (final ingredient in recipe.ingredients) {
        // If this ingredient has a different section, add a section header
        if (ingredient.section != null && ingredient.section != lastSection) {
          _addIngredientRow(name: ingredient.section!, isSection: true);
          lastSection = ingredient.section;
        }
        
        // Skip ingredients with empty names (section-only markers from import)
        if (ingredient.name.isEmpty) {
          continue;
        }
        
        // Combine preparation and alternative into notes field
        final notesParts = <String>[
          if (ingredient.preparation != null && ingredient.preparation!.isNotEmpty)
            ingredient.preparation!,
          if (ingredient.alternative != null && ingredient.alternative!.isNotEmpty)
            ingredient.alternative!,
        ];
        _addIngredientRow(
          name: ingredient.name,
          amount: ingredient.displayAmount,
          notes: notesParts.join('; '),
          bakerPercent: ingredient.bakerPercent ?? '',
        );
      }

      // Load directions into rows
      for (final direction in recipe.directions) {
        _addDirectionRow(text: direction);
      }
      
      // Load step images
      _stepImages.addAll(recipe.stepImages);
      // Convert stepImageMap from List<String> "stepIndex:imageIndex" to Map<int, int>
      for (final mapping in recipe.stepImageMap) {
        final parts = mapping.split(':');
        if (parts.length == 2) {
          final stepIndex = int.tryParse(parts[0]);
          final imageIndex = int.tryParse(parts[1]);
          if (stepIndex != null && imageIndex != null) {
            _stepImageMap[stepIndex] = imageIndex;
          }
        }
      }
      
      // Load header images only (first image from getFirstImage)
      final firstImage = recipe.getFirstImage();
      if (firstImage != null && firstImage.isNotEmpty) {
        _imagePaths = [firstImage];
      }
      
      // Load drinks-specific fields
      _glass = recipe.glass;
      _garnish.clear();
      _garnish.addAll(recipe.garnish);
      
      // Load pickles-specific fields
      _pickleMethod = recipe.pickleMethod;
      
      // Load paired recipe IDs
      _pairedRecipeIds.clear();
      _pairedRecipeIds.addAll(recipe.pairedRecipeIds);
    } else if (widget.ocrText != null) {
      // Pre-populate with OCR text for manual extraction
      _notesController.text = 'OCR Text:\n${widget.ocrText}';
    }

    // Always have at least one empty row at the end for adding ingredients
    if (_ingredientRows.isEmpty) {
      // For salads, add a Dressing section after initial ingredients
      if (_selectedCourse == 'salad') {
        _addIngredientRow(); // Empty row for salad ingredients
        _addIngredientRow(name: 'Dressing', isSection: true);
        _addIngredientRow(); // Empty row for dressing ingredients
      } else {
        _addIngredientRow();
      }
    } else {
      // Insert blank rows before each section header (so users can add ingredients above sections)
      // Work backwards to avoid index shifting issues
      for (int i = _ingredientRows.length - 1; i >= 0; i--) {
        if (_ingredientRows[i].isSection) {
          // Check if there's already a blank row before this section
          final hasPrecedingBlank = i > 0 && 
              _ingredientRows[i - 1].nameController.text.isEmpty &&
              _ingredientRows[i - 1].amountController.text.isEmpty &&
              !_ingredientRows[i - 1].isSection;
          
          if (!hasPrecedingBlank) {
            // Insert blank row before this section
            _ingredientRows.insert(i, _IngredientRow(
              nameController: TextEditingController(),
              amountController: TextEditingController(),
              notesController: TextEditingController(),
              bakerPercentController: TextEditingController(),
            ));
          }
        }
      }
      
      // Add blank row at end for existing recipes (for adding more)
      final lastRow = _ingredientRows.last;
      final lastIsEmpty = lastRow.nameController.text.isEmpty && 
                          lastRow.amountController.text.isEmpty && 
                          !lastRow.isSection;
      if (!lastIsEmpty) {
        _addIngredientRow();
      }
    }
    
    // Always have at least one direction row, and ensure blank row at end for adding more
    if (_directionRows.isEmpty) {
      _addDirectionRow();
    } else {
      // Add blank row at end for existing recipes (for adding more)
      final lastRow = _directionRows.last;
      if (lastRow.controller.text.isNotEmpty) {
        _addDirectionRow();
      }
    }

    setState(() => _isLoading = false);
  }

  /// Normalise course slug to match dropdown values
  String _normaliseCourseSlug(String course) {
    // First convert to lowercase
    final lower = course.toLowerCase();
    
    // Handle special mappings
    const mapping = {
      'soups': 'soup',
      'salads': 'salad',
      'not-meat': 'vegn',
      'not meat': 'vegn',
      'vegetarian': 'vegn',
      "veg'n": 'vegn',
    };
    
    final mapped = mapping[lower] ?? lower;
    
    // Ensure the result is a valid dropdown value
    const validSlugs = {
      'apps', 'soup', 'mains', 'vegn', 'sides', 'salad', 'desserts', 
      'brunch', 'drinks', 'breads', 'sauces', 'rubs', 'pickles', 
      'modernist', 'pizzas', 'sandwiches', 'smoking', 'cheese', 'scratch'
    };
    
    return validSlugs.contains(mapped) ? mapped : 'mains';
  }

  void _addIngredientRow({String name = '', String amount = '', String notes = '', String bakerPercent = '', bool isSection = false}) {
    _ingredientRows.add(_IngredientRow(
      nameController: TextEditingController(text: name),
      amountController: TextEditingController(text: amount),
      notesController: TextEditingController(text: notes),
      bakerPercentController: TextEditingController(text: bakerPercent),
      isSection: isSection,
    ),);
  }

  void _addSectionHeader() {
    _ingredientRows.add(_IngredientRow(
      nameController: TextEditingController(),
      amountController: TextEditingController(),
      notesController: TextEditingController(),
      bakerPercentController: TextEditingController(),
      isSection: true,
    ),);
    setState(() {});
  }

  void _removeIngredientRow(int index) {
    if (_ingredientRows.length > 1) {
      final row = _ingredientRows.removeAt(index);
      row.dispose();
      setState(() {});
    }
  }

  void _addDirectionRow({String text = ''}) {
    _directionRows.add(_DirectionRow(
      controller: TextEditingController(text: text),
    ),);
  }

  void _removeDirectionRow(int index) {
    if (_directionRows.length > 1) {
      // Remove image association if exists
      _stepImageMap.remove(index);
      // Update indices for rows after this one
      final newMap = <int, int>{};
      for (final entry in _stepImageMap.entries) {
        if (entry.key > index) {
          newMap[entry.key - 1] = entry.value;
        } else {
          newMap[entry.key] = entry.value;
        }
      }
      _stepImageMap.clear();
      _stepImageMap.addAll(newMap);
      
      final row = _directionRows.removeAt(index);
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
    _regionController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    for (final row in _directionRows) {
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

  Widget _buildDirectionRowWidget(int index, ThemeData theme, {Key? key}) {
    final row = _directionRows[index];
    final isLast = index == _directionRows.length - 1;
    final hasImage = _stepImageMap.containsKey(index);
    final imageIndex = _stepImageMap[index];

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle and step number
          Column(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
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

          // Direction text field
          Expanded(
            child: TextField(
              controller: row.controller,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: const OutlineInputBorder(),
                hintText: 'Enter step ${index + 1}...',
                hintStyle: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.outline,
                ),
              ),
              maxLines: 3,
              minLines: 2,
              style: theme.textTheme.bodyMedium,
              onChanged: (value) {
                // Auto-add new row when typing in last row
                if (isLast && value.isNotEmpty) {
                  _addDirectionRow();
                  setState(() {});
                }
              },
            ),
          ),
          const SizedBox(width: 8),

          // Image picker and delete buttons
          Column(
            children: [
              // Image picker button
              IconButton(
                icon: Icon(
                  hasImage ? Icons.image : Icons.add_photo_alternate_outlined,
                  size: 20,
                  color: hasImage ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
                tooltip: hasImage ? 'Image #${imageIndex! + 1} attached' : 'Add image for this step',
                onPressed: () => _pickStepImage(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              // Remove image if has one
              if (hasImage)
                IconButton(
                  icon: Icon(
                    Icons.link_off,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  tooltip: 'Remove image link',
                  onPressed: () {
                    setState(() => _stepImageMap.remove(index));
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              // Delete button
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
                onPressed: _directionRows.length > 1
                    ? () => _removeDirectionRow(index)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepImagesGallery(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Gallery',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_stepImages.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Images attached to steps above',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _stepImages.length,
            itemBuilder: (context, index) {
              // Find which step(s) use this image
              final stepsUsingImage = _stepImageMap.entries
                  .where((e) => e.value == index)
                  .map((e) => e.key + 1)
                  .toList();

              return Padding(
                padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildStepImageWidget(_stepImages[index], width: 100, height: 100),
                    ),
                    // Step numbers badge
                    if (stepsUsingImage.isNotEmpty)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            stepsUsingImage.map((s) => '#$s').join(', '),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    // Delete button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: theme.colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              // Remove all step associations to this image
                              _stepImageMap.removeWhere((k, v) => v == index);
                              // Update indices for images after this one
                              final newMap = <int, int>{};
                              for (final entry in _stepImageMap.entries) {
                                if (entry.value > index) {
                                  newMap[entry.key] = entry.value - 1;
                                } else {
                                  newMap[entry.key] = entry.value;
                                }
                              }
                              _stepImageMap.clear();
                              _stepImageMap.addAll(newMap);
                              _stepImages.removeAt(index);
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStepImageWidget(String imagePath, {double? width, double? height}) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image),
        ),
      );
    } else {
      return Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image),
        ),
      );
    }
  }

  Future<void> _pickStepImage(int stepIndex) async {
    // Show dialog to pick new image or select existing step image
    if (_stepImages.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_photo_alternate),
                title: const Text('Add New Image'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickNewStepImage(stepIndex);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Existing Step Images'),
                onTap: () {
                  Navigator.pop(ctx);
                  _selectExistingStepImage(stepIndex);
                },
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
    } else {
      _pickNewStepImage(stepIndex);
    }
  }

  void _selectExistingStepImage(int stepIndex) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Image'),
        content: SizedBox(
          width: 300,
          height: 200,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _stepImages.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  setState(() => _stepImageMap[stepIndex] = index);
                  Navigator.pop(ctx);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildStepImageWidget(_stepImages[index]),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickNewStepImage(int stepIndex) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/recipe_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final fileName = '${_uuid.v4()}${path.extension(pickedFile.path)}';
        final savedFile = await File(pickedFile.path).copy('${imagesDir.path}/$fileName');

        setState(() {
          _stepImages.add(savedFile.path);
          _stepImageMap[stepIndex] = _stepImages.length - 1;
        });
      }
    } catch (e) {
      MemoixSnackBar.showError('Error picking image: $e');
    }
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
              initialValue: _selectedCourse,
              decoration: const InputDecoration(
                labelText: 'Category *',
              ),
              items: const [
                DropdownMenuItem(value: 'apps', child: Text('Apps')),
                DropdownMenuItem(value: 'soup', child: Text('Soup')),
                DropdownMenuItem(value: 'mains', child: Text('Mains')),
                DropdownMenuItem(value: 'vegn', child: Text("Veg'n")),
                DropdownMenuItem(value: 'sides', child: Text('Sides')),
                DropdownMenuItem(value: 'salad', child: Text('Salad')),
                DropdownMenuItem(value: 'desserts', child: Text('Desserts')),
                DropdownMenuItem(value: 'brunch', child: Text('Brunch')),
                DropdownMenuItem(value: 'drinks', child: Text('Drinks')),
                DropdownMenuItem(value: 'breads', child: Text('Breads')),
                DropdownMenuItem(value: 'sauces', child: Text('Sauces')),
                DropdownMenuItem(value: 'rubs', child: Text('Rubs')),
                DropdownMenuItem(value: 'pickles', child: Text('Pickles')),
                DropdownMenuItem(value: 'modernist', child: Text('Modernist')),
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
                        row.amountController.text.isEmpty,);
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

            // Glass and Garnish (Drinks only) - side by side
            if (_selectedCourse == 'drinks') ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildGlassSection(theme)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGarnishSection(theme)),
                ],
              ),
            ],

            // Pickle Method (Pickles only)
            if (_selectedCourse == 'pickles') ...[
              const SizedBox(height: 16),
              _buildPickleMethodSection(theme),
            ],

            // Pairs With selector (only for courses that support pairing)
            if (_supportsPairingForCourse(_selectedCourse)) ...[
              const SizedBox(height: 16),
              _buildPairsWithSection(theme),
            ],

            const SizedBox(height: 24),

            // Ingredients (3-column spreadsheet layout)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Ingredients',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Baker's percentage toggle (only for Bread and Dessert)
                    if (_selectedCourse == 'breads' || _selectedCourse == 'desserts')
                      TextButton.icon(
                        onPressed: () => setState(() => _showBakerPercent = !_showBakerPercent),
                        icon: Icon(
                          _showBakerPercent ? Icons.percent : Icons.percent_outlined,
                          size: 18,
                          color: _showBakerPercent ? theme.colorScheme.primary : null,
                        ),
                        label: Text(
                          'BK%',
                          style: TextStyle(
                            color: _showBakerPercent ? theme.colorScheme.primary : null,
                          ),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _addSectionHeader,
                      icon: const Icon(Icons.title, size: 18),
                      label: const Text('Section'),
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
                      Expanded(
                        flex: _showBakerPercent ? 2 : 3,
                        child: Text('Ingredient', 
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_showBakerPercent) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 65,
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
                        return _buildIngredientRowWidget(
                          index, 
                          hasBakerPercent: _showBakerPercent,
                          key: ValueKey(_ingredientRows[index]),
                        );
                      },
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Directions section with step images
            Text(
              'Directions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add steps and optionally attach images to each step',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _directionRows.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final row = _directionRows.removeAt(oldIndex);
                  _directionRows.insert(newIndex, row);
                  // Update step image map
                  final newMap = <int, int>{};
                  for (final entry in _stepImageMap.entries) {
                    int newKey = entry.key;
                    if (entry.key == oldIndex) {
                      newKey = newIndex;
                    } else if (entry.key > oldIndex && entry.key <= newIndex) {
                      newKey = entry.key - 1;
                    } else if (entry.key < oldIndex && entry.key >= newIndex) {
                      newKey = entry.key + 1;
                    }
                    newMap[newKey] = entry.value;
                  }
                  _stepImageMap.clear();
                  _stepImageMap.addAll(newMap);
                });
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Material(
                      elevation: 4,
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                return _buildDirectionRowWidget(index, theme, key: ValueKey(_directionRows[index]));
              },
            ),
            
            // Step Images Gallery
            if (_stepImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildStepImagesGallery(theme),
            ],

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
      MemoixSnackBar.showError('Please enter a recipe name');
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
        
        // Get baker's percentage if present
        final bakerPercent = row.bakerPercentController.text.trim();
        
        ingredients.add(Ingredient()
          ..name = name
          ..amount = amount
          ..unit = unit
          ..preparation = row.notesController.text.trim().isEmpty 
              ? null 
              : row.notesController.text.trim()
          ..section = currentSection
          ..bakerPercent = bakerPercent.isEmpty ? null : bakerPercent,);
      }

      // Parse directions from rows
      final directions = _directionRows
          .map((row) => row.controller.text.trim())
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
        ..imageUrls = _imagePaths
        ..imageUrl = _imagePaths.isNotEmpty ? _imagePaths.first : null
        ..stepImages = _stepImages
        ..stepImageMap = _stepImageMap.entries
            .map((e) => '${e.key}:${e.value}')
            .toList()
        ..glass = _selectedCourse == 'drinks' ? _glass : null
        ..garnish = _selectedCourse == 'drinks' ? _garnish : []
        ..pickleMethod = _selectedCourse == 'pickles' ? _pickleMethod : null
        ..pairedRecipeIds = _supportsPairingForCourse(_selectedCourse) ? _pairedRecipeIds : []
        ..updatedAt = DateTime.now();

      // Save to database
      final repository = ref.read(recipeRepositoryProvider);
      await repository.saveRecipe(recipe);
      final savedId = recipe.uuid;
      final recipeName = recipe.name;

      if (mounted) {
        // Capture navigator before popping
        final navigator = Navigator.of(context);
        
        // Pop first
        navigator.pop();
        
        // Use MemoixSnackBar for snackbar after navigation
        MemoixSnackBar.showSaved(
          itemName: recipeName,
          actionLabel: 'View',
          onView: () {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(recipeId: savedId),
              ),
            );
          },
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      MemoixSnackBar.showError('Error saving recipe: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildIngredientRowWidget(int index, {bool hasBakerPercent = false, Key? key}) {
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
                        Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: theme.colorScheme.secondary)),
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
          Expanded(
            flex: hasBakerPercent ? 2 : 3,
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
                // Auto-add new row when typing in last row OR last row before a section
                if (value.isNotEmpty && !row.isSection) {
                  // Check if next row is a section header
                  final nextIsSection = index < _ingredientRows.length - 1 &&
                      _ingredientRows[index + 1].isSection;
                  
                  if (isLast) {
                    // Append at the end
                    _addIngredientRow();
                    setState(() {});
                  } else if (nextIsSection) {
                    // Insert a new row between this ingredient and the section
                    _insertIngredientAt(index + 1);
                  }
                }
              },
            ),
          ),
          // Baker's percentage (only shown when any ingredient has it)
          if (hasBakerPercent) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 65,
              child: TextField(
                controller: row.bakerPercentController,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  border: const OutlineInputBorder(),
                  hintText: '%',
                  hintStyle: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.outline,
                  ),
                ),
                style: theme.textTheme.bodyMedium,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
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
            flex: 2,
            child: TextField(
              controller: row.notesController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(),
                hintText: 'Notes',
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
                        Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.secondary),
                        const SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: theme.colorScheme.secondary)),
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
        bakerPercentController: TextEditingController(),
        isSection: true,
      ),);
    });
  }

  void _insertIngredientAt(int index) {
    setState(() {
      _ingredientRows.insert(index, _IngredientRow(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
        notesController: TextEditingController(),
        bakerPercentController: TextEditingController(),
      ),);
    });
  }

  // ============ IMAGE PICKER ============

  Widget _buildImagePicker(ThemeData theme) {
    final hasImages = _imagePaths.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipe Photos',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (hasImages)
          _buildImageGallery(theme)
        else
          _buildEmptyImagePicker(theme),
      ],
    );
  }

  Widget _buildEmptyImagePicker(ThemeData theme) {
    return GestureDetector(
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
        child: Center(
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
                'Tap to add photos',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGallery(ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _imagePaths.length + 1, // +1 for add button
            itemBuilder: (context, index) {
              if (index == _imagePaths.length) {
                // Add more button
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      width: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add,
                            size: 32,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              
              return Padding(
                padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImageWidget(_imagePaths[index], width: 100, height: 120),
                    ),
                    // Image number badge
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    // Remove button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _imageActionButton(
                        icon: Icons.close,
                        onTap: () => _removeImage(index),
                        theme: theme,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _imageActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
    double size = 20,
  }) {
    return Material(
      color: theme.colorScheme.surface.withOpacity(0.9),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: size, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imagePath, {double? width, double? height}) {
    // Check if it's a URL or local file
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox(
          width: width,
          height: height,
          child: const Center(child: Icon(Icons.broken_image, size: 32)),
        ),
      );
    } else {
      // Local file
      return Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox(
          width: width,
          height: height,
          child: const Center(child: Icon(Icons.broken_image, size: 32)),
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
            ListTile(
              leading: const Icon(Icons.collections),
              title: const Text('Choose Multiple Photos'),
              onTap: () {
                Navigator.pop(ctx);
                _pickMultipleImages();
              },
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
          _imagePaths.add(savedFile.path);
        });
      }
    } catch (e) {
      MemoixSnackBar.showError('Error picking image: $e');
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        // Copy to app documents directory for persistence
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/recipe_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        for (final pickedFile in pickedFiles) {
          final fileName = '${const Uuid().v4()}${path.extension(pickedFile.path)}';
          final savedFile = await File(pickedFile.path).copy('${imagesDir.path}/$fileName');
          _imagePaths.add(savedFile.path);
        }

        setState(() {});
      }
    } catch (e) {
      MemoixSnackBar.showError('Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imagePaths.removeAt(index);
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

  /// Build Glass section for drinks
  Widget _buildGlassSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Glass',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (value) {
            final suggestions = _glassSuggestions.where(
              (s) => s.toLowerCase().contains(value.text.toLowerCase()),
            );
            return suggestions;
          },
          initialValue: TextEditingValue(text: _glass ?? ''),
          onSelected: (value) {
            setState(() => _glass = value);
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                hintText: 'e.g., Coupe, Highball, Rocks',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (value) {
                _glass = value.isEmpty ? null : value;
              },
            );
          },
        ),
      ],
    );
  }

  /// Build Garnish section for drinks
  Widget _buildGarnishSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Garnish',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (value) {
            final suggestions = _garnishSuggestions.where(
              (s) => s.toLowerCase().contains(value.text.toLowerCase()) &&
                     !_garnish.contains(s),
            );
            return suggestions;
          },
          onSelected: (value) {
            final normalized = normalizeGarnish(value);
            if (!_garnish.contains(normalized)) {
              setState(() => _garnish.add(normalized));
              _garnishFieldController?.clear();
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            _garnishFieldController = controller;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Add garnish...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isNotEmpty) {
                      final normalized = normalizeGarnish(value);
                      if (!_garnish.contains(normalized)) {
                        setState(() => _garnish.add(normalized));
                        controller.clear();
                      }
                    }
                  },
                ),
              ),
              textCapitalization: TextCapitalization.words,
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  final normalized = normalizeGarnish(value);
                  if (!_garnish.contains(normalized)) {
                    setState(() => _garnish.add(normalized));
                    controller.clear();
                  }
                }
              },
            );
          },
        ),
        if (_garnish.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _garnish.map((item) => Chip(
              label: Text(item),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () => setState(() => _garnish.remove(item)),
            )).toList(),
          ),
        ],
      ],
    );
  }

  /// Build Pickle Method section for pickles
  Widget _buildPickleMethodSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Method',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (value) {
            final suggestions = _pickleMethodSuggestions.where(
              (s) => s.toLowerCase().contains(value.text.toLowerCase()),
            );
            return suggestions;
          },
          initialValue: TextEditingValue(text: _pickleMethod ?? ''),
          onSelected: (value) {
            setState(() => _pickleMethod = value);
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                hintText: 'e.g., Quick Pickle, Fermentation',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (value) {
                _pickleMethod = value.isEmpty ? null : value;
              },
            );
          },
        ),
      ],
    );
  }

  /// Common pickle methods for autocomplete
  static const List<String> _pickleMethodSuggestions = [
    'Quick Pickle',
    'Refrigerator Pickle',
    'Fermentation',
    'Lacto-Fermentation',
    'Brine',
    'Vinegar Pickle',
    'Salt Cure',
    'Dry Brine',
    'Water Bath Canning',
    'Pressure Canning',
  ];

  /// Check if a course supports pairing with other recipes.
  /// Excluded: pizzas, sandwiches, cellar, cheese (component assemblies or non-recipes)
  bool _supportsPairingForCourse(String course) {
    const excludedCourses = {'pizzas', 'sandwiches', 'cellar', 'cheese'};
    return !excludedCourses.contains(course.toLowerCase());
  }

  /// Build the "Pairs With" section for linking related recipes
  Widget _buildPairsWithSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pairs With',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Display current paired recipes as chips
        if (_pairedRecipeIds.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _pairedRecipeIds.map((uuid) {
              // Get recipe info for display
              final allRecipesAsync = ref.watch(allRecipesProvider);
              final allRecipes = allRecipesAsync.valueOrNull ?? [];
              final recipe = allRecipes.where((r) => r.uuid == uuid).firstOrNull;
              final name = recipe?.name ?? 'Unknown';
              final course = recipe?.course ?? 'mains';
              
              return Chip(
                avatar: Icon(
                  _iconForCourse(course),
                  size: 16,
                  color: theme.colorScheme.onSurface,
                ),
                label: Text(name),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                visualDensity: VisualDensity.compact,
                deleteIcon: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurface),
                onDeleted: () {
                  setState(() {
                    _pairedRecipeIds.remove(uuid);
                  });
                },
              );
            }).toList(),
          ),
        // Add button if under limit of 3
        if (_pairedRecipeIds.length < 3) ...[
          if (_pairedRecipeIds.isNotEmpty) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showRecipeSelector,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Recipe'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ],
    );
  }

  /// Get the Material icon for a course category slug
  IconData _iconForCourse(String course) {
    switch (course.toLowerCase()) {
      case 'apps':
        return Icons.restaurant;
      case 'soup':
      case 'soups':
        return Icons.soup_kitchen;
      case 'mains':
        return Icons.dinner_dining;
      case 'vegn':
        return Icons.eco;
      case 'sides':
        return Icons.rice_bowl;
      case 'salad':
      case 'salads':
        return Icons.grass;
      case 'desserts':
        return Icons.cake;
      case 'brunch':
        return Icons.egg_alt;
      case 'drinks':
        return Icons.local_bar;
      case 'breads':
        return Icons.bakery_dining;
      case 'sauces':
        return Icons.water_drop;
      case 'rubs':
        return Icons.local_fire_department;
      case 'pickles':
        return Icons.local_florist;
      case 'modernist':
        return Icons.science;
      case 'smoking':
        return Icons.outdoor_grill;
      case 'scratch':
        return Icons.note_alt;
      default:
        return Icons.restaurant_menu;
    }
  }

  /// Show a dialog to select a recipe to pair with
  void _showRecipeSelector() {
    final allRecipesAsync = ref.read(allRecipesProvider);
    final allRecipes = allRecipesAsync.valueOrNull ?? [];
    
    // Filter out: current recipe, already paired, and recipes from excluded courses
    final availableRecipes = allRecipes.where((r) {
      // Exclude current recipe
      if (_existingRecipe != null && r.uuid == _existingRecipe!.uuid) return false;
      // Exclude already paired
      if (_pairedRecipeIds.contains(r.uuid)) return false;
      // Exclude recipes that don't support pairing
      if (!r.supportsPairing) return false;
      return true;
    }).toList();
    
    // Sort alphabetically by name
    availableRecipes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    final theme = Theme.of(context);
    final searchController = TextEditingController();
    var filteredRecipes = List<Recipe>.from(availableRecipes);
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Select Recipe'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search recipes...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (query) {
                      setDialogState(() {
                        if (query.isEmpty) {
                          filteredRecipes = List<Recipe>.from(availableRecipes);
                        } else {
                          filteredRecipes = availableRecipes.where((r) =>
                            r.name.toLowerCase().contains(query.toLowerCase()) ||
                            (r.cuisine?.toLowerCase().contains(query.toLowerCase()) ?? false)
                          ).toList();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filteredRecipes.isEmpty
                      ? Center(
                          child: Text(
                            'No recipes found',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredRecipes.length,
                          itemBuilder: (context, index) {
                            final recipe = filteredRecipes[index];
                            return ListTile(
                              leading: Icon(
                                _iconForCourse(recipe.course),
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(recipe.name),
                              subtitle: Text(
                                Category.displayNameFromSlug(recipe.course),
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              dense: true,
                              onTap: () {
                                setState(() {
                                  _pairedRecipeIds.add(recipe.uuid);
                                });
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Common glass types for autocomplete
  static const List<String> _glassSuggestions = [
    'Coupe',
    'Highball',
    'Rocks',
    'Collins',
    'Martini',
    'Nick & Nora',
    'Old Fashioned',
    'Wine Glass',
    'Flute',
    'Hurricane',
    'Copper Mug',
    'Julep Cup',
    'Tiki Mug',
    'Shot Glass',
    'Snifter',
    'Goblet',
    'Tumbler',
    'Pint Glass',
    'Margarita Glass',
    'Pilsner',
  ];

  /// Common garnish types for autocomplete
  static const List<String> _garnishSuggestions = [
    'Lemon twist',
    'Lemon wheel',
    'Lemon wedge',
    'Lime twist',
    'Lime wheel',
    'Lime wedge',
    'Orange twist',
    'Orange wheel',
    'Orange slice',
    'Cherry',
    'Maraschino cherry',
    'Luxardo cherry',
    'Olive',
    'Cocktail onion',
    'Mint sprig',
    'Basil leaf',
    'Rosemary sprig',
    'Cucumber slice',
    'Celery stalk',
    'Pineapple wedge',
    'Edible flower',
    'Salt rim',
    'Sugar rim',
    'Tajin rim',
    'Cinnamon stick',
    'Nutmeg (grated)',
    'Coffee beans',
    'Candied ginger',
    'Pickled jalapeño',
    'Bacon strip',
  ];
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
              ? spirit.name
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
      c.code.toLowerCase().contains(query),
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
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),),
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
  final TextEditingController bakerPercentController;
  bool isSection; // True if this is a section header (e.g., "For the Glaze")

  _IngredientRow({
    required this.nameController,
    required this.amountController,
    required this.notesController,
    required this.bakerPercentController,
    this.isSection = false,
  });

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    notesController.dispose();
    bakerPercentController.dispose();
  }
}

/// Helper class for direction rows
class _DirectionRow {
  final TextEditingController controller;

  _DirectionRow({required this.controller});

  void dispose() {
    controller.dispose();
  }
}
