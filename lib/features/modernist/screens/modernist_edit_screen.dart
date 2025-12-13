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

  const ModernistEditScreen({super.key, this.recipeId});

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
  final _directionsController = TextEditingController();

  ModernistType _selectedType = ModernistType.concept;
  final List<String> _equipment = [];
  final List<_IngredientRow> _ingredientRows = [];
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
        // Combine notes and science notes into single notes field
        final notesParts = <String>[
          if (recipe.notes != null && recipe.notes!.isNotEmpty) recipe.notes!,
          if (recipe.scienceNotes != null && recipe.scienceNotes!.isNotEmpty) recipe.scienceNotes!,
        ];
        _notesController.text = notesParts.join('\n\n');
        _equipment.addAll(recipe.equipment);
        _imagePaths = recipe.getAllImages();

        for (final ingredient in recipe.ingredients) {
          _addIngredientRow(
            name: ingredient.name,
            amount: ingredient.displayAmount,
            notes: ingredient.notes ?? '',
          );
        }

        _directionsController.text = recipe.directions.join('\n\n');
      }
    }

    // Always have at least one empty row
    if (_ingredientRows.isEmpty) {
      _addIngredientRow();
    }

    setState(() => _isLoading = false);
  }

  void _addIngredientRow({String name = '', String amount = '', String notes = ''}) {
    _ingredientRows.add(_IngredientRow(
      nameController: TextEditingController(text: name),
      amountController: TextEditingController(text: amount),
      notesController: TextEditingController(text: notes),
    ));
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
    _techniqueController.dispose();
    _servesController.dispose();
    _timeController.dispose();
    _notesController.dispose();
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
            // Recipe image (at top like Mains)
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
                _buildCategoryChip('Concept', ModernistType.concept, theme),
                const SizedBox(width: 12),
                _buildCategoryChip('Technique', ModernistType.technique, theme),
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

            // Directions
            Text(
              'Directions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Separate steps with blank lines.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _directionsController,
              decoration: const InputDecoration(
                hintText: 'Prepare the base solution...\n\nDrop into the bath...\n\n...',
                alignLabelWithHint: true,
              ),
              maxLines: 15,
              minLines: 8,
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
    );
  }

  Widget _buildEquipmentSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Special Equipment',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                _showAddEquipmentDialog();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Equipment needed before starting',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
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
            )).toList(),
          ),
        ],
      ],
    );
  }

  void _showAddEquipmentDialog() {
    final controller = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Equipment',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              optionsBuilder: (value) {
                final suggestions = ModernistEquipment.getSuggestions(value.text);
                return suggestions.where((s) => !_equipment.contains(s));
              },
              onSelected: (value) {
                controller.text = value;
              },
              fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
                controller.addListener(() => textController.text = controller.text);
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Immersion circulator, iSi whipper',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    final value = textController.text.trim();
                    if (value.isNotEmpty && !_equipment.contains(value)) {
                      setState(() => _equipment.add(value));
                    }
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isNotEmpty && !_equipment.contains(value)) {
                      setState(() => _equipment.add(value));
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
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

        // Ingredient rows
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
          ),
          child: Column(
            children: List.generate(_ingredientRows.length, (index) {
              return _buildIngredientRowWidget(index, theme);
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientRowWidget(int index, ThemeData theme) {
    final row = _ingredientRows[index];
    final isLast = index == _ingredientRows.length - 1;

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

  Widget _buildImagePicker(ThemeData theme) {
    final hasImages = _imagePaths.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recipe Photos',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasImages) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_imagePaths.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
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
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _imagePaths.length + 1,
        itemBuilder: (context, index) {
          if (index == _imagePaths.length) {
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
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: theme.colorScheme.surface.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () => setState(() => _imagePaths.removeAt(index)),
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

  Future<void> _pickMultipleImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${appDir.path}/modernist_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }

        for (final pickedFile in pickedFiles) {
          final fileName = '${_uuid.v4()}${path.extension(pickedFile.path)}';
          final savedFile = await File(pickedFile.path).copy('${imagesDir.path}/$fileName');
          _imagePaths.add(savedFile.path);
        }

        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
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
      // Build ingredients
      final ingredients = _ingredientRows
          .where((row) => row.nameController.text.isNotEmpty)
          .map((row) {
            // Parse amount for amount and unit
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
            return ModernistIngredient.create(
              name: row.nameController.text.trim(),
              amount: amount,
              unit: unit,
              notes: row.notesController.text.trim().isEmpty
                  ? null
                  : row.notesController.text.trim(),
            );
          })
          .toList();

      // Build directions
      final directions = _directionsController.text
          .split(RegExp(r'\n\s*\n'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
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
          ..imageUrls = _imagePaths
          ..imageUrl = _imagePaths.isNotEmpty ? _imagePaths.first : null
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
  final TextEditingController notesController;

  _IngredientRow({
    required this.nameController,
    required this.amountController,
    required this.notesController,
  });

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    notesController.dispose();
  }
}
