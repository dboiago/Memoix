import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../models/modernist_recipe.dart';
import '../repository/modernist_repository.dart';

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

  ModernistType _selectedType = ModernistType.concept;
  final List<String> _equipment = [];
  final List<_IngredientRow> _ingredientRows = [];
  final List<_DirectionRow> _directionRows = [];
  
  // Image handling - separate header and step images
  String? _headerImage;
  final List<String> _stepImages = [];
  final Map<int, int> _stepImageMap = {}; // stepIndex -> imageIndex in _stepImages

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
      _headerImage = recipe.getFirstImage();
      _stepImages.addAll(recipe.stepImages);
      
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
                controller.text = _techniqueController.text;
                controller.addListener(() => _techniqueController.text = controller.text);
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

            // Ingredients section (spreadsheet layout like Mains)
            _buildIngredientsSection(theme),
            const SizedBox(height: 24),

            // Directions (individual steps with image picker)
            _buildDirectionsSection(theme),
            const SizedBox(height: 24),

            // Step Images Gallery (shown if any step has images)
            if (_stepImages.isNotEmpty) ...[
              _buildStepImagesGallery(theme),
              const SizedBox(height: 24),
            ],

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
            }
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
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
          SizedBox(
            width: 120,
            child: Autocomplete<String>(
              optionsBuilder: (value) =>
                  ModernistIngredients.getSuggestions(value.text),
              initialValue: TextEditingValue(text: row.nameController.text),
              onSelected: (value) => row.nameController.text = value,
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                controller.text = row.nameController.text;
                controller.addListener(() => row.nameController.text = controller.text);
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

          // Notes
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

  /// Get all images as a unified list (header first, then step images)
  List<String> get _allImages {
    final images = <String>[];
    if (_headerImage != null && _headerImage!.isNotEmpty) {
      images.add(_headerImage!);
    }
    images.addAll(_stepImages);
    return images;
  }

  Widget _buildImagePicker(ThemeData theme) {
    final hasImages = _allImages.isNotEmpty;

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
    final images = _allImages;
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length + 1, // +1 for add button
            itemBuilder: (context, index) {
              if (index == images.length) {
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
                      child: _buildImageWidget(images[index], width: 100, height: 120),
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

  void _removeImage(int index) {
    setState(() {
      if (index == 0 && _headerImage != null && _headerImage!.isNotEmpty) {
        // Removing header image
        _headerImage = null;
        // Shift first step image to header if available
        if (_stepImages.isNotEmpty) {
          _headerImage = _stepImages.removeAt(0);
        }
      } else {
        // Removing a step image (adjust index for header)
        final stepIndex = _headerImage != null && _headerImage!.isNotEmpty ? index - 1 : index;
        if (stepIndex >= 0 && stepIndex < _stepImages.length) {
          _stepImages.removeAt(stepIndex);
        }
      }
    });
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
        final savedPath = await _saveImageToLocal(pickedFile.path);
        setState(() {
          // First image goes to header, rest go to stepImages
          if (_headerImage == null || _headerImage!.isEmpty) {
            _headerImage = savedPath;
          } else {
            _stepImages.add(savedPath);
          }
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

  Future<void> _pickMultipleImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        for (final file in pickedFiles) {
          final savedPath = await _saveImageToLocal(file.path);
          setState(() {
            // First image goes to header, rest go to stepImages
            if (_headerImage == null || _headerImage!.isEmpty) {
              _headerImage = savedPath;
            } else {
              _stepImages.add(savedPath);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
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
              'Step Images',
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
                            child: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurface),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
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

  Future<void> _saveRecipe() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipe name')),
      );
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
          ..updatedAt = DateTime.now();

        await repo.save(_existingRecipe!);
      } else {
        await repo.create(
          name: _nameController.text.trim(),
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
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_nameController.text} saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
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
