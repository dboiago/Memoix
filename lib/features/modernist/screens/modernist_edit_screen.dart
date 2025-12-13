import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../app/theme/colors.dart';
import '../models/modernist_recipe.dart';
import '../repository/modernist_repository.dart';

/// Edit screen for creating/editing modernist recipes
class ModernistEditScreen extends ConsumerStatefulWidget {
  final int? recipeId;

  const ModernistEditScreen({super.key, this.recipeId});

  @override
  ConsumerState<ModernistEditScreen> createState() => _ModernistEditScreenState();
}

class _ModernistEditScreenState extends ConsumerState<ModernistEditScreen> {
  static const _uuid = Uuid();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _techniqueController = TextEditingController();
  final _servesController = TextEditingController();
  final _timeController = TextEditingController();
  final _difficultyController = TextEditingController();
  final _notesController = TextEditingController();
  final _scienceNotesController = TextEditingController();
  final _sourceUrlController = TextEditingController();

  ModernistType _selectedType = ModernistType.concept;
  final List<String> _equipment = [];
  final List<_IngredientRow> _ingredientRows = [];
  final _directionsController = TextEditingController();
  List<String> _imagePaths = [];

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
    if (widget.recipeId != null) {
      final repo = ref.read(modernistRepositoryProvider);
      final recipe = await repo.getById(widget.recipeId!);
      if (recipe != null) {
        _existingRecipe = recipe;
        _nameController.text = recipe.name;
        _selectedType = recipe.type;
        _techniqueController.text = recipe.technique ?? '';
        _servesController.text = recipe.serves ?? '';
        _timeController.text = recipe.time ?? '';
        _difficultyController.text = recipe.difficulty ?? '';
        _notesController.text = recipe.notes ?? '';
        _scienceNotesController.text = recipe.scienceNotes ?? '';
        _sourceUrlController.text = recipe.sourceUrl ?? '';
        _equipment.addAll(recipe.equipment);
        _imagePaths = recipe.getAllImages();

        for (final ingredient in recipe.ingredients) {
          _ingredientRows.add(_IngredientRow(
            nameController: TextEditingController(text: ingredient.name),
            amountController: TextEditingController(text: ingredient.amount ?? ''),
            unitController: TextEditingController(text: ingredient.unit ?? ''),
            notesController: TextEditingController(text: ingredient.notes ?? ''),
          ));
        }

        _directionsController.text = recipe.directions.join('\n\n');
      }
    }

    // Ensure at least one ingredient row
    if (_ingredientRows.isEmpty) {
      _ingredientRows.add(_IngredientRow(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
        unitController: TextEditingController(),
        notesController: TextEditingController(),
      ));
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _techniqueController.dispose();
    _servesController.dispose();
    _timeController.dispose();
    _difficultyController.dispose();
    _notesController.dispose();
    _scienceNotesController.dispose();
    _sourceUrlController.dispose();
    _directionsController.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Recipe' : 'New Modernist Recipe'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveRecipe,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Recipe Name *',
                hintText: 'e.g., Mustard Air, Spherified Mango',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) =>
                  value?.isEmpty == true ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            // Type selection
            Text('Recipe Type', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ModernistType>(
              segments: const [
                ButtonSegment(
                  value: ModernistType.concept,
                  label: Text('Concept'),
                  icon: Icon(Icons.lightbulb_outline),
                ),
                ButtonSegment(
                  value: ModernistType.technique,
                  label: Text('Technique'),
                  icon: Icon(Icons.science_outlined),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (selection) {
                setState(() => _selectedType = selection.first);
              },
            ),
            const SizedBox(height: 16),

            // Technique category
            Autocomplete<String>(
              optionsBuilder: (value) =>
                  ModernistTechniques.getSuggestions(value.text),
              initialValue: TextEditingValue(text: _techniqueController.text),
              onSelected: (value) => _techniqueController.text = value,
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                // Sync with our controller
                controller.text = _techniqueController.text;
                controller.addListener(() => _techniqueController.text = controller.text);
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Technique Category',
                    hintText: 'e.g., Spherification, Foams, Sous Vide',
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Metadata row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servesController,
                    decoration: const InputDecoration(
                      labelText: 'Serves',
                      hintText: '4',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _timeController,
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      hintText: '30 min',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _difficultyController,
                    decoration: const InputDecoration(
                      labelText: 'Difficulty',
                      hintText: 'Advanced',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Equipment section
            _buildEquipmentSection(theme),
            const SizedBox(height: 24),

            // Ingredients section
            _buildIngredientsSection(theme),
            const SizedBox(height: 24),

            // Directions section
            Text('Directions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _directionsController,
              decoration: const InputDecoration(
                hintText: 'Enter each step on a new line...',
                border: OutlineInputBorder(),
              ),
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Science notes
            Text('Science Notes (optional)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              controller: _scienceNotesController,
              decoration: const InputDecoration(
                hintText: 'Explain the science behind this technique...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Tips, variations, etc.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Source URL
            TextFormField(
              controller: _sourceUrlController,
              decoration: const InputDecoration(
                labelText: 'Source URL',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

            // Image picker
            _buildImagePicker(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.build_outlined, size: 20, color: MemoixColors.molecular),
            const SizedBox(width: 8),
            Text('Special Equipment', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Equipment needed before starting (shown above ingredients)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),

        // Equipment chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._equipment.map((item) => Chip(
              label: Text(item),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () => setState(() => _equipment.remove(item)),
              backgroundColor: MemoixColors.molecular.withOpacity(0.1),
            )),
          ],
        ),
        const SizedBox(height: 12),

        // Add equipment autocomplete
        Autocomplete<String>(
          optionsBuilder: (value) {
            final suggestions = ModernistEquipment.getSuggestions(value.text);
            // Exclude already added items
            return suggestions.where((s) => !_equipment.contains(s));
          },
          onSelected: (value) {
            setState(() {
              if (!_equipment.contains(value)) {
                _equipment.add(value);
              }
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Add equipment...',
                prefixIcon: const Icon(Icons.add),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      ],
    );
  }

  Widget _buildIngredientsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ingredients', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),

        // Ingredient rows
        ...List.generate(_ingredientRows.length, (index) {
          final row = _ingredientRows[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: row.amountController,
                    decoration: const InputDecoration(
                      hintText: 'Amt',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Unit
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: row.unitController,
                    decoration: const InputDecoration(
                      hintText: 'Unit',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Name with autocomplete
                Expanded(
                  flex: 2,
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
                        decoration: const InputDecoration(
                          hintText: 'Ingredient',
                          isDense: true,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Notes
                Expanded(
                  child: TextField(
                    controller: row.notesController,
                    decoration: const InputDecoration(
                      hintText: 'Notes',
                      isDense: true,
                    ),
                  ),
                ),
                // Remove button
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: _ingredientRows.length > 1
                      ? () => setState(() {
                          _ingredientRows.removeAt(index);
                        })
                      : null,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          );
        }),

        // Add ingredient button
        TextButton.icon(
          onPressed: () => setState(() {
            _ingredientRows.add(_IngredientRow(
              nameController: TextEditingController(),
              amountController: TextEditingController(),
              unitController: TextEditingController(),
              notesController: TextEditingController(),
            ));
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add Ingredient'),
        ),
      ],
    );
  }

  Widget _buildImagePicker(ThemeData theme) {
    final hasImages = _imagePaths.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (hasImages)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imagePaths.length + 1,
              itemBuilder: (context, index) {
                if (index == _imagePaths.length) {
                  return GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.add),
                    ),
                  );
                }

                return Stack(
                  children: [
                    Container(
                      width: 80,
                      margin: EdgeInsets.only(left: index == 0 ? 0 : 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _imagePaths[index].startsWith('http')
                            ? Image.network(_imagePaths[index], fit: BoxFit.cover)
                            : Image.file(File(_imagePaths[index]), fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _imagePaths.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        else
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        size: 40, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text('Add photos',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _pickImage() async {
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
        final imagesDir = Directory('${appDir.path}/modernist_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        final fileName = '${_uuid.v4()}${path.extension(pickedFile.path)}';
        final savedFile = await File(pickedFile.path).copy('${imagesDir.path}/$fileName');

        setState(() {
          _imagePaths.add(savedFile.path);
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

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Build ingredients
      final ingredients = _ingredientRows
          .where((row) => row.nameController.text.isNotEmpty)
          .map((row) => ModernistIngredient.create(
                name: row.nameController.text.trim(),
                amount: row.amountController.text.trim().isEmpty
                    ? null
                    : row.amountController.text.trim(),
                unit: row.unitController.text.trim().isEmpty
                    ? null
                    : row.unitController.text.trim(),
                notes: row.notesController.text.trim().isEmpty
                    ? null
                    : row.notesController.text.trim(),
              ))
          .toList();

      // Build directions
      final directions = _directionsController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final repo = ref.read(modernistRepositoryProvider);

      if (_existingRecipe != null) {
        // Update existing
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
          ..difficulty = _difficultyController.text.trim().isEmpty
              ? null
              : _difficultyController.text.trim()
          ..equipment = _equipment
          ..ingredients = ingredients
          ..directions = directions
          ..notes = _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim()
          ..scienceNotes = _scienceNotesController.text.trim().isEmpty
              ? null
              : _scienceNotesController.text.trim()
          ..sourceUrl = _sourceUrlController.text.trim().isEmpty
              ? null
              : _sourceUrlController.text.trim()
          ..imageUrls = _imagePaths
          ..imageUrl = _imagePaths.isNotEmpty ? _imagePaths.first : null
          ..updatedAt = DateTime.now();

        await repo.save(_existingRecipe!);
      } else {
        // Create new
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
          difficulty: _difficultyController.text.trim().isEmpty
              ? null
              : _difficultyController.text.trim(),
          equipment: _equipment,
          ingredients: ingredients,
          directions: directions,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          scienceNotes: _scienceNotesController.text.trim().isEmpty
              ? null
              : _scienceNotesController.text.trim(),
          sourceUrl: _sourceUrlController.text.trim().isEmpty
              ? null
              : _sourceUrlController.text.trim(),
          imageUrls: _imagePaths,
          imageUrl: _imagePaths.isNotEmpty ? _imagePaths.first : null,
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
  final TextEditingController unitController;
  final TextEditingController notesController;

  _IngredientRow({
    required this.nameController,
    required this.amountController,
    required this.unitController,
    required this.notesController,
  });

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    unitController.dispose();
    notesController.dispose();
  }
}
