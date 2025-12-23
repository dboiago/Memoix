import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../core/utils/suggestions.dart';
import '../models/pizza.dart';
import '../repository/pizza_repository.dart';
import '../../../core/widgets/memoix_snackbar.dart';

/// Pizza edit/create screen
class PizzaEditScreen extends ConsumerStatefulWidget {
  final String? pizzaId;
  /// Pre-populated pizza for imports (not yet saved)
  final Pizza? importedRecipe;

  const PizzaEditScreen({super.key, this.pizzaId, this.importedRecipe});

  @override
  ConsumerState<PizzaEditScreen> createState() => _PizzaEditScreenState();
}

class _PizzaEditScreenState extends ConsumerState<PizzaEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  // Controllers for cheese rows
  final List<TextEditingController> _cheeseControllers = [];
  // Controllers for protein rows  
  final List<TextEditingController> _proteinControllers = [];
  // Controllers for vegetable rows
  final List<TextEditingController> _vegetableControllers = [];

  String _selectedBase = 'Tomato'; // String to allow custom bases
  String? _imagePath;
  Pizza? _existingPizza;
  bool _isLoading = true;

  // Predefined bases
  static const List<String> _defaultBases = [
    'Tomato',
    'Oil',
    'Pesto',
    'Cream',
    'BBQ Sauce',
    'Buffalo',
    'Alfredo',
    'Garlic Butter',
    'Marinara',
    'No Sauce',
  ];

  @override
  void initState() {
    super.initState();
    _addCheeseRow(); // Start with one empty row
    _addProteinRow(); // Start with one empty row
    _addVegetableRow(); // Start with one empty row
    _loadPizza();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    for (final c in _cheeseControllers) {
      c.dispose();
    }
    for (final c in _proteinControllers) {
      c.dispose();
    }
    for (final c in _vegetableControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addCheeseRow({String value = ''}) {
    final controller = TextEditingController(text: value);
    controller.addListener(() => _onCheeseChanged());
    _cheeseControllers.add(controller);
  }

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

  void _onCheeseChanged() {
    // If last row has content, add a new empty row
    if (_cheeseControllers.isNotEmpty && 
        _cheeseControllers.last.text.isNotEmpty) {
      setState(() => _addCheeseRow());
    }
  }

  void _onProteinChanged() {
    // If last row has content, add a new empty row
    if (_proteinControllers.isNotEmpty && 
        _proteinControllers.last.text.isNotEmpty) {
      setState(() => _addProteinRow());
    }
  }

  void _onVegetableChanged() {
    // If last row has content, add a new empty row
    if (_vegetableControllers.isNotEmpty && 
        _vegetableControllers.last.text.isNotEmpty) {
      setState(() => _addVegetableRow());
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

  Future<void> _loadPizza() async {
    Pizza? pizza;
    
    if (widget.pizzaId != null) {
      final repo = ref.read(pizzaRepositoryProvider);
      pizza = await repo.getPizzaByUuid(widget.pizzaId!);
      if (pizza != null) {
        _existingPizza = pizza;
      }
    } else if (widget.importedRecipe != null) {
      pizza = widget.importedRecipe;
      // importedRecipe is not saved yet, so don't set _existingPizza
    }
    
    if (pizza != null) {
      _nameController.text = pizza.name;
      _notesController.text = pizza.notes ?? '';
      _selectedBase = pizza.base.displayName;
      _imagePath = pizza.imageUrl;

      // Clear default rows and load cheeses
      for (final c in _cheeseControllers) {
        c.dispose();
      }
      _cheeseControllers.clear();
      for (final cheese in pizza.cheeses) {
        _addCheeseRow(value: cheese);
      }
      _addCheeseRow(); // Add empty row at end

      // Clear default rows and load proteins
      for (final c in _proteinControllers) {
        c.dispose();
      }
      _proteinControllers.clear();
      for (final protein in pizza.proteins) {
        _addProteinRow(value: protein);
      }
      _addProteinRow(); // Add empty row at end

      // Clear default rows and load vegetables
      for (final c in _vegetableControllers) {
        c.dispose();
      }
      _vegetableControllers.clear();
      for (final vegetable in pizza.vegetables) {
        _addVegetableRow(value: vegetable);
      }
      _addVegetableRow(); // Add empty row at end
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.pizzaId != null;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(isEditing ? 'Edit Pizza' : 'New Pizza')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Pizza' : 'New Pizza'),
        actions: [
          TextButton(
            onPressed: _savePizza,
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
                labelText: 'Pizza Name *',
                hintText: 'e.g., Margherita, BBQ Chicken',
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

            // Base sauce + Cheeses (side by side)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(theme, 'Base Sauce'),
                      const SizedBox(height: 8),
                      _buildBaseSauceSelector(theme),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(theme, 'Cheeses'),
                      const SizedBox(height: 8),
                      _buildCheeseRows(theme),
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
                hintText: 'Special instructions, timing tips, etc.',
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

  Widget _buildBaseSauceSelector(ThemeData theme) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _selectedBase),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return _defaultBases;
        }
        final matches = _defaultBases.where(
          (base) => base.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        ).toList();
        // Always allow the typed value as an option if not in suggestions
        final typed = textEditingValue.text.trim();
        if (typed.isNotEmpty && !matches.any((m) => m.toLowerCase() == typed.toLowerCase())) {
          return [...matches, typed];
        }
        return matches;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            hintText: 'e.g., Tomato, Pesto',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => onFieldSubmitted(),
          onChanged: (value) {
            setState(() => _selectedBase = value.trim().isEmpty ? 'Tomato' : value.trim());
          },
        );
      },
      onSelected: (selection) {
        setState(() => _selectedBase = selection);
      },
      optionsViewBuilder: (context, onSelected, options) {
        return _buildOptionsView(context, onSelected, options, theme);
      },
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
                child: Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return Suggestions.cheeses;
                    }
                    return Suggestions.filter(
                      Suggestions.cheeses, 
                      textEditingValue.text,
                    );
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    // Sync with our controller
                    if (controller.text != _cheeseControllers[index].text) {
                      controller.text = _cheeseControllers[index].text;
                      controller.selection = TextSelection.collapsed(
                        offset: controller.text.length,
                      );
                    }
                    controller.addListener(() {
                      if (_cheeseControllers[index].text != controller.text) {
                        _cheeseControllers[index].text = controller.text;
                      }
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: index == 0 && _cheeseControllers.length == 1
                            ? 'e.g., Mozzarella'
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => onFieldSubmitted(),
                    );
                  },
                  onSelected: (selection) {
                    _cheeseControllers[index].text = selection;
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return _buildOptionsView(context, onSelected, options, theme);
                  },
                ),
              ),
              if (_cheeseControllers[index].text.isNotEmpty || _cheeseControllers.length > 1)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, 
                    color: theme.colorScheme.error.withOpacity(0.7),),
                  onPressed: () => _removeCheeseRow(index),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        );
      }),
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
                child: Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return Suggestions.pizzaProteins;
                    }
                    return Suggestions.filter(
                      Suggestions.pizzaProteins, 
                      textEditingValue.text,
                    );
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    // Sync with our controller
                    if (controller.text != _proteinControllers[index].text) {
                      controller.text = _proteinControllers[index].text;
                      controller.selection = TextSelection.collapsed(
                        offset: controller.text.length,
                      );
                    }
                    controller.addListener(() {
                      if (_proteinControllers[index].text != controller.text) {
                        _proteinControllers[index].text = controller.text;
                      }
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: index == 0 && _proteinControllers.length == 1
                            ? 'e.g., Pepperoni'
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => onFieldSubmitted(),
                    );
                  },
                  onSelected: (selection) {
                    _proteinControllers[index].text = selection;
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return _buildOptionsView(context, onSelected, options, theme);
                  },
                ),
              ),
              if (_proteinControllers[index].text.isNotEmpty || _proteinControllers.length > 1)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, 
                    color: theme.colorScheme.error.withOpacity(0.7),),
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
                child: Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return Suggestions.pizzaVegetables;
                    }
                    return Suggestions.filter(
                      Suggestions.pizzaVegetables, 
                      textEditingValue.text,
                    );
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    // Sync with our controller
                    if (controller.text != _vegetableControllers[index].text) {
                      controller.text = _vegetableControllers[index].text;
                      controller.selection = TextSelection.collapsed(
                        offset: controller.text.length,
                      );
                    }
                    controller.addListener(() {
                      if (_vegetableControllers[index].text != controller.text) {
                        _vegetableControllers[index].text = controller.text;
                      }
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: index == 0 && _vegetableControllers.length == 1
                            ? 'e.g., Mushrooms'
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => onFieldSubmitted(),
                    );
                  },
                  onSelected: (selection) {
                    _vegetableControllers[index].text = selection;
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return _buildOptionsView(context, onSelected, options, theme);
                  },
                ),
              ),
              if (_vegetableControllers[index].text.isNotEmpty || _vegetableControllers.length > 1)
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, 
                    color: theme.colorScheme.error.withOpacity(0.7),),
                  onPressed: () => _removeVegetableRow(index),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        );
      }),
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
      final imagesDir = Directory('${appDir.path}/pizza_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = '${const Uuid().v4()}${path.extension(pickedFile.path)}';
      final savedPath = '${imagesDir.path}/$fileName';
      await File(pickedFile.path).copy(savedPath);

      setState(() => _imagePath = savedPath);
    }
  }

  Future<void> _savePizza() async {
    if (!_formKey.currentState!.validate()) return;

    // Collect non-empty values from controllers
    final cheeses = _cheeseControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final proteins = _proteinControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final vegetables = _vegetableControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final pizza = _existingPizza ?? Pizza();
    pizza
      ..uuid = _existingPizza?.uuid ?? const Uuid().v4()
      ..name = _nameController.text.trim()
      ..base = PizzaBaseExtension.fromString(_selectedBase)
      ..cheeses = cheeses
      ..proteins = proteins
      ..vegetables = vegetables
      ..notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim()
      ..imageUrl = _imagePath
      ..source = _existingPizza?.source ?? PizzaSource.personal
      ..updatedAt = DateTime.now();

    if (_existingPizza == null) {
      pizza.createdAt = DateTime.now();
    }

    final repo = ref.read(pizzaRepositoryProvider);
    await repo.savePizza(pizza);

    MemoixSnackBar.show('${pizza.name} saved');
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDelete() async {
    if (_existingPizza == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Pizza?'),
        content: Text('Are you sure you want to delete "${_existingPizza!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(pizzaRepositoryProvider).deletePizza(_existingPizza!.id);
      if (mounted) {
        Navigator.of(context).pop();
        MemoixSnackBar.show('${_existingPizza!.name} deleted');
      }
    }
  }
}
