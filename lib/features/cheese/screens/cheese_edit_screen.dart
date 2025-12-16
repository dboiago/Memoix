import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../recipes/models/cuisine.dart';
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
  final _milkController = TextEditingController();
  final _textureController = TextEditingController();
  final _typeController = TextEditingController();
  final _flavourController = TextEditingController();

  String? _selectedCountry; // Uses same selection pattern as Cuisine
  bool _buy = false;
  int _priceRange = 0; // 0 = unset, 1-5 = tier
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

  // Cheese textures as per requirements (selectable suggestions, custom allowed)
  static const List<String> _defaultTextures = [
    'Fresh',
    'Aged Fresh',
    'Bloomy Rind',
    'Washed Rind',
    'Semi-Soft',
    'Semi-Hard',
    'Hard',
    'Blue',
  ];

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _milkController.dispose();
    _textureController.dispose();
    _typeController.dispose();
    _flavourController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    if (widget.entryId != null) {
      final repo = ref.read(cheeseRepositoryProvider);
      final entry = await repo.getEntryByUuid(widget.entryId!);
      if (entry != null) {
        _existingEntry = entry;
        _nameController.text = entry.name;
        _selectedCountry = entry.country;
        _milkController.text = entry.milk ?? '';
        _textureController.text = entry.texture ?? '';
        _typeController.text = entry.type ?? '';
        _flavourController.text = entry.flavour ?? '';
        _priceRange = entry.priceRange ?? 0;
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
          TextButton.icon(
            onPressed: _saveEntry,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
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

            // Country selector (uses same pattern as Cuisine)
            _CountrySelector(
              selectedCountry: _selectedCountry,
              onChanged: (country) => setState(() => _selectedCountry = country),
            ),
            const SizedBox(height: 16),

            // Milk (autocomplete with suggestions)
            Autocomplete<String>(
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

            // Buy toggle (compact, not full-width)
            Row(
              children: [
                Text('Buy', style: theme.textTheme.bodyLarge),
                const SizedBox(width: 8),
                Switch.adaptive(
                  value: _buy,
                  onChanged: (value) => setState(() => _buy = value),
                ),
              ],
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

            // Price range (5-tier rating)
            _PriceRangeSelector(
              value: _priceRange,
              onChanged: (value) => setState(() => _priceRange = value),
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
      ..country = _selectedCountry
      ..milk = _milkController.text.trim().isEmpty ? null : _milkController.text.trim()
      ..texture = _textureController.text.trim().isEmpty ? null : _textureController.text.trim()
      ..type = _typeController.text.trim().isEmpty ? null : _typeController.text.trim()
      ..buy = _buy
      ..flavour = _flavourController.text.trim().isEmpty ? null : _flavourController.text.trim()
      ..priceRange = _priceRange > 0 ? _priceRange : null
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

/// Country selector using same pattern as Cuisine selector in recipe edit
class _CountrySelector extends StatelessWidget {
  final String? selectedCountry;
  final ValueChanged<String?> onChanged;

  const _CountrySelector({
    required this.selectedCountry,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cuisine = selectedCountry != null ? Cuisine.byCode(selectedCountry!) : null;
    
    return InkWell(
      onTap: () => _showCountrySheet(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Country',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          cuisine != null
              ? '${cuisine.flag} ${cuisine.name}'
              : selectedCountry ?? 'Select country (optional)',
          style: TextStyle(
            color: selectedCountry != null
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _showCountrySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CountryPickerSheet(
        selectedCountry: selectedCountry,
        onChanged: (code) {
          onChanged(code);
          Navigator.pop(ctx);
        },
        onClear: () {
          onChanged(null);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

/// Bottom sheet with searchable country list grouped by continent
class _CountryPickerSheet extends StatefulWidget {
  final String? selectedCountry;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _CountryPickerSheet({
    required this.selectedCountry,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Cuisine> get _filteredCuisines {
    if (_searchQuery.isEmpty) return [];
    final query = _searchQuery.toLowerCase();
    return Cuisine.all.where((c) => 
      c.name.toLowerCase().contains(query) ||
      c.continent.toLowerCase().contains(query) ||
      c.code.toLowerCase().contains(query),
    ).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Select Country',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onClear,
                  child: const Text('Clear'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search countries...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _searchQuery.isNotEmpty
                ? _buildSearchResults(controller)
                : _buildGroupedList(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ScrollController controller) {
    final results = _filteredCuisines;
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No countries found for "$_searchQuery"',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      controller: controller,
      itemCount: results.length,
      itemBuilder: (context, index) {
        final cuisine = results[index];
        final isSelected = widget.selectedCountry == cuisine.code;
        return ListTile(
          leading: Text(cuisine.flag, style: const TextStyle(fontSize: 24)),
          title: Text(cuisine.name),
          subtitle: Text(cuisine.continent, 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          trailing: isSelected
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
          selected: isSelected,
          onTap: () => widget.onChanged(cuisine.code),
        );
      },
    );
  }

  Widget _buildGroupedList(ScrollController controller) {
    return ListView(
      controller: controller,
      children: CuisineGroup.all.map((group) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                group.continent,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 14,
                ),
              ),
            ),
            ...group.cuisines.map((cuisine) {
              final isSelected = widget.selectedCountry == cuisine.code;
              return ListTile(
                leading: Text(cuisine.flag, style: const TextStyle(fontSize: 24)),
                title: Text(cuisine.name),
                trailing: isSelected
                    ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                    : null,
                selected: isSelected,
                onTap: () => widget.onChanged(cuisine.code),
              );
            }),
          ],
        );
      }).toList(),
    );
  }
}

/// 5-tier price range selector displayed as dollar signs
class _PriceRangeSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _PriceRangeSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Range',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ...List.generate(5, (index) {
              final tier = index + 1;
              final isSelected = value >= tier;
              return GestureDetector(
                onTap: () => onChanged(value == tier ? 0 : tier),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '\$',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isSelected 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.outline.withOpacity(0.4),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 16),
            if (value > 0)
              TextButton(
                onPressed: () => onChanged(0),
                child: const Text('Clear'),
              ),
          ],
        ),
      ],
    );
  }
}
