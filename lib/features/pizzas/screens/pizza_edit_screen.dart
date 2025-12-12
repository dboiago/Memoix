import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../app/theme/colors.dart';
import '../models/pizza.dart';
import '../repository/pizza_repository.dart';

/// Pizza edit/create screen
class PizzaEditScreen extends ConsumerStatefulWidget {
  final String? pizzaId;

  const PizzaEditScreen({super.key, this.pizzaId});

  @override
  ConsumerState<PizzaEditScreen> createState() => _PizzaEditScreenState();
}

class _PizzaEditScreenState extends ConsumerState<PizzaEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _cheeseController = TextEditingController();
  final _toppingController = TextEditingController();

  PizzaBase _selectedBase = PizzaBase.tomato;
  List<String> _cheeses = [];
  List<String> _toppings = [];
  String? _imagePath;
  Pizza? _existingPizza;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPizza();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _cheeseController.dispose();
    _toppingController.dispose();
    super.dispose();
  }

  Future<void> _loadPizza() async {
    if (widget.pizzaId != null) {
      final repo = ref.read(pizzaRepositoryProvider);
      final pizza = await repo.getPizzaByUuid(widget.pizzaId!);
      if (pizza != null) {
        _existingPizza = pizza;
        _nameController.text = pizza.name;
        _notesController.text = pizza.notes ?? '';
        _selectedBase = pizza.base;
        _cheeses = List.from(pizza.cheeses);
        _toppings = List.from(pizza.toppings);
        _imagePath = pizza.imageUrl;
      }
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

            // Base dropdown
            DropdownButtonFormField<PizzaBase>(
              value: _selectedBase,
              decoration: const InputDecoration(
                labelText: 'Base Sauce',
                border: OutlineInputBorder(),
              ),
              items: PizzaBase.values.map((base) {
                return DropdownMenuItem(
                  value: base,
                  child: Text(base.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedBase = value);
                }
              },
            ),
            const SizedBox(height: 24),

            // Cheeses section
            _buildSectionHeader(theme, 'Cheeses'),
            const SizedBox(height: 8),
            _buildChipsInput(
              controller: _cheeseController,
              items: _cheeses,
              hintText: 'Add cheese...',
              onAdd: (value) {
                if (value.isNotEmpty && !_cheeses.contains(value)) {
                  setState(() => _cheeses.add(value));
                }
              },
              onRemove: (value) {
                setState(() => _cheeses.remove(value));
              },
              chipColor: Colors.amber.withOpacity(0.15),
              chipBorderColor: Colors.amber.withOpacity(0.4),
              chipTextColor: Colors.amber.shade800,
            ),
            const SizedBox(height: 24),

            // Toppings section
            _buildSectionHeader(theme, 'Toppings'),
            const SizedBox(height: 8),
            _buildChipsInput(
              controller: _toppingController,
              items: _toppings,
              hintText: 'Add topping...',
              onAdd: (value) {
                if (value.isNotEmpty && !_toppings.contains(value)) {
                  setState(() => _toppings.add(value));
                }
              },
              onRemove: (value) {
                setState(() => _toppings.remove(value));
              },
              chipColor: theme.colorScheme.secondaryContainer,
              chipBorderColor: theme.colorScheme.secondary.withOpacity(0.3),
              chipTextColor: theme.colorScheme.onSecondaryContainer,
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

            // Delete button (only for existing)
            if (isEditing)
              OutlinedButton.icon(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete Pizza'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
                ),
              ),
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

  Widget _buildChipsInput({
    required TextEditingController controller,
    required List<String> items,
    required String hintText,
    required Function(String) onAdd,
    required Function(String) onRemove,
    required Color chipColor,
    required Color chipBorderColor,
    required Color chipTextColor,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input row
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hintText,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (value) {
                  onAdd(value.trim());
                  controller.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                onAdd(controller.text.trim());
                controller.clear();
              },
              icon: const Icon(Icons.add_circle),
              color: theme.colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Chips
        if (items.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Chip(
                label: Text(item),
                onDeleted: () => onRemove(item),
                backgroundColor: chipColor,
                side: BorderSide(color: chipBorderColor),
                labelStyle: TextStyle(color: chipTextColor),
                deleteIconColor: chipTextColor,
              );
            }).toList(),
          ),
        if (items.isEmpty)
          Text(
            'None added yet',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
      ],
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

    final pizza = _existingPizza ?? Pizza();
    pizza
      ..uuid = _existingPizza?.uuid ?? const Uuid().v4()
      ..name = _nameController.text.trim()
      ..base = _selectedBase
      ..cheeses = _cheeses
      ..toppings = _toppings
      ..notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim()
      ..imageUrl = _imagePath
      ..source = _existingPizza?.source ?? PizzaSource.personal
      ..updatedAt = DateTime.now();

    if (_existingPizza == null) {
      pizza.createdAt = DateTime.now();
    }

    final repo = ref.read(pizzaRepositoryProvider);
    await repo.savePizza(pizza);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pizza.name} saved!')),
      );
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
              backgroundColor: Theme.of(context).colorScheme.error,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_existingPizza!.name} deleted')),
        );
      }
    }
  }
}
