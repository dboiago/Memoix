import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/recipe.dart';
import '../models/cuisine.dart';
import '../repository/recipe_repository.dart';

class RecipeEditScreen extends ConsumerStatefulWidget {
  final String? recipeId;
  final Recipe? initialRecipe;
  final Recipe? importedRecipe;
  final String? ocrText;
  final String? defaultCourse;

  const RecipeEditScreen({
    super.key,
    this.recipeId,
    this.initialRecipe,
    this.importedRecipe,
    this.ocrText,
    this.defaultCourse,
  });

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  static const _uuid = Uuid();

  late final TextEditingController _nameController;
  late final TextEditingController _servesController;
  late final TextEditingController _timeController;
  late final TextEditingController _notesController;
  late final TextEditingController _ingredientsController;
  late final TextEditingController _directionsController;

  String _selectedCourse = 'mains';
  String? _selectedCuisine;
  bool _isSaving = false;
  bool _isLoading = true;
  Recipe? _existingRecipe;

  bool get _isEditing => _existingRecipe != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _servesController = TextEditingController();
    _timeController = TextEditingController();
    _notesController = TextEditingController();
    _ingredientsController = TextEditingController();
    _directionsController = TextEditingController();

    if (widget.defaultCourse != null) {
      _selectedCourse = widget.defaultCourse!;
    }

    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    Recipe? recipe;

    if (widget.initialRecipe != null) {
      recipe = widget.initialRecipe;
    } else if (widget.importedRecipe != null) {
      recipe = widget.importedRecipe;
    } else if (widget.recipeId != null) {
      final repo = ref.read(recipeRepositoryProvider);
      recipe = await repo.getRecipeByUuid(widget.recipeId!);
    }

    if (recipe != null) {
      _existingRecipe = recipe;
      _nameController.text = recipe.name;
      _servesController.text = recipe.serves ?? '';
      _timeController.text = recipe.time ?? '';
      _notesController.text = recipe.notes ?? '';
      // Normalize course to slug form (lowercase) to match dropdown values
      _selectedCourse = recipe.course?.toLowerCase() ?? _selectedCourse;
      _selectedCuisine = recipe.cuisine;

      // Convert ingredients to editable text
      _ingredientsController.text = recipe.ingredients
          .map((i) => i.displayText)
          .join('\n');

      // Convert directions to editable text
      _directionsController.text = recipe.directions.join('\n\n');
    } else if (widget.ocrText != null) {
      // Pre-populate with OCR text for manual extraction
      _notesController.text = 'OCR Text:\n${widget.ocrText}';
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servesController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    _ingredientsController.dispose();
    _directionsController.dispose();
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
          if (widget.ocrText != null)
            IconButton(
              icon: const Icon(Icons.text_snippet),
              tooltip: 'View OCR Text',
              onPressed: () => _showOcrText(context),
            ),
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
            // Recipe name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Recipe Name *',
                hintText: 'e.g., Korean Fried Chicken',
              ),
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            // Course dropdown
            DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: const InputDecoration(
                labelText: 'Category *',
              ),
              items: const [
                DropdownMenuItem(value: 'apps', child: Text('Apps')),
                DropdownMenuItem(value: 'mains', child: Text('Mains')),
                DropdownMenuItem(value: 'not-meat', child: Text('Not Meat')),
                DropdownMenuItem(value: 'soups', child: Text('Soups')),
                DropdownMenuItem(value: 'brunch', child: Text('Brunch')),
                DropdownMenuItem(value: 'sides', child: Text('Sides')),
                DropdownMenuItem(value: 'desserts', child: Text('Desserts')),
                DropdownMenuItem(value: 'breads', child: Text('Breads')),
                DropdownMenuItem(value: 'rubs', child: Text('Rubs')),
                DropdownMenuItem(value: 'sauces', child: Text('Sauces')),
                DropdownMenuItem(value: 'pickles', child: Text('Pickles/Brines')),
                DropdownMenuItem(value: 'molecular', child: Text('Molecular')),
                DropdownMenuItem(value: 'pizzas', child: Text('Pizzas')),
                DropdownMenuItem(value: 'smoking', child: Text('Smoking')),
                DropdownMenuItem(value: 'cheese', child: Text('Cheese')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCourse = value);
                }
              },
            ),

            const SizedBox(height: 16),

            // Cuisine selector
            _CuisineSelector(
              selectedCuisine: _selectedCuisine,
              onChanged: (cuisine) => setState(() => _selectedCuisine = cuisine),
            ),

            const SizedBox(height: 16),

            // Serves and Time row
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

            // Ingredients
            Text(
              'Ingredients',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'One ingredient per line',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ingredientsController,
              decoration: const InputDecoration(
                hintText: '1 can white beans\n2 tbsp butter\n1 onion, diced\n...',
                alignLabelWithHint: true,
              ),
              maxLines: 10,
              minLines: 5,
            ),

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
              'Separate steps with blank lines',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _directionsController,
              decoration: const InputDecoration(
                hintText: 'Melt butter in a large pot...\n\nAdd onions and sauté...\n\n...',
                alignLabelWithHint: true,
              ),
              maxLines: 15,
              minLines: 8,
            ),

            const SizedBox(height: 24),

            // Notes
            Text(
              'Notes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                hintText: 'Optional tips, variations, etc.',
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

  Future<void> _saveRecipe() async {
    // Validate
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipe name')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Parse ingredients from text
      final ingredients = _ingredientsController.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map((line) => Ingredient.create(name: line))
          .toList();

      // Parse directions from text
      final directions = _directionsController.text
          .split(RegExp(r'\n\s*\n'))
          .map((step) => step.trim())
          .where((step) => step.isNotEmpty)
          .toList();

      // Create or update recipe
      final recipe = _existingRecipe ?? Recipe();
      
      recipe
        ..uuid = recipe.uuid.isEmpty ? _uuid.v4() : recipe.uuid
        ..name = _nameController.text.trim()
        ..course = _selectedCourse
        ..cuisine = _selectedCuisine
        ..serves = _servesController.text.trim().isEmpty 
            ? null 
            : _servesController.text.trim()
        ..time = _timeController.text.trim().isEmpty 
            ? null 
            : _timeController.text.trim()
        ..notes = _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim()
        ..ingredients = ingredients
        ..directions = directions
        ..source = _existingRecipe?.source ?? 
            (widget.importedRecipe != null ? RecipeSource.imported : 
             widget.ocrText != null ? RecipeSource.ocr : RecipeSource.personal)
        ..updatedAt = DateTime.now();

      // Save to database
      final repository = ref.read(recipeRepositoryProvider);
      await repository.saveRecipe(recipe);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${recipe.name} saved!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving recipe: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showOcrText(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Scanned Text',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: SelectableText(
                    widget.ocrText ?? '',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cuisine selector dropdown with grouped cuisines by continent
class _CuisineSelector extends StatelessWidget {
  final String? selectedCuisine;
  final ValueChanged<String?> onChanged;

  const _CuisineSelector({
    required this.selectedCuisine,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showCuisineSheet(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Cuisine',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedCuisine != null
              ? '${Cuisine.byCode(selectedCuisine!)?.flag ?? ''} ${Cuisine.byCode(selectedCuisine!)?.name ?? selectedCuisine}'
              : 'Select cuisine (optional)',
          style: TextStyle(
            color: selectedCuisine != null
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _showCuisineSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Select Cuisine',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      onChanged(null);
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
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
                        final isSelected = selectedCuisine == cuisine.code;
                        return ListTile(
                          leading: Text(
                            cuisine.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(cuisine.name),
                          trailing: isSelected
                              ? Icon(Icons.check,
                                  color: Theme.of(context).colorScheme.primary)
                              : null,
                          selected: isSelected,
                          onTap: () {
                            onChanged(cuisine.code);
                            Navigator.pop(ctx);
                          },
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
