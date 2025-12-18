import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../core/utils/suggestions.dart';
import '../models/sandwich.dart';
import '../repository/sandwich_repository.dart';

/// Sandwich edit/create screen with side-by-side layout
class SandwichEditScreen extends ConsumerStatefulWidget {
  final String? sandwichId;
  /// Pre-populated sandwich for imports (not yet saved)
  final Sandwich? importedRecipe;

  const SandwichEditScreen({super.key, this.sandwichId, this.importedRecipe});

  @override
  ConsumerState<SandwichEditScreen> createState() => _SandwichEditScreenState();
}

class _SandwichEditScreenState extends ConsumerState<SandwichEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breadController = TextEditingController();
  final _notesController = TextEditingController();

  // Controllers for dynamic rows
  final List<TextEditingController> _proteinControllers = [];
  final List<TextEditingController> _vegetableControllers = [];
  final List<TextEditingController> _cheeseControllers = [];
  final List<TextEditingController> _condimentControllers = [];

  String? _imagePath;
  Sandwich? _existingSandwich;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _addProteinRow();
    _addVegetableRow();
    _addCheeseRow();
    _addCondimentRow();
    _loadSandwich();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breadController.dispose();
    _notesController.dispose();
    for (final c in _proteinControllers) {
      c.dispose();
    }
    for (final c in _vegetableControllers) {
      c.dispose();
    }
    for (final c in _cheeseControllers) {
      c.dispose();
    }
    for (final c in _condimentControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // Row management methods
  void _addProteinRow({String value = ''}) {
    final controller = TextEditingController(text: value);
    controller.addListener(() => _onProteinChanged());
    _proteinControllers.add(controller);
  }

  void _addVegetableRow({String value = ''}) {
    final controller = TextEditingController(text: value);
    controller.addListener(() => _onVegetableChanged());
    _vegetableControllers.add(controller);
  }

  void _addCheeseRow({String value = ''}) {
    final controller = TextEditingController(text: value);
    controller.addListener(() => _onCheeseChanged());
    _cheeseControllers.add(controller);
  }

  void _addCondimentRow({String value = ''}) {
    final controller = TextEditingController(text: value);
    controller.addListener(() => _onCondimentChanged());
    _condimentControllers.add(controller);
  }

  void _onProteinChanged() {
    if (_proteinControllers.isNotEmpty && _proteinControllers.last.text.isNotEmpty) {
      setState(() => _addProteinRow());
    }
  }

  void _onVegetableChanged() {
    if (_vegetableControllers.isNotEmpty && _vegetableControllers.last.text.isNotEmpty) {
      setState(() => _addVegetableRow());
    }
  }

  void _onCheeseChanged() {
    if (_cheeseControllers.isNotEmpty && _cheeseControllers.last.text.isNotEmpty) {
      setState(() => _addCheeseRow());
    }
  }

  void _onCondimentChanged() {
    if (_condimentControllers.isNotEmpty && _condimentControllers.last.text.isNotEmpty) {
      setState(() => _addCondimentRow());
    }
  }

  void _removeProteinRow(int index) {
    if (_proteinControllers.length > 1) {
      setState(() {
        _proteinControllers[index].dispose();
        _proteinControllers.removeAt(index);
      });
    }
  }

  void _removeVegetableRow(int index) {
    if (_vegetableControllers.length > 1) {
      setState(() {
        _vegetableControllers[index].dispose();
        _vegetableControllers.removeAt(index);
      });
    }
  }

  void _removeCheeseRow(int index) {
    if (_cheeseControllers.length > 1) {
      setState(() {
        _cheeseControllers[index].dispose();
        _cheeseControllers.removeAt(index);
      });
    }
  }

  void _removeCondimentRow(int index) {
    if (_condimentControllers.length > 1) {
      setState(() {
        _condimentControllers[index].dispose();
        _condimentControllers.removeAt(index);
      });
    }
  }

  Future<void> _loadSandwich() async {
    Sandwich? sandwich;
    
    if (widget.sandwichId != null) {
      final repo = ref.read(sandwichRepositoryProvider);
      sandwich = await repo.getSandwichByUuid(widget.sandwichId!);
      if (sandwich != null) {
        _existingSandwich = sandwich;
      }
    } else if (widget.importedRecipe != null) {
      sandwich = widget.importedRecipe;
    }
    
    if (sandwich != null) {
      _nameController.text = sandwich.name;
      _breadController.text = sandwich.bread;
      _notesController.text = sandwich.notes ?? '';
      _imagePath = sandwich.imageUrl;

      // Load proteins
      for (final c in _proteinControllers) {
        c.dispose();
      }
      _proteinControllers.clear();
      for (final protein in sandwich.proteins) {
        _addProteinRow(value: protein);
      }
      _addProteinRow();

      // Load vegetables
      for (final c in _vegetableControllers) {
        c.dispose();
      }
      _vegetableControllers.clear();
      for (final vegetable in sandwich.vegetables) {
        _addVegetableRow(value: vegetable);
      }
      _addVegetableRow();

      // Load cheeses
      for (final c in _cheeseControllers) {
        c.dispose();
      }
      _cheeseControllers.clear();
      for (final cheese in sandwich.cheeses) {
        _addCheeseRow(value: cheese);
      }
      _addCheeseRow();

      // Load condiments
      for (final c in _condimentControllers) {
        c.dispose();
      }
      _condimentControllers.clear();
      for (final condiment in sandwich.condiments) {
        _addCondimentRow(value: condiment);
      }
      _addCondimentRow();
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.sandwichId != null;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(isEditing ? 'Edit Sandwich' : 'New Sandwich')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Sandwich' : 'New Sandwich'),
        actions: [
          TextButton(
            onPressed: _saveSandwich,
            child: Text(
              'Save',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image picker
            _buildImagePicker(theme),
            const SizedBox(height: 24),

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Sandwich Name *',
                hintText: 'e.g., Bourbon Street, Cuban',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Bread field (full width with autocomplete)
            _buildBreadField(theme),
            const SizedBox(height: 24),

            // Cheese + Condiments (side by side) - above proteins/veggies for easier navigation
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(theme, 'Cheese'),
                      const SizedBox(height: 8),
                      _buildCheeseRows(theme),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(theme, 'Condiments'),
                      const SizedBox(height: 8),
                      _buildCondimentRows(theme),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Proteins + Vegetables (side by side)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(theme, 'Proteins'),
                      const SizedBox(height: 8),
                      _buildProteinRows(theme),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(theme, 'Vegetables'),
                      const SizedBox(height: 8),
                      _buildVegetableRows(theme),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Notes field
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Special instructions, assembly tips, etc.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 32),

            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildBreadField(ThemeData theme) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return Suggestions.breads;
        }
        return Suggestions.filter(Suggestions.breads, textEditingValue.text);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Sync with our controller
        if (controller.text != _breadController.text) {
          controller.text = _breadController.text;
          controller.selection = TextSelection.collapsed(offset: controller.text.length);
        }
        controller.addListener(() {
          if (_breadController.text != controller.text) {
            _breadController.text = controller.text;
          }
        });
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Bread',
            hintText: 'e.g., Sourdough, Ciabatta',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      onSelected: (selection) {
        _breadController.text = selection;
      },
      optionsViewBuilder: (context, onSelected, options) {
        return _buildOptionsView(context, onSelected, options, theme);
      },
    );
  }

  Widget _buildProteinRows(ThemeData theme) {
    return Column(
      children: List.generate(_proteinControllers.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildAutocompleteRow(
                  controller: _proteinControllers[index],
                  suggestions: Suggestions.proteins,
                  hintText: index == 0 && _proteinControllers.length == 1 ? 'e.g., Chicken' : null,
                  theme: theme,
                ),
              ),
              if (_proteinControllers[index].text.isNotEmpty || _proteinControllers.length > 1)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, 
                    color: theme.colorScheme.secondary.withOpacity(0.7)),
                  onPressed: () => _removeProteinRow(index),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildVegetableRows(ThemeData theme) {
    return Column(
      children: List.generate(_vegetableControllers.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildAutocompleteRow(
                  controller: _vegetableControllers[index],
                  suggestions: Suggestions.vegetables,
                  hintText: index == 0 && _vegetableControllers.length == 1 ? 'e.g., Lettuce' : null,
                  theme: theme,
                ),
              ),
              if (_vegetableControllers[index].text.isNotEmpty || _vegetableControllers.length > 1)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, 
                    color: theme.colorScheme.secondary.withOpacity(0.7)),
                  onPressed: () => _removeVegetableRow(index),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCheeseRows(ThemeData theme) {
    return Column(
      children: List.generate(_cheeseControllers.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildAutocompleteRow(
                  controller: _cheeseControllers[index],
                  suggestions: Suggestions.cheeses,
                  hintText: index == 0 && _cheeseControllers.length == 1 ? 'e.g., Swiss' : null,
                  theme: theme,
                ),
              ),
              if (_cheeseControllers[index].text.isNotEmpty || _cheeseControllers.length > 1)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, 
                    color: theme.colorScheme.secondary.withOpacity(0.7)),
                  onPressed: () => _removeCheeseRow(index),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCondimentRows(ThemeData theme) {
    return Column(
      children: List.generate(_condimentControllers.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildAutocompleteRow(
                  controller: _condimentControllers[index],
                  suggestions: Suggestions.condiments,
                  hintText: index == 0 && _condimentControllers.length == 1 ? 'e.g., Mayo' : null,
                  theme: theme,
                ),
              ),
              if (_condimentControllers[index].text.isNotEmpty || _condimentControllers.length > 1)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, 
                    color: theme.colorScheme.secondary.withOpacity(0.7)),
                  onPressed: () => _removeCondimentRow(index),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildAutocompleteRow({
    required TextEditingController controller,
    required List<String> suggestions,
    String? hintText,
    required ThemeData theme,
  }) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return suggestions;
        }
        return Suggestions.filter(suggestions, textEditingValue.text);
      },
      fieldViewBuilder: (context, acController, focusNode, onFieldSubmitted) {
        // Sync with our controller
        if (acController.text != controller.text) {
          acController.text = controller.text;
          acController.selection = TextSelection.collapsed(offset: acController.text.length);
        }
        acController.addListener(() {
          if (controller.text != acController.text) {
            controller.text = acController.text;
          }
        });
        return TextField(
          controller: acController,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      onSelected: (selection) {
        controller.text = selection;
      },
      optionsViewBuilder: (context, onSelected, options) {
        return _buildOptionsView(context, onSelected, options, theme);
      },
    );
  }

  Widget _buildOptionsView(
    BuildContext context,
    AutocompleteOnSelected<String> onSelected,
    Iterable<String> options,
    ThemeData theme,
  ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 200,
            maxWidth: 280,
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
  }

  Widget _buildImagePicker(ThemeData theme) {
    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: _imagePath != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildImageWidget(),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      children: [
                        _imageActionButton(
                          icon: Icons.edit,
                          onPressed: _showImageSourceDialog,
                        ),
                        const SizedBox(width: 4),
                        _imageActionButton(
                          icon: Icons.delete,
                          onPressed: () => setState(() => _imagePath = null),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo,
                    size: 48,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to add photo',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _imageActionButton({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildImageWidget() {
    if (_imagePath == null) return const SizedBox.shrink();

    if (_imagePath!.startsWith('http://') || _imagePath!.startsWith('https://')) {
      return Image.network(
        _imagePath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, size: 48),
        ),
      );
    } else {
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
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      // Save to app documents
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/sandwich_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = '${const Uuid().v4()}${path.extension(pickedFile.path)}';
      final savedPath = '${imagesDir.path}/$fileName';
      await File(pickedFile.path).copy(savedPath);

      setState(() => _imagePath = savedPath);
    }
  }

  Future<void> _saveSandwich() async {
    if (!_formKey.currentState!.validate()) return;

    // Collect non-empty values from controllers
    final proteins = _proteinControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final vegetables = _vegetableControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final cheeses = _cheeseControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final condiments = _condimentControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final sandwich = _existingSandwich ?? Sandwich();
    sandwich
      ..uuid = _existingSandwich?.uuid ?? const Uuid().v4()
      ..name = _nameController.text.trim()
      ..bread = _breadController.text.trim()
      ..proteins = proteins
      ..vegetables = vegetables
      ..cheeses = cheeses
      ..condiments = condiments
      ..notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim()
      ..imageUrl = _imagePath
      ..source = _existingSandwich?.source ?? SandwichSource.personal
      ..updatedAt = DateTime.now();

    if (_existingSandwich == null) {
      sandwich.createdAt = DateTime.now();
    }

    final repo = ref.read(sandwichRepositoryProvider);
    await repo.saveSandwich(sandwich);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${sandwich.name} saved')),
      );
      Navigator.of(context).pop();
    }
  }
}
