import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../models/cellar_entry.dart';
import '../repository/cellar_repository.dart';

/// Cellar edit/create screen
class CellarEditScreen extends ConsumerStatefulWidget {
  final String? entryId;

  const CellarEditScreen({super.key, this.entryId});

  @override
  ConsumerState<CellarEditScreen> createState() => _CellarEditScreenState();
}

class _CellarEditScreenState extends ConsumerState<CellarEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _producerController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tastingNotesController = TextEditingController();
  final _abvController = TextEditingController();
  final _ageVintageController = TextEditingController();
  final _priceRangeController = TextEditingController();

  bool _buy = false;
  String? _imagePath;
  CellarEntry? _existingEntry;
  bool _isLoading = true;

  // Common categories for autocomplete
  static const List<String> _defaultCategories = [
    'Wine',
    'Whiskey',
    'Gin',
    'Rum',
    'Tequila',
    'Vodka',
    'Brandy',
    'Beer',
    'Cider',
    'Coffee',
    'Tea',
    'Sake',
    'Mezcal',
    'Liqueur',
    'Port',
    'Sherry',
  ];

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _producerController.dispose();
    _categoryController.dispose();
    _tastingNotesController.dispose();
    _abvController.dispose();
    _ageVintageController.dispose();
    _priceRangeController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    if (widget.entryId != null) {
      final repo = ref.read(cellarRepositoryProvider);
      final entry = await repo.getEntryByUuid(widget.entryId!);
      if (entry != null) {
        _existingEntry = entry;
        _nameController.text = entry.name;
        _producerController.text = entry.producer ?? '';
        _categoryController.text = entry.category ?? '';
        _tastingNotesController.text = entry.tastingNotes ?? '';
        _abvController.text = entry.abv ?? '';
        _ageVintageController.text = entry.ageVintage ?? '';
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
        appBar: AppBar(title: Text(isEditing ? 'Edit Entry' : 'New Entry')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Entry' : 'New Entry'),
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

            // Producer and Category (side by side)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _producerController,
                    decoration: const InputDecoration(
                      labelText: 'Producer / Origin',
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
                        return _defaultCategories;
                      }
                      return _defaultCategories.where((c) =>
                          c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      if (controller.text != _categoryController.text) {
                        controller.text = _categoryController.text;
                      }
                      controller.addListener(() {
                        if (_categoryController.text != controller.text) {
                          _categoryController.text = controller.text;
                        }
                      });
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        onFieldSubmitted: (_) => onFieldSubmitted(),
                      );
                    },
                    onSelected: (selection) {
                      _categoryController.text = selection;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ABV and Age/Vintage (side by side, optional)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _abvController,
                    decoration: const InputDecoration(
                      labelText: 'ABV',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _ageVintageController,
                    decoration: const InputDecoration(
                      labelText: 'Age / Vintage',
                      border: OutlineInputBorder(),
                    ),
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

            // Tasting notes
            TextFormField(
              controller: _tastingNotesController,
              decoration: const InputDecoration(
                labelText: 'Tasting Notes',
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
      final imagesDir = Directory('${appDir.path}/cellar_images');
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

    final entry = _existingEntry ?? CellarEntry();
    entry
      ..uuid = _existingEntry?.uuid ?? const Uuid().v4()
      ..name = _nameController.text.trim()
      ..producer = _producerController.text.trim().isEmpty ? null : _producerController.text.trim()
      ..category = _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim()
      ..buy = _buy
      ..tastingNotes = _tastingNotesController.text.trim().isEmpty ? null : _tastingNotesController.text.trim()
      ..abv = _abvController.text.trim().isEmpty ? null : _abvController.text.trim()
      ..ageVintage = _ageVintageController.text.trim().isEmpty ? null : _ageVintageController.text.trim()
      ..priceRange = _priceRangeController.text.trim().isEmpty ? null : _priceRangeController.text.trim()
      ..imageUrl = _imagePath
      ..source = _existingEntry?.source ?? CellarSource.personal
      ..updatedAt = DateTime.now();

    if (_existingEntry == null) {
      entry.createdAt = DateTime.now();
    }

    final repo = ref.read(cellarRepositoryProvider);
    await repo.saveEntry(entry);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${entry.name} saved!')),
      );
      Navigator.of(context).pop();
    }
  }
}
