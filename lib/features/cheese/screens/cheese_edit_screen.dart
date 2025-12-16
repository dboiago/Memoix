import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../models/cheese_entry.dart';
import '../repository/cheese_repository.dart';

/// Cheese edit/create screen
class CheeseEditScreen extends ConsumerStatefulWidget {
  final String? entryId;

  const CheeseEditScreen({super.key, this.entryId});

  @override
  ConsumerState<CheeseEditScreen> createState() => _CheeseEditScreenState();
}

class _CheeseEditScreenState extends ConsumerState<CheeseEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _milkController = TextEditingController();
  final _textureController = TextEditingController();
  final _typeController = TextEditingController();
  final _flavourController = TextEditingController();
  final _priceRangeController = TextEditingController();

  bool _buy = false;
  String? _imagePath;
  CheeseEntry? _existingEntry;
  bool _isLoading = true;

  // Common milk types for autocomplete
  static const List<String> _defaultMilkTypes = [
    'Cow',
    'Goat',
    'Sheep',
    'Buffalo',
    'Mixed',
  ];

  // Common textures for autocomplete
  static const List<String> _defaultTextures = [
    'Soft',
    'Semi-soft',
    'Semi-hard',
    'Hard',
    'Blue',
    'Fresh',
    'Washed Rind',
    'Bloomy Rind',
  ];

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _milkController.dispose();
    _textureController.dispose();
    _typeController.dispose();
    _flavourController.dispose();
    _priceRangeController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    if (widget.entryId != null) {
      final repo = ref.read(cheeseRepositoryProvider);
      final entry = await repo.getEntryByUuid(widget.entryId!);
      if (entry != null) {
        _existingEntry = entry;
        _nameController.text = entry.name;
        _countryController.text = entry.country ?? '';
        _milkController.text = entry.milk ?? '';
        _textureController.text = entry.texture ?? '';
        _typeController.text = entry.type ?? '';
        _flavourController.text = entry.flavour ?? '';
        _priceRangeController.text = entry.priceRange ?? '';
        _buy = entry.buy;
        _imagePath = entry.imageUrl;
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.entryId != null;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(isEditing ? 'Edit Cheese' : 'New Cheese')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Cheese' : 'New Cheese'),
        actions: [
          TextButton(
            onPressed: _saveEntry,
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
                labelText: 'Name *',
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

            // Country and Milk (side by side)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _countryController,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return _defaultMilkTypes;
                      }
                      return _defaultMilkTypes.where((m) =>
                          m.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      if (controller.text != _milkController.text) {
                        controller.text = _milkController.text;
                      }
                      controller.addListener(() {
                        if (_milkController.text != controller.text) {
                          _milkController.text = controller.text;
                        }
                      });
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Milk',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        onFieldSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
                    onSelected: (selection) {
                      _milkController.text = selection;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Texture and Type (side by side)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return _defaultTextures;
                      }
                      return _defaultTextures.where((t) =>
                          t.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      if (controller.text != _textureController.text) {
                        controller.text = _textureController.text;
                      }
                      controller.addListener(() {
                        if (_textureController.text != controller.text) {
                          _textureController.text = controller.text;
                        }
                      });
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Texture',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        onFieldSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
                    onSelected: (selection) {
                      _textureController.text = selection;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _typeController,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Buy toggle
            SwitchListTile(
              title: const Text('Would buy again'),
              value: _buy,
              onChanged: (value) => setState(() => _buy = value),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Flavour notes
            TextFormField(
              controller: _flavourController,
              decoration: const InputDecoration(
                labelText: 'Flavour Notes',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Price range (optional)
            TextFormField(
              controller: _priceRangeController,
              decoration: const InputDecoration(
                labelText: 'Price Range',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 80),
          ],
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
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/cheese_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = '${const Uuid().v4()}${path.extension(pickedFile.path)}';
      final savedPath = '${imagesDir.path}/$fileName';
      await File(pickedFile.path).copy(savedPath);

      setState(() => _imagePath = savedPath);
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final entry = _existingEntry ?? CheeseEntry();
    entry
      ..uuid = _existingEntry?.uuid ?? const Uuid().v4()
      ..name = _nameController.text.trim()
      ..country = _countryController.text.trim().isEmpty ? null : _countryController.text.trim()
      ..milk = _milkController.text.trim().isEmpty ? null : _milkController.text.trim()
      ..texture = _textureController.text.trim().isEmpty ? null : _textureController.text.trim()
      ..type = _typeController.text.trim().isEmpty ? null : _typeController.text.trim()
      ..buy = _buy
      ..flavour = _flavourController.text.trim().isEmpty ? null : _flavourController.text.trim()
      ..priceRange = _priceRangeController.text.trim().isEmpty ? null : _priceRangeController.text.trim()
      ..imageUrl = _imagePath
      ..source = _existingEntry?.source ?? CheeseSource.personal
      ..updatedAt = DateTime.now();

    if (_existingEntry == null) {
      entry.createdAt = DateTime.now();
    }

    final repo = ref.read(cheeseRepositoryProvider);
    await repo.saveEntry(entry);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entry.name} saved!')),
      );
      Navigator.of(context).pop();
    }
  }
}
