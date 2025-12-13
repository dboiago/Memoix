import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

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
  final _temperatureController = TextEditingController();
  final _timeController = TextEditingController();
  final _woodController = TextEditingController();
  final _notesController = TextEditingController();

  String? _imagePath; // Local file path or URL
  final List<_SeasoningEntry> _seasonings = [];
  final List<TextEditingController> _directionControllers = [];

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
      _temperatureController.text = recipe.temperature;
      _timeController.text = recipe.time;
      _woodController.text = recipe.wood;
      _notesController.text = recipe.notes ?? '';
      _imagePath = recipe.imageUrl;

      for (final seasoning in recipe.seasonings) {
        _seasonings.add(_SeasoningEntry(
          nameController: TextEditingController(text: seasoning.name),
          amountController: TextEditingController(text: seasoning.amount ?? ''),
        ));
      }

      for (final direction in recipe.directions) {
        _directionControllers.add(TextEditingController(text: direction));
      }
    } else if (widget.recipeId != null) {
      final recipe = await ref
          .read(smokingRepositoryProvider)
          .getRecipeByUuid(widget.recipeId!);
      if (recipe != null) {
        _existingRecipe = recipe;
        _nameController.text = recipe.name;
        _temperatureController.text = recipe.temperature;
        _timeController.text = recipe.time;
        _woodController.text = recipe.wood;
        _notesController.text = recipe.notes ?? '';
        _imagePath = recipe.imageUrl;

        for (final seasoning in recipe.seasonings) {
          _seasonings.add(_SeasoningEntry(
            nameController: TextEditingController(text: seasoning.name),
            amountController: TextEditingController(text: seasoning.amount ?? ''),
          ));
        }

        for (final direction in recipe.directions) {
          _directionControllers.add(TextEditingController(text: direction));
        }
      }
    }

    // Ensure at least one empty field for each
    if (_seasonings.isEmpty) {
      _seasonings.add(_SeasoningEntry(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
      ));
    }
    if (_directionControllers.isEmpty) {
      _directionControllers.add(TextEditingController());
    }
    // Default wood for new recipes
    if (_woodController.text.isEmpty) {
      _woodController.text = 'Hickory';
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _temperatureController.dispose();
    _timeController.dispose();
    _woodController.dispose();
    _notesController.dispose();
    for (final entry in _seasonings) {
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
          TextButton(
            onPressed: _saveRecipe,
            child: const Text('Save'),
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
                labelText: 'Name *',
                hintText: 'e.g., Brisket, Pulled Pork, Watermelon',
                prefixIcon: Icon(Icons.restaurant),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Name is required' : null,
              textCapitalization: TextCapitalization.words,
            ),

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
                      prefixIcon: Icon(Icons.thermostat),
                    ),
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Temperature is required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _timeController,
                    decoration: const InputDecoration(
                      labelText: 'Time *',
                      hintText: 'e.g., 8-12 hrs',
                      prefixIcon: Icon(Icons.timer),
                    ),
                    validator: (v) =>
                        v?.isEmpty ?? true ? 'Time is required' : null,
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
                    labelText: 'Wood Type *',
                    hintText: 'e.g., Hickory, Cherry, Apple',
                    prefixIcon: Icon(Icons.park),
                  ),
                  validator: (v) =>
                      v?.isEmpty ?? true ? 'Wood type is required' : null,
                  textCapitalization: TextCapitalization.words,
                );
              },
              onSelected: (selection) {
                _woodController.text = selection;
              },
            ),

            const SizedBox(height: 24),

            // Seasonings section
            _buildSectionTitle(theme, 'Seasonings', Icons.grain),
            const SizedBox(height: 8),
            ..._buildSeasoningFields(),
            TextButton.icon(
              onPressed: _addSeasoning,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Seasoning'),
            ),

            const SizedBox(height: 24),

            // Directions section
            _buildSectionTitle(theme, 'Directions', Icons.format_list_numbered),
            const SizedBox(height: 8),
            ..._buildDirectionFields(),
            TextButton.icon(
              onPressed: _addDirection,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Step'),
            ),

            const SizedBox(height: 24),

            // Recipe Photo
            _buildImagePicker(theme),

            const SizedBox(height: 16),

            // Notes field
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Additional tips or variations...',
                prefixIcon: Icon(Icons.note),
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

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
            // Ingredient/Seasoning name
            SizedBox(
              width: 120,
              child: TextField(
                controller: seasoning.nameController,
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
                  if (isLast && value.isNotEmpty) {
                    _addSeasoning();
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
                  color: theme.colorScheme.error,
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

  List<Widget> _buildDirectionFields() {
    return _directionControllers.asMap().entries.map((entry) {
      final index = entry.key;
      final controller = entry.value;
      final theme = Theme.of(context);

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step number
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.secondary,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Describe this step...',
                  suffixIcon: _directionControllers.length > 1
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () => _removeDirection(index),
                        )
                      : null,
                ),
                maxLines: null,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _addSeasoning() {
    setState(() {
      _seasonings.add(_SeasoningEntry(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
      ));
    });
  }

  void _removeSeasoning(int index) {
    setState(() {
      _seasonings[index].dispose();
      _seasonings.removeAt(index);
    });
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
    });
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    // Build seasonings list
    final seasonings = _seasonings
        .where((s) => s.nameController.text.trim().isNotEmpty)
        .map((s) => SmokingSeasoning()
          ..name = s.nameController.text.trim()
          ..amount = s.amountController.text.trim().isEmpty
              ? null
              : s.amountController.text.trim())
        .toList();

    // Build directions list
    final directions = _directionControllers
        .map((c) => c.text.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    final recipe = SmokingRecipe()
      ..uuid = _existingRecipe?.uuid ?? const Uuid().v4()
      ..name = _nameController.text.trim()
      ..temperature = _temperatureController.text.trim()
      ..time = _timeController.text.trim()
      ..wood = _woodController.text.trim()
      ..seasonings = seasonings
      ..directions = directions
      ..notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim()
      ..imageUrl = _imagePath
      ..source = _existingRecipe?.source ?? SmokingSource.personal
      ..createdAt = _existingRecipe?.createdAt ?? DateTime.now()
      ..updatedAt = DateTime.now();

    await ref.read(smokingRepositoryProvider).saveRecipe(recipe);

    if (mounted) {
      Navigator.pop(context);
    }
  }
}

/// Helper class to manage seasoning input fields
class _SeasoningEntry {
  final TextEditingController nameController;
  final TextEditingController amountController;

  _SeasoningEntry({
    required this.nameController,
    required this.amountController,
  });

  void dispose() {
    nameController.dispose();
    amountController.dispose();
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
