import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../core/utils/suggestions.dart';
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
  String? _selectedCategory;
  final _temperatureController = TextEditingController();
  final _timeController = TextEditingController();
  final _woodController = TextEditingController();
  final _notesController = TextEditingController();

  String? _imagePath; // Header image - local file path or URL
  final List<String> _stepImages = []; // Step images
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
      _itemController.text = recipe.item ?? '';
      _selectedCategory = recipe.category;
      _temperatureController.text = recipe.temperature;
      _timeController.text = recipe.time;
      _woodController.text = recipe.wood;
      _notesController.text = recipe.notes ?? '';
      _imagePath = recipe.imageUrl;
      _stepImages.addAll(recipe.stepImages);

      for (final seasoning in recipe.seasonings) {
        _seasonings.add(_SeasoningEntry(
          nameController: TextEditingController(text: seasoning.name),
          amountController: TextEditingController(text: seasoning.amount ?? ''),
        ),);
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
        _itemController.text = recipe.item ?? '';
        _selectedCategory = recipe.category;
        _temperatureController.text = recipe.temperature;
        _timeController.text = recipe.time;
        _woodController.text = recipe.wood;
        _notesController.text = recipe.notes ?? '';
        _imagePath = recipe.imageUrl;
        _stepImages.addAll(recipe.stepImages);

        for (final seasoning in recipe.seasonings) {
          _seasonings.add(_SeasoningEntry(
            nameController: TextEditingController(text: seasoning.name),
            amountController: TextEditingController(text: seasoning.amount ?? ''),
          ),);
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
            // Recipe Photo (top for consistency)
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

            // Item and Category row
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
                        if (detectedCategory != null && _selectedCategory == null) {
                          setState(() => _selectedCategory = detectedCategory);
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
                        setState(() => _selectedCategory = detectedCategory);
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
                // Category dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                    ),
                    items: SmokingCategory.all.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value),
                  ),
                ),
              ],
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
                  ),
                  validator: (v) =>
                      v?.isEmpty ?? true ? 'Wood type is required' : null,
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

            // Seasonings section
            _buildSectionTitle(theme, 'Seasonings'),
            const SizedBox(height: 8),
            ..._buildSeasoningFields(),

            const SizedBox(height: 24),

            // Directions section
            _buildSectionTitle(theme, 'Directions'),
            const SizedBox(height: 8),
            ..._buildDirectionFields(),

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
            SizedBox(
              width: 120,
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

  List<Widget> _buildDirectionFields() {
    return _directionControllers.asMap().entries.map((entry) {
      final index = entry.key;
      final controller = entry.value;
      final theme = Theme.of(context);
      final isLast = index == _directionControllers.length - 1;

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
                onChanged: (value) {
                  // Auto-add new row when typing in last row
                  if (isLast && value.isNotEmpty && _directionControllers.length == index + 1) {
                    _addDirection();
                  }
                },
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
      ),);
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

  Widget _buildStepImagesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Step Images',
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
      _stepImages.removeAt(index);
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
              : s.amountController.text.trim(),)
        .toList();

    // Build directions list
    final directions = _directionControllers
        .map((c) => c.text.trim())
        .where((d) => d.isNotEmpty)
        .toList();

    final recipe = SmokingRecipe()
      ..uuid = _existingRecipe?.uuid ?? const Uuid().v4()
      ..name = _nameController.text.trim()
      ..item = _itemController.text.trim().isEmpty
          ? null
          : _itemController.text.trim()
      ..category = _selectedCategory
      ..temperature = _temperatureController.text.trim()
      ..time = _timeController.text.trim()
      ..wood = _woodController.text.trim()
      ..seasonings = seasonings
      ..directions = directions
      ..notes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim()
      ..imageUrl = _imagePath
      ..stepImages = _stepImages
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
