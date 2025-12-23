import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../models/modernist_recipe.dart';
import '../repository/modernist_repository.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../recipes/models/course.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
import '../../smoking/models/smoking_recipe.dart';
import '../../smoking/screens/smoking_edit_screen.dart';

/// Edit screen for creating/editing modernist recipes - follows Mains pattern
class ModernistEditScreen extends ConsumerStatefulWidget {
  final int? recipeId;
  /// Pre-populated recipe for imports (not yet saved)
  final ModernistRecipe? importedRecipe;

  const ModernistEditScreen({super.key, this.recipeId, this.importedRecipe});

  @override
  ConsumerState<ModernistEditScreen> createState() => _ModernistEditScreenState();
}

class _ModernistEditScreenState extends ConsumerState<ModernistEditScreen> {
  static const _uuid = Uuid();

  final _nameController = TextEditingController();
  final _techniqueController = TextEditingController();
  final _servesController = TextEditingController();
  final _timeController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCourse = 'modernist';
  ModernistType _selectedType = ModernistType.concept;
  final List<String> _equipment = [];
  TextEditingController? _equipmentFieldController;
  final List<_IngredientRow> _ingredientRows = [];
  final List<_DirectionRow> _directionRows = [];
  
  // Image handling - separate header and step images
  String? _headerImage;
  final List<String> _stepImages = [];
  final Map<int, int> _stepImageMap = {}; // stepIndex -> imageIndex in _stepImages

  /// Paired recipe IDs (for linking related recipes)
  final List<String> _pairedRecipeIds = [];

  bool _isLoading = true;
  bool _isSaving = false;
  ModernistRecipe? _existingRecipe;

  bool get _isEditing => _existingRecipe != null;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    ModernistRecipe? recipe;
    
    if (widget.recipeId != null) {
      final repo = ref.read(modernistRepositoryProvider);
      recipe = await repo.getById(widget.recipeId!);
      if (recipe != null) {
        _existingRecipe = recipe;
      }
    } else if (widget.importedRecipe != null) {
      recipe = widget.importedRecipe;
      // importedRecipe is not saved yet, so don't set _existingRecipe
    }
    
    if (recipe != null) {
      _nameController.text = recipe.name;
      _selectedCourse = recipe.course;
      _selectedType = recipe.type;
      _techniqueController.text = recipe.technique ?? '';
      _servesController.text = recipe.serves ?? '';
      _timeController.text = recipe.time ?? '';
      // Combine notes and science notes into single notes field
      final notesParts = <String>[
        if (recipe.notes != null && recipe.notes!.isNotEmpty) recipe.notes!,
        if (recipe.scienceNotes != null && recipe.scienceNotes!.isNotEmpty) recipe.scienceNotes!,
      ];
      _notesController.text = notesParts.join('\n\n');
      _equipment.addAll(recipe.equipment);
      
      // Load images - new structure
      // Filter stepImages to exclude headerImage to prevent duplicates
      _headerImage = recipe.getFirstImage();
      final headerImg = _headerImage;
      _stepImages.addAll(
        recipe.stepImages.where((img) => headerImg == null || img != headerImg),
      );
      
      // Parse step image map
      for (final mapping in recipe.stepImageMap) {
        final parts = mapping.split(':');
        if (parts.length == 2) {
          final stepIdx = int.tryParse(parts[0]);
          final imgIdx = int.tryParse(parts[1]);
          if (stepIdx != null && imgIdx != null) {
            _stepImageMap[stepIdx] = imgIdx;
          }
        }
      }

      // Track sections to insert section headers
      String? lastSection;
      for (final ingredient in recipe.ingredients) {
        // If this ingredient has a different section, add a section header
        if (ingredient.section != null && ingredient.section != lastSection) {
          _addIngredientRow(name: ingredient.section!, isSection: true);
          lastSection = ingredient.section;
        }
        // Combine amount and unit for display
        final amountParts = <String>[
          if (ingredient.amount != null && ingredient.amount!.isNotEmpty) ingredient.amount!,
          if (ingredient.unit != null && ingredient.unit!.isNotEmpty) ingredient.unit!,
        ];
        _addIngredientRow(
          name: ingredient.name,
          amount: amountParts.join(' '),
          notes: ingredient.notes ?? '',
        );
      }

      // Load directions as individual rows
      for (final direction in recipe.directions) {
        _addDirectionRow(text: direction);
      }
      
      // Load paired recipe IDs
      _pairedRecipeIds.addAll(recipe.pairedRecipeIds);
    }

    // Always have at least one empty row
    if (_ingredientRows.isEmpty) {
      _addIngredientRow();
    }
    if (_directionRows.isEmpty) {
      _addDirectionRow();
    }

    setState(() => _isLoading = false);
  }

  void _addIngredientRow({String name = '', String amount = '', String notes = '', bool isSection = false}) {
    _ingredientRows.add(_IngredientRow(
      nameController: TextEditingController(text: name),
      amountController: TextEditingController(text: amount),
      notesController: TextEditingController(text: notes),
      isSection: isSection,
    ),);
  }

  void _addSectionHeader() {
    _ingredientRows.add(_IngredientRow(
      nameController: TextEditingController(),
      amountController: TextEditingController(),
      notesController: TextEditingController(),
      isSection: true,
    ),);
    setState(() {});
  }

  void _addDirectionRow({String text = ''}) {
    _directionRows.add(_DirectionRow(
      controller: TextEditingController(text: text),
    ),);
  }

  void _removeIngredientRow(int index) {
    if (_ingredientRows.length > 1) {
      final row = _ingredientRows.removeAt(index);
      row.dispose();
      setState(() {});
    }
  }

  void _removeDirectionRow(int index) {
    if (_directionRows.length > 1) {
      // Update step image map when removing a direction
      _stepImageMap.remove(index);
      // Shift indices for rows after the removed one
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
    _techniqueController.dispose();
    _servesController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    for (final row in _directionRows) {
      row.dispose();
    }
    super.dispose();
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
            // Image gallery (matches Mains pattern)
            _buildImagePicker(theme),
            const SizedBox(height: 16),

            // Recipe name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Recipe Name *',
                hintText: 'e.g., Mustard Air, Spherified Mango',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // Category (Concept/Technique) - styled like cuisine chips
            Text(
              'Category *',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildCategoryChip(
                      'Concept', ModernistType.concept, theme),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCategoryChip(
                      'Technique', ModernistType.technique, theme),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Technique category (like Region in Mains)
            Autocomplete<String>(
              optionsBuilder: (value) =>
                  ModernistTechniques.getSuggestions(value.text),
              initialValue: TextEditingValue(text: _techniqueController.text),
              onSelected: (value) => _techniqueController.text = value,
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                // Sync with our controller (check if different to avoid losing first letter)
                if (controller.text != _techniqueController.text) {
                  controller.text = _techniqueController.text;
                  controller.selection = TextSelection.collapsed(
                    offset: controller.text.length,
                  );
                }
                controller.addListener(() {
                  if (_techniqueController.text != controller.text) {
                    _techniqueController.text = controller.text;
                  }
                });
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Technique (optional)',
                    hintText: 'e.g., Spherification, Foams, Sous Vide',
                  ),
                  textCapitalization: TextCapitalization.words,
                );
              },
            ),
            const SizedBox(height: 16),

            // Course dropdown
            DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: const InputDecoration(
                labelText: 'Course',
              ),
              items: Course.defaults
                  .map((c) => DropdownMenuItem(
                        value: c.slug,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null && value != _selectedCourse) {
                  _handleCourseChange(value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Serves and Time row (like Mains)
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

            // Equipment section
            _buildEquipmentSection(theme),
            const SizedBox(height: 24),

            // Pairs With section
            _buildPairsWithSection(theme),
            const SizedBox(height: 24),

            // Ingredients section (spreadsheet layout like Mains)
            _buildIngredientsSection(theme),
            const SizedBox(height: 24),

            // Directions (individual steps with image picker)
            _buildDirectionsSection(theme),
            const SizedBox(height: 24),

            // Step Images Gallery (always shown with add button)
            _buildStepImagesGallery(theme),
            const SizedBox(height: 24),

            // Comments (single notes field)
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
                hintText: 'Optional tips, science notes, variations, etc.',
              ),
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, ModernistType type, ThemeData theme) {
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

  Widget _buildEquipmentSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Special Equipment',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Equipment needed before starting',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        
        // Dropdown-style equipment selector (like Smoking wood type)
        Autocomplete<String>(
          optionsBuilder: (value) {
            final suggestions = ModernistEquipment.getSuggestions(value.text);
            return suggestions.where((s) => !_equipment.contains(s));
          },
          onSelected: (value) {
            if (!_equipment.contains(value)) {
              setState(() => _equipment.add(value));
              _equipmentFieldController?.clear();
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            _equipmentFieldController = controller;
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Add equipment...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isNotEmpty && !_equipment.contains(value)) {
                      setState(() => _equipment.add(value));
                      controller.clear();
                    }
                  },
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty && !_equipment.contains(value)) {
                  setState(() => _equipment.add(value));
                  controller.clear();
                }
              },
            );
          },
        ),
        
        if (_equipment.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _equipment.map((item) => Chip(
              label: Text(item),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () => setState(() => _equipment.remove(item)),
            ),).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildIngredientsSection(ThemeData theme) {
    return Column(
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
            // Add section header button
            TextButton.icon(
              onPressed: _addSectionHeader,
              icon: const Icon(Icons.title, size: 18),
              label: const Text('Add Section'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
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
                flex: 3,
                child: Text('Ingredient',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text('Amount',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text('Notes/Prep',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),

        // Ingredient rows (reorderable like Mains)
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
              return _buildIngredientRowWidget(index, theme, key: ValueKey(_ingredientRows[index]));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRowWidget(int index, ThemeData theme, {Key? key}) {
    final row = _ingredientRows[index];
    final isLast = index == _ingredientRows.length - 1;

    // Section header row (different styling) - matches Mains pattern
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
            // Section name input
            Expanded(
              child: TextField(
                controller: row.nameController,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  border: const OutlineInputBorder(),
                  hintText: 'Section name (e.g., For the Gel)',
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
            // Delete button
            SizedBox(
              width: 40,
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
                onPressed: _ingredientRows.length > 1
                    ? () => _removeIngredientRow(index)
                    : null,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
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
            flex: 3,
            child: Autocomplete<String>(
              optionsBuilder: (value) =>
                  ModernistIngredients.getSuggestions(value.text),
              initialValue: TextEditingValue(text: row.nameController.text),
              onSelected: (value) => row.nameController.text = value,
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                // Sync with our controller (check if different to avoid losing first letter)
                if (controller.text != row.nameController.text) {
                  controller.text = row.nameController.text;
                  controller.selection = TextSelection.collapsed(
                    offset: controller.text.length,
                  );
                }
                controller.addListener(() {
                  if (row.nameController.text != controller.text) {
                    row.nameController.text = controller.text;
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
                  onChanged: (value) {
                    // Auto-add new row when typing in last row
                    if (isLast && value.isNotEmpty) {
                      _addIngredientRow();
                      setState(() {});
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 8),

          // Amount
          Expanded(
            flex: 2,
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

          // Notes
          Expanded(
            flex: 3,
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

          // Delete button
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: theme.colorScheme.outline,
              ),
              onPressed: _ingredientRows.length > 1
                  ? () => _removeIngredientRow(index)
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }

  // ============ HEADER IMAGE PICKER (Full width at top) ============

  Widget _buildImagePicker(ThemeData theme) {
    final hasImage = _headerImage != null && _headerImage!.isNotEmpty;
    
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
          onTap: _pickHeaderImage,
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
                        child: _buildImageWidget(_headerImage!, width: double.infinity, height: 180),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _imageActionButton(
                              icon: Icons.edit,
                              onTap: _pickHeaderImage,
                              theme: theme,
                            ),
                            const SizedBox(width: 8),
                            _imageActionButton(
                              icon: Icons.delete,
                              onTap: _removeHeaderImage,
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

  void _pickHeaderImage() {
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
                _pickImageForHeader(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageForHeader(ImageSource.gallery);
              },
            ),
            // Show URL option if current image is a URL
            if (_headerImage != null && _headerImage!.startsWith('http'))
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Using URL'),
                subtitle: Text(_headerImage!, overflow: TextOverflow.ellipsis),
                enabled: false,
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

  Future<void> _pickImageForHeader(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final savedPath = await _saveImageToLocal(pickedFile.path);
        setState(() {
          _headerImage = savedPath;
        });
      }
    } catch (e) {
      MemoixSnackBar.showError('Error picking image: $e');
    }
  }

  void _removeHeaderImage() {
    setState(() {
      _headerImage = null;
    });
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
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: size, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }

  // ============ STEP IMAGES (Gallery at bottom) ============

  Future<void> _pickGalleryImage() async {
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
                _pickImageForGallery(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageForGallery(ImageSource.gallery);
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

  Future<void> _pickImageForGallery(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final savedPath = await _saveImageToLocal(pickedFile.path);
        setState(() {
          _stepImages.add(savedPath);
        });
      }
    } catch (e) {
      MemoixSnackBar.showError('Error picking image: $e');
    }
  }

  void _removeStepImage(int index) {
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
      // Remove the image
      _stepImages.removeAt(index);
    });
  }

  Widget _buildDirectionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Directions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add steps and optionally attach images',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        
        // Direction rows
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: _directionRows.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = _directionRows.removeAt(oldIndex);
              _directionRows.insert(newIndex, item);
              
              // Update step image map when reordering
              final oldImageIdx = _stepImageMap.remove(oldIndex);
              final newMap = <int, int>{};
              for (final entry in _stepImageMap.entries) {
                if (entry.key >= newIndex && entry.key < oldIndex) {
                  newMap[entry.key + 1] = entry.value;
                } else if (entry.key > oldIndex && entry.key <= newIndex) {
                  newMap[entry.key - 1] = entry.value;
                } else {
                  newMap[entry.key] = entry.value;
                }
              }
              if (oldImageIdx != null) {
                newMap[newIndex] = oldImageIdx;
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
      ],
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
                  onTap: _pickGalleryImage,
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

              // Find which step(s) use this image
              final stepsUsingImage = _stepImageMap.entries
                  .where((e) => e.value == index)
                  .map((e) => e.key + 1)
                  .toList();

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImageWidget(_stepImages[index], width: 100, height: 100),
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

  Widget _buildImageWidget(String imagePath, {double? width, double? height}) {
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
                  child: _buildImageWidget(_stepImages[index]),
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
        final savedPath = await _saveImageToLocal(pickedFile.path);
        setState(() {
          _stepImages.add(savedPath);
          _stepImageMap[stepIndex] = _stepImages.length - 1;
        });
      }
    } catch (e) {
      MemoixSnackBar.showError('Error picking image: $e');
    }
  }

  Future<String> _saveImageToLocal(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/modernist_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final fileName = '${_uuid.v4()}${path.extension(sourcePath)}';
    final savedFile = await File(sourcePath).copy('${imagesDir.path}/$fileName');
    return savedFile.path;
  }

  /// Handle course change - if changing to a non-Modernist course, offer to switch screens
  void _handleCourseChange(String newCourse) {
    final lowerCourse = newCourse.toLowerCase();
    
    // If staying in Modernist, just update the value
    if (lowerCourse == 'modernist') {
      setState(() => _selectedCourse = newCourse);
      return;
    }
    
    // If switching to Smoking, convert and navigate immediately
    if (lowerCourse == 'smoking') {
      final smokingRecipe = _buildSmokingRecipeFromCurrent(newCourse);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SmokingEditScreen(importedRecipe: smokingRecipe),
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
  
  /// Build a regular Recipe from current Modernist form data
  Recipe _buildRecipeFromCurrent(String course) {
    // Convert Modernist ingredients to regular Ingredient format
    final ingredients = <Ingredient>[];
    String? currentSection;
    
    for (final row in _ingredientRows) {
      if (row.nameController.text.isEmpty) continue;
      
      if (row.isSection) {
        currentSection = row.nameController.text.trim();
      } else {
        // Parse amount and unit from combined amountController
        final amountText = row.amountController.text.trim();
        String? amount;
        String? unit;
        if (amountText.isNotEmpty) {
          final parts = amountText.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            amount = parts.first;
            unit = parts.sublist(1).join(' ');
          } else {
            amount = amountText;
          }
        }
        
        ingredients.add(Ingredient()
          ..name = row.nameController.text.trim()
          ..amount = amount
          ..unit = unit
          ..preparation = row.notesController.text.trim().isEmpty 
              ? null 
              : row.notesController.text.trim()
          ..section = currentSection);
      }
    }
    
    // Build directions from direction rows
    final directions = _directionRows
        .where((row) => row.controller.text.trim().isNotEmpty)
        .map((row) => row.controller.text.trim())
        .toList();
    
    // Use notes directly (Modernist doesn't have separate science notes)
    final notes = _notesController.text.trim();
    
    return Recipe()
      ..uuid = _existingRecipe?.uuid ?? _uuid.v4()
      ..name = _nameController.text.trim()
      ..course = course
      ..serves = _servesController.text.trim().isEmpty ? null : _servesController.text.trim()
      ..time = _timeController.text.trim().isEmpty ? null : _timeController.text.trim()
      ..ingredients = ingredients
      ..directions = directions
      ..notes = notes.isEmpty ? null : notes
      ..headerImage = _headerImage
      ..stepImages = _stepImages
      ..stepImageMap = _stepImageMap.entries.map((e) => '${e.key}:${e.value}').toList()
      ..pairedRecipeIds = _pairedRecipeIds
      ..sourceUrl = _existingRecipe?.sourceUrl
      ..source = RecipeSource.personal
      ..createdAt = _existingRecipe?.createdAt ?? DateTime.now()
      ..updatedAt = DateTime.now();
  }
  
  /// Build a SmokingRecipe from current Modernist form data
  SmokingRecipe _buildSmokingRecipeFromCurrent(String course) {
    // Convert Modernist ingredients to SmokingSeasoning format
    final seasonings = <SmokingSeasoning>[];
    
    for (final row in _ingredientRows) {
      if (row.nameController.text.isEmpty || row.isSection) continue;
      seasonings.add(SmokingSeasoning()
        ..name = row.nameController.text.trim()
        ..amount = row.amountController.text.trim().isEmpty 
            ? null 
            : row.amountController.text.trim());
    }
    
    // Build directions from direction rows
    final directions = _directionRows
        .where((row) => row.controller.text.trim().isNotEmpty)
        .map((row) => row.controller.text.trim())
        .toList();
    
    return SmokingRecipe()
      ..uuid = _existingRecipe?.uuid ?? _uuid.v4()
      ..name = _nameController.text.trim()
      ..course = course
      ..type = SmokingType.recipe
      ..seasonings = seasonings
      ..directions = directions
      ..notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim()
      ..headerImage = _headerImage
      ..stepImages = _stepImages
      ..stepImageMap = _stepImageMap.entries.map((e) => '${e.key}:${e.value}').toList()
      ..pairedRecipeIds = _pairedRecipeIds
      ..source = SmokingSource.personal
      ..createdAt = _existingRecipe?.createdAt ?? DateTime.now()
      ..updatedAt = DateTime.now();
  }

  Future<void> _saveRecipe() async {
    if (_nameController.text.trim().isEmpty) {
      MemoixSnackBar.showError('Please enter a recipe name');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Build ingredients, tracking sections
      final ingredients = <ModernistIngredient>[];
      String? currentSection;
      
      for (final row in _ingredientRows) {
        if (row.nameController.text.isEmpty) continue;
        
        if (row.isSection) {
          // This is a section header - track it for following ingredients
          currentSection = row.nameController.text.trim();
        } else {
          // Regular ingredient - assign current section
          final amountText = row.amountController.text.trim();
          String? amount;
          String? unit;
          if (amountText.isNotEmpty) {
            final parts = amountText.split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              amount = parts.first;
              unit = parts.sublist(1).join(' ');
            } else {
              amount = amountText;
            }
          }
          ingredients.add(ModernistIngredient.create(
            name: row.nameController.text.trim(),
            amount: amount,
            unit: unit,
            notes: row.notesController.text.trim().isEmpty
                ? null
                : row.notesController.text.trim(),
            section: currentSection,
          ));
        }
      }

      // Build directions from individual rows
      final directions = _directionRows
          .where((row) => row.controller.text.trim().isNotEmpty)
          .map((row) => row.controller.text.trim())
          .toList();

      // Build step image map as strings for Isar
      final stepImageMapStrings = _stepImageMap.entries
          .map((e) => '${e.key}:${e.value}')
          .toList();

      final repo = ref.read(modernistRepositoryProvider);

      if (_existingRecipe != null) {
        _existingRecipe!
          ..name = _nameController.text.trim()
          ..course = _selectedCourse
          ..type = _selectedType
          ..technique = _techniqueController.text.trim().isEmpty
              ? null
              : _techniqueController.text.trim()
          ..serves = _servesController.text.trim().isEmpty
              ? null
              : _servesController.text.trim()
          ..time = _timeController.text.trim().isEmpty
              ? null
              : _timeController.text.trim()
          ..equipment = _equipment
          ..ingredients = ingredients
          ..directions = directions
          ..notes = _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim()
          ..headerImage = _headerImage
          ..stepImages = _stepImages
          ..stepImageMap = stepImageMapStrings
          ..pairedRecipeIds = _pairedRecipeIds
          ..updatedAt = DateTime.now();

        await repo.save(_existingRecipe!);
      } else {
        await repo.create(
          name: _nameController.text.trim(),
          course: _selectedCourse,
          type: _selectedType,
          technique: _techniqueController.text.trim().isEmpty
              ? null
              : _techniqueController.text.trim(),
          serves: _servesController.text.trim().isEmpty
              ? null
              : _servesController.text.trim(),
          time: _timeController.text.trim().isEmpty
              ? null
              : _timeController.text.trim(),
          equipment: _equipment,
          ingredients: ingredients,
          directions: directions,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          headerImage: _headerImage,
          stepImages: _stepImages,
          stepImageMap: stepImageMapStrings,
          pairedRecipeIds: _pairedRecipeIds,
        );
      }

      MemoixSnackBar.show('${_nameController.text} saved');
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      MemoixSnackBar.showError('Error saving: $e');
    } finally {
      setState(() => _isSaving = false);
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

/// Helper class for ingredient row controllers
class _IngredientRow {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController notesController;
  bool isSection; // True if this is a section header (e.g., "For the Gel")

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

/// Helper class for direction row controllers
class _DirectionRow {
  final TextEditingController controller;

  _DirectionRow({required this.controller});

  void dispose() {
    controller.dispose();
  }
}
