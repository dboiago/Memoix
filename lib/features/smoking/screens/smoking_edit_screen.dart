import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../core/utils/suggestions.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../modernist/models/modernist_recipe.dart';
import '../../modernist/screens/modernist_edit_screen.dart';
import '../../recipes/models/course.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
import '../models/smoking_recipe.dart';
import '../repository/smoking_repository.dart';

/// Edit/create screen for smoking recipes
class SmokingEditScreen extends ConsumerStatefulWidget {
  final String? recipeId;
  final SmokingRecipe? importedRecipe;

  const SmokingEditScreen({
    super.key,
    this.recipeId,
    this.importedRecipe,
  });

  @override
  ConsumerState<SmokingEditScreen> createState() => _SmokingEditScreenState();
}

class _SmokingEditScreenState extends ConsumerState<SmokingEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _itemController = TextEditingController();
  final _categoryController = TextEditingController();
  SmokingType _selectedType = SmokingType.pitNote;
  final _temperatureController = TextEditingController();
  final _timeController = TextEditingController();
  final _woodController = TextEditingController();
  final _notesController = TextEditingController();
  final _servesController = TextEditingController();

  String? _imagePath; // Header image - local file path or URL
  final List<String> _stepImages = []; // Step images
  final Map<int, int> _stepImageMap = {}; // stepIndex -> imageIndex in _stepImages
  final List<_SeasoningEntry> _seasonings = [];
  final List<_SeasoningEntry> _ingredients = []; // For Recipe type
  final List<TextEditingController> _directionControllers = [];

  /// Paired recipe IDs (for linking related recipes)
  final List<String> _pairedRecipeIds = [];

  /// Selected course for this recipe
  String _selectedCourse = 'smoking';

  bool _isLoading = true;
  SmokingRecipe? _existingRecipe;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    // Check for imported recipe first
    if (widget.importedRecipe != null) {
      final recipe = widget.importedRecipe!;
      _nameController.text = recipe.name;
      _selectedType = recipe.type;
      _itemController.text = recipe.item ?? '';
      _categoryController.text = recipe.category ?? '';
      _temperatureController.text = recipe.temperature;
      _timeController.text = recipe.time;
      _woodController.text = recipe.wood;
      _notesController.text = recipe.notes ?? '';
      _servesController.text = recipe.serves ?? '';
      // Filter stepImages to exclude header image to prevent duplicates
      _imagePath = recipe.getFirstImage();
      final headerImg = _imagePath;
      _stepImages.addAll(
        recipe.stepImages.where((img) => headerImg == null || img != headerImg),
      );
      
      // Load step image mappings
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

      for (final seasoning in recipe.seasonings) {
        _seasonings.add(_SeasoningEntry(
          nameController: TextEditingController(text: seasoning.name),
          amountController: TextEditingController(text: seasoning.amount ?? ''),
        ),);
      }

      for (final ingredient in recipe.ingredients) {
        _ingredients.add(_SeasoningEntry(
          nameController: TextEditingController(text: ingredient.name),
          amountController: TextEditingController(text: ingredient.amount ?? ''),
        ),);
      }

      for (final direction in recipe.directions) {
        _directionControllers.add(TextEditingController(text: direction));
      }
      
      // Load paired recipe IDs
      _pairedRecipeIds.addAll(recipe.pairedRecipeIds);
      
      // Load course
      _selectedCourse = recipe.course;
    } else if (widget.recipeId != null) {
      final recipe = await ref
          .read(smokingRepositoryProvider)
          .getRecipeByUuid(widget.recipeId!);
      if (recipe != null) {
        _existingRecipe = recipe;
        _nameController.text = recipe.name;
        _selectedType = recipe.type;
        _itemController.text = recipe.item ?? '';
        _categoryController.text = recipe.category ?? '';
        _temperatureController.text = recipe.temperature;
        _timeController.text = recipe.time;
        _woodController.text = recipe.wood;
        _notesController.text = recipe.notes ?? '';
        _servesController.text = recipe.serves ?? '';
        // Filter stepImages to exclude header image to prevent duplicates
        _imagePath = recipe.getFirstImage();
        final headerImg = _imagePath;
        _stepImages.addAll(
          recipe.stepImages.where((img) => headerImg == null || img != headerImg),
        );
        
        // Load step image mappings
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

        for (final seasoning in recipe.seasonings) {
          _seasonings.add(_SeasoningEntry(
            nameController: TextEditingController(text: seasoning.name),
            amountController: TextEditingController(text: seasoning.amount ?? ''),
          ),);
        }

        for (final ingredient in recipe.ingredients) {
          _ingredients.add(_SeasoningEntry(
            nameController: TextEditingController(text: ingredient.name),
            amountController: TextEditingController(text: ingredient.amount ?? ''),
          ),);
        }

        for (final direction in recipe.directions) {
          _directionControllers.add(TextEditingController(text: direction));
        }
        
        // Load paired recipe IDs
        _pairedRecipeIds.addAll(recipe.pairedRecipeIds);
        
        // Load course
        _selectedCourse = recipe.course;
      }
    }

    // Ensure at least one empty field for each
    if (_seasonings.isEmpty) {
      _seasonings.add(_SeasoningEntry(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
      ),);
    }
    if (_ingredients.isEmpty) {
      _ingredients.add(_SeasoningEntry(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
      ),);
    }
    if (_directionControllers.isEmpty) {
      _directionControllers.add(TextEditingController());
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _itemController.dispose();
    _categoryController.dispose();
    _temperatureController.dispose();
    _timeController.dispose();
    _woodController.dispose();
    _notesController.dispose();
    _servesController.dispose();
    for (final entry in _seasonings) {
      entry.dispose();
    }
    for (final entry in _ingredients) {
      entry.dispose();
    }
    for (final controller in _directionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.recipeId != null;
    final isImporting = widget.importedRecipe != null;
    
    final title = isEditing 
        ? 'Edit Recipe' 
        : isImporting 
            ? 'Review Imported Recipe'
            : 'New Smoking Recipe';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton.icon(
            onPressed: _saveRecipe,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Recipe Photo (always first)
            _buildImagePicker(theme),

            const SizedBox(height: 16),

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g., Competition Brisket, Smoked Salmon',
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Name is required' : null,
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            // Type selector (Pit Note vs Recipe) - styled like Modernist
            Text(
              'Type *',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTypeChip('Pit Note', SmokingType.pitNote, theme),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeChip('Recipe', SmokingType.recipe, theme),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Course dropdown
            DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: const InputDecoration(
                labelText: 'Course',
              ),
              items: Course.defaults
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.slug,
                      child: Text(c.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null && value != _selectedCourse) {
                  _handleCourseChange(value);
                }
              },
            ),

            const SizedBox(height: 16),

            // Item and Category row (only for Pit Notes)
            if (_selectedType == SmokingType.pitNote) ...[
              Row(
                children: [
                  // Item being smoked (with autocomplete)
                  Expanded(
                    flex: 2,
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: _itemController.text),
                    optionsBuilder: (textEditingValue) {
                      return SmokingCategory.getSuggestions(textEditingValue.text);
                    },
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      controller.addListener(() {
                        _itemController.text = controller.text;
                        // Auto-detect category based on item
                        final detectedCategory = SmokingCategory.getCategoryForItem(controller.text);
                        if (detectedCategory != null && _categoryController.text.isEmpty) {
                          setState(() => _categoryController.text = detectedCategory);
                        }
                      });
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Item *',
                          hintText: 'e.g., Brisket',
                        ),
                        validator: (v) => v?.isEmpty ?? true ? 'Item is required' : null,
                        textCapitalization: TextCapitalization.words,
                      );
                    },
                    onSelected: (selection) {
                      _itemController.text = selection;
                      // Auto-detect category
                      final detectedCategory = SmokingCategory.getCategoryForItem(selection);
                      if (detectedCategory != null) {
                        setState(() => _categoryController.text = detectedCategory);
                      }
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: 200,
                              maxWidth: MediaQuery.of(context).size.width - 32,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Category with autocomplete (free-form entry)
                Expanded(
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: _categoryController.text),
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return SmokingCategory.all;
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return SmokingCategory.all.where(
                        (c) => c.toLowerCase().contains(query),
                      );
                    },
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      controller.addListener(() {
                        _categoryController.text = controller.text;
                      });
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        textCapitalization: TextCapitalization.words,
                      );
                    },
                    onSelected: (selection) {
                      _categoryController.text = selection;
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 200,
                              maxWidth: 200,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  dense: true,
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            ],

            // Pit Note specific fields
            if (_selectedType == SmokingType.pitNote) ...[
              const SizedBox(height: 16),

              // Temperature and Time row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _temperatureController,
                      decoration: const InputDecoration(
                        labelText: 'Temperature *',
                        hintText: 'e.g., 275°F',
                      ),
                      validator: (v) =>
                          _selectedType == SmokingType.pitNote && (v?.isEmpty ?? true)
                              ? 'Temperature is required'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _timeController,
                      decoration: const InputDecoration(
                        labelText: 'Time *',
                        hintText: 'e.g., 8-12 hrs',
                      ),
                      validator: (v) =>
                          _selectedType == SmokingType.pitNote && (v?.isEmpty ?? true)
                              ? 'Time is required'
                              : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Wood type with autocomplete suggestions
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _woodController.text),
              optionsBuilder: (textEditingValue) {
                return WoodSuggestions.getSuggestions(textEditingValue.text);
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                // Sync with our controller
                controller.addListener(() {
                  _woodController.text = controller.text;
                });
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Wood Type (optional)',
                    hintText: 'e.g., Hickory, Cherry, Apple',
                  ),
                  textCapitalization: TextCapitalization.words,
                );
              },
              onSelected: (selection) {
                _woodController.text = selection;
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 200,
                        maxWidth: MediaQuery.of(context).size.width - 32,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            dense: true,
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

              // Seasonings section (Pit Notes)
              _buildSectionTitle(theme, 'Seasonings'),
              const SizedBox(height: 8),
              ..._buildSeasoningFields(),
            ],

            // Recipe specific fields
            if (_selectedType == SmokingType.recipe) ...[
              const SizedBox(height: 16),

              // Category with autocomplete (free-form entry)
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _categoryController.text),
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return SmokingCategory.all;
                  }
                  final query = textEditingValue.text.toLowerCase();
                  return SmokingCategory.all.where(
                    (c) => c.toLowerCase().contains(query),
                  );
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  controller.addListener(() {
                    _categoryController.text = controller.text;
                  });
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      hintText: 'What is being smoked?',
                    ),
                    textCapitalization: TextCapitalization.words,
                  );
                },
                onSelected: (selection) {
                  _categoryController.text = selection;
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 200,
                          maxWidth: MediaQuery.of(context).size.width - 32,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              title: Text(option),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Wood type (optional, for reference)
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _woodController.text),
                optionsBuilder: (textEditingValue) {
                  return WoodSuggestions.getSuggestions(textEditingValue.text);
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  controller.addListener(() {
                    _woodController.text = controller.text;
                  });
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Wood Type (optional)',
                      hintText: 'e.g., Hickory, Cherry, Apple',
                    ),
                    textCapitalization: TextCapitalization.words,
                  );
                },
                onSelected: (selection) {
                  _woodController.text = selection;
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: 200,
                          maxWidth: MediaQuery.of(context).size.width - 32,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options.elementAt(index);
                            return ListTile(
                              dense: true,
                              title: Text(option),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Serves and Time row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _servesController,
                      decoration: const InputDecoration(
                        labelText: 'Serves',
                        hintText: 'e.g., 8-10',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _timeController,
                      decoration: const InputDecoration(
                        labelText: 'Time',
                        hintText: 'e.g., 12 hours',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Ingredients section (Recipes) - matches standard recipe layout
              _buildIngredientsSection(theme),
            ],

            // Pairs With section
            const SizedBox(height: 24),
            _buildPairsWithSection(theme),

            const SizedBox(height: 24),

            // Directions section (both types)
            Text(
              'Directions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _directionControllers.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final controller = _directionControllers.removeAt(oldIndex);
                  _directionControllers.insert(newIndex, controller);
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
                return _buildDirectionRowWidget(index, theme, key: ValueKey(_directionControllers[index]));
              },
            ),

            const SizedBox(height: 24),

            // Step Images section
            _buildStepImagesSection(theme),

            const SizedBox(height: 24),

            // Notes field
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Additional tips or variations...',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, SmokingType type, ThemeData theme) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.secondary.withOpacity(0.15)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.secondary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  List<Widget> _buildSeasoningFields() {
    final theme = Theme.of(context);
    
    return _seasonings.asMap().entries.map((entry) {
      final index = entry.key;
      final seasoning = entry.value;
      final isLast = index == _seasonings.length - 1;

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
            // Ingredient/Seasoning name with autocomplete
            Expanded(
              flex: 3,
              child: Autocomplete<String>(
                initialValue: TextEditingValue(text: seasoning.nameController.text),
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return Suggestions.seasonings;
                  }
                  return Suggestions.filter(
                    Suggestions.seasonings, 
                    textEditingValue.text,
                  );
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  controller.addListener(() {
                    seasoning.nameController.text = controller.text;
                    // Auto-add new row when typing in last row
                    if (isLast && controller.text.isNotEmpty && _seasonings.length == index + 1) {
                      _addSeasoning();
                      setState(() {});
                    }
                  });
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
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
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => onFieldSubmitted(),
                  );
                },
                onSelected: (selection) {
                  seasoning.nameController.text = selection;
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 200,
                          maxWidth: 180,
                        ),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (context, idx) {
                            final option = options.elementAt(idx);
                            return ListTile(
                              dense: true,
                              title: Text(option),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            
            // Amount
            Expanded(
              flex: 2,
              child: TextField(
                controller: seasoning.amountController,
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
            
            // Delete button
            if (_seasonings.length > 1)
              IconButton(
                icon: Icon(
                  Icons.remove_circle_outline, 
                  size: 20,
                  color: theme.colorScheme.secondary,
                ),
                onPressed: () => _removeSeasoning(index),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildDirectionRowWidget(int index, ThemeData theme, {Key? key}) {
    final controller = _directionControllers[index];
    final isLast = index == _directionControllers.length - 1;
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
              controller: controller,
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
                  _addDirection();
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
                onPressed: () => _pickStepImageForDirection(index),
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
                onPressed: _directionControllers.length > 1
                    ? () => _removeDirection(index)
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

  void _addSeasoning() {
    setState(() {
      _seasonings.add(_SeasoningEntry(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
      ),);
    });
  }

  void _removeSeasoning(int index) {
    setState(() {
      _seasonings[index].dispose();
      _seasonings.removeAt(index);
    });
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_SeasoningEntry(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
      ),);
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients[index].dispose();
      _ingredients.removeAt(index);
    });
  }

  Widget _buildIngredientsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
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
                flex: 3,
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
            itemCount: _ingredients.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _ingredients.removeAt(oldIndex);
                _ingredients.insert(newIndex, item);
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
              return _buildIngredientRow(index, theme, key: ValueKey(_ingredients[index]));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRow(int index, ThemeData theme, {Key? key}) {
    final ingredient = _ingredients[index];
    final isLast = index == _ingredients.length - 1;

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
          // Drag handle
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Icon(
                Icons.drag_indicator,
                color: theme.colorScheme.outline,
                size: 20,
              ),
            ),
          ),

          // Ingredient name
          Expanded(
            flex: 3,
            child: TextField(
              controller: ingredient.nameController,
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
              textCapitalization: TextCapitalization.words,
              onChanged: (value) {
                // Auto-add new row when typing in last row
                if (isLast && value.isNotEmpty && _ingredients.length == index + 1) {
                  _addIngredient();
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
              controller: ingredient.amountController,
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

          // Notes/Prep (new column)
          Expanded(
            flex: 2,
            child: TextField(
              controller: ingredient.notesController,
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

          // Delete button
          SizedBox(
            width: 40,
            child: _ingredients.length > 1
                ? IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: theme.colorScheme.outline,
                    ),
                    onPressed: () => _removeIngredient(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  void _addDirection() {
    setState(() {
      _directionControllers.add(TextEditingController());
    });
  }

  void _removeDirection(int index) {
    setState(() {
      _directionControllers[index].dispose();
      _directionControllers.removeAt(index);
      
      // Remove step image mapping for this step and adjust mappings for subsequent steps
      _stepImageMap.remove(index);
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
    });
  }

  Widget _buildStepImagesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Gallery',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            if (_stepImages.isNotEmpty)
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
          'Add photos for cooking steps',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _stepImages.length + 1, // +1 for add button
            itemBuilder: (context, index) {
              // Add button at the end
              if (index == _stepImages.length) {
                return GestureDetector(
                  onTap: _pickStepImage,
                  child: Container(
                    width: 100,
                    height: 100,
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
                          Icons.add_photo_alternate,
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
                );
              }

              // Existing image
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildStepImageWidget(_stepImages[index], width: 100, height: 100),
                    ),
                    // Delete button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: theme.colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => _removeStepImage(index),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 16,
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

  Future<void> _pickStepImage() async {
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
        final imagesDir = Directory('${appDir.path}/smoking_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final fileName = '${const Uuid().v4()}${path.extension(pickedFile.path)}';
        final savedFile = await File(pickedFile.path).copy('${imagesDir.path}/$fileName');

        setState(() {
          _stepImages.add(savedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _removeStepImage(int index) {
    setState(() {
      // Also remove any step mappings to this image
      _stepImageMap.removeWhere((k, v) => v == index);
      // Adjust mappings for images after this one
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
  }

  /// Pick or select an image for a specific direction step
  Future<void> _pickStepImageForDirection(int stepIndex) async {
    // If we have step images, show a picker to choose one or add new
    if (_stepImages.isNotEmpty) {
      await showModalBottomSheet(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select image for step ${stepIndex + 1}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _stepImages.length + 1,
                    itemBuilder: (_, index) {
                      if (index == _stepImages.length) {
                        // Add new image option
                        return GestureDetector(
                          onTap: () async {
                            Navigator.pop(ctx);
                            await _addNewImageForStep(stepIndex);
                          },
                          child: Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outline),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate, 
                                    color: theme.colorScheme.outline),
                                const SizedBox(height: 4),
                                Text('Add new', 
                                    style: TextStyle(
                                      color: theme.colorScheme.outline,
                                      fontSize: 12,
                                    )),
                              ],
                            ),
                          ),
                        );
                      }
                      final isSelected = _stepImageMap[stepIndex] == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _stepImageMap[stepIndex] = index);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected 
                                  ? theme.colorScheme.primary 
                                  : Colors.transparent,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: _buildStepImageWidget(_stepImages[index], 
                                width: 100, height: 100),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // No existing images, add a new one directly
      await _addNewImageForStep(stepIndex);
    }
  }

  /// Add a new image and associate it with a step
  Future<void> _addNewImageForStep(int stepIndex) async {
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
        final imagesDir = Directory('${appDir.path}/smoking_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final fileName = '${const Uuid().v4()}${path.extension(pickedFile.path)}';
        final savedFile = await File(pickedFile.path).copy('${imagesDir.path}/$fileName');

        setState(() {
          _stepImages.add(savedFile.path);
          _stepImageMap[stepIndex] = _stepImages.length - 1;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  /// Handle course change - if changing to a non-Smoking course, offer to switch screens
  void _handleCourseChange(String newCourse) {
    final lowerCourse = newCourse.toLowerCase();
    
    // If staying in Smoking, just update the value
    if (lowerCourse == 'smoking') {
      setState(() => _selectedCourse = newCourse);
      return;
    }
    
    // If switching to Modernist, convert and navigate immediately
    if (lowerCourse == 'modernist') {
      final modernistRecipe = _buildModernistRecipeFromCurrent(newCourse);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ModernistEditScreen(importedRecipe: modernistRecipe),
        ),
      );
      return;
    }
    
    // For all other courses, convert to regular Recipe and navigate immediately
    final recipe = _buildRecipeFromCurrent(newCourse);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RecipeEditScreen(importedRecipe: recipe),
      ),
    );
  }
  
  /// Build a regular Recipe from current Smoking form data
  Recipe _buildRecipeFromCurrent(String course) {
    // Convert seasonings/ingredients to regular Ingredient format
    final ingredients = <Ingredient>[];
    
    // Use seasonings for Pit Notes, ingredients for Recipe type
    final sourceList = _selectedType == SmokingType.pitNote ? _seasonings : _ingredients;
    
    for (final entry in sourceList) {
      if (entry.nameController.text.trim().isEmpty) continue;
      ingredients.add(Ingredient()
        ..name = entry.nameController.text.trim()
        ..amount = entry.amountController.text.trim().isEmpty 
            ? null 
            : entry.amountController.text.trim());
    }
    
    // Build directions
    final directions = _directionControllers
        .map((c) => c.text.trim())
        .where((d) => d.isNotEmpty)
        .toList();
    
    // Include smoking-specific info in notes
    var notes = _notesController.text.trim();
    final smokingInfo = <String>[];
    if (_woodController.text.trim().isNotEmpty) {
      smokingInfo.add('Wood: ${_woodController.text.trim()}');
    }
    if (_temperatureController.text.trim().isNotEmpty) {
      smokingInfo.add('Temperature: ${_temperatureController.text.trim()}');
    }
    if (_itemController.text.trim().isNotEmpty) {
      smokingInfo.add('Item: ${_itemController.text.trim()}');
    }
    if (smokingInfo.isNotEmpty) {
      final smokingNotes = '**Smoking Info**\n${smokingInfo.join('\n')}';
      notes = notes.isEmpty ? smokingNotes : '$smokingNotes\n\n$notes';
    }
    
    return Recipe()
      ..uuid = _existingRecipe?.uuid ?? const Uuid().v4()
      ..name = _nameController.text.trim()
      ..course = course
      ..serves = _servesController.text.trim().isEmpty ? null : _servesController.text.trim()
      ..time = _timeController.text.trim().isEmpty ? null : _timeController.text.trim()
      ..ingredients = ingredients
      ..directions = directions
      ..notes = notes.isEmpty ? null : notes
      ..headerImage = _imagePath
      ..stepImages = _stepImages
      ..stepImageMap = _stepImageMap.entries.map((e) => '${e.key}:${e.value}').toList()
      ..pairedRecipeIds = _pairedRecipeIds
      ..source = RecipeSource.personal
      ..createdAt = _existingRecipe?.createdAt ?? DateTime.now()
      ..updatedAt = DateTime.now();
  }
  
  /// Build a ModernistRecipe from current Smoking form data
  ModernistRecipe _buildModernistRecipeFromCurrent(String course) {
    // Convert seasonings/ingredients to ModernistIngredient format
    final ingredients = <ModernistIngredient>[];
    
    final sourceList = _selectedType == SmokingType.pitNote ? _seasonings : _ingredients;
    
    for (final entry in sourceList) {
      if (entry.nameController.text.trim().isEmpty) continue;
      ingredients.add(ModernistIngredient.create(
        name: entry.nameController.text.trim(),
        amount: entry.amountController.text.trim().isEmpty 
            ? null 
            : entry.amountController.text.trim(),
      ));
    }
    
    // Build directions
    final directions = _directionControllers
        .map((c) => c.text.trim())
        .where((d) => d.isNotEmpty)
        .toList();
    
    return ModernistRecipe.create(
      uuid: _existingRecipe?.uuid ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      course: course,
      serves: _servesController.text.trim().isEmpty ? null : _servesController.text.trim(),
      time: _timeController.text.trim().isEmpty ? null : _timeController.text.trim(),
      ingredients: ingredients,
      directions: directions,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      headerImage: _imagePath,
      stepImages: _stepImages,
      stepImageMap: _stepImageMap.entries.map((e) => '${e.key}:${e.value}').toList(),
      pairedRecipeIds: _pairedRecipeIds,
      source: ModernistSource.personal,
    );
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    // Build seasonings list (for Pit Notes)
    final seasonings = _seasonings
        .where((s) => s.nameController.text.trim().isNotEmpty)
        .map((s) => SmokingSeasoning()
          ..name = s.nameController.text.trim()
          ..amount = s.amountController.text.trim().isEmpty
              ? null
              : s.amountController.text.trim(),)
        .toList();

    // Build ingredients list (for Recipes)
    final ingredients = _ingredients
        .where((i) => i.nameController.text.trim().isNotEmpty)
        .map((i) => SmokingSeasoning()
          ..name = i.nameController.text.trim()
          ..amount = i.amountController.text.trim().isEmpty
              ? null
              : i.amountController.text.trim(),)
        .toList();

    // Build directions list
    final directions = _directionControllers
        .map((c) => c.text.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    final recipe = SmokingRecipe()
      ..uuid = _existingRecipe?.uuid ?? const Uuid().v4()
      ..name = _nameController.text.trim()
      ..type = _selectedType
      ..course = _selectedCourse
      ..item = _itemController.text.trim().isEmpty
          ? null
          : _itemController.text.trim()
      ..category = _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim()
      ..temperature = _temperatureController.text.trim()
      ..time = _timeController.text.trim()
      ..wood = _woodController.text.trim()
      ..seasonings = seasonings
      ..ingredients = ingredients
      ..serves = _servesController.text.trim().isEmpty
          ? null
          : _servesController.text.trim()
      ..directions = directions
      ..notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim()
      ..headerImage = _imagePath
      ..stepImages = _stepImages
      ..stepImageMap = _stepImageMap.entries
          .map((e) => '${e.key}:${e.value}')
          .toList()
      ..pairedRecipeIds = _pairedRecipeIds
      ..source = _existingRecipe?.source ?? SmokingSource.personal
      ..createdAt = _existingRecipe?.createdAt ?? DateTime.now()
      ..updatedAt = DateTime.now();

    await ref.read(smokingRepositoryProvider).saveRecipe(recipe);

    if (mounted) {
      Navigator.pop(context);
    }
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
    
    // Filter out: already paired, and recipes from excluded courses
    final availableRecipes = allRecipes.where((r) {
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
                                Course.displayNameFromSlug(recipe.course),
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
}

/// Helper class to manage seasoning input fields
class _SeasoningEntry {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController notesController;

  _SeasoningEntry({
    required this.nameController,
    required this.amountController,
    TextEditingController? notesController,
  }) : notesController = notesController ?? TextEditingController();

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    notesController.dispose();
  }
}

// ============ IMAGE PICKER EXTENSION ============

extension _ImagePickerExtension on _SmokingEditScreenState {
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
        final imagesDir = Directory('${appDir.path}/smoking_images');
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
      debugPrint('Error picking image: $e');
    }
  }

  void _removeImage() {
    setState(() {
      _imagePath = null;
    });
  }
}
