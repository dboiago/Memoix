import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/recipe.dart';
import '../repository/recipe_repository.dart';

class RecipeEditScreen extends ConsumerStatefulWidget {
  final Recipe? initialRecipe;
  final String? rawOcrText;

  const RecipeEditScreen({
    super.key,
    this.initialRecipe,
    this.rawOcrText,
  });

  @override
  ConsumerState<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends ConsumerState<RecipeEditScreen> {
  static const _uuid = Uuid();

  late final TextEditingController _nameController;
  late final TextEditingController _cuisineController;
  late final TextEditingController _servesController;
  late final TextEditingController _timeController;
  late final TextEditingController _notesController;
  late final TextEditingController _ingredientsController;
  late final TextEditingController _directionsController;

  String _selectedCourse = 'Mains';
  bool _isSaving = false;

  bool get _isEditing => widget.initialRecipe?.id != null && widget.initialRecipe!.id > 0;

  @override
  void initState() {
    super.initState();

    final recipe = widget.initialRecipe;

    _nameController = TextEditingController(text: recipe?.name ?? '');
    _cuisineController = TextEditingController(text: recipe?.cuisine ?? '');
    _servesController = TextEditingController(text: recipe?.serves ?? '');
    _timeController = TextEditingController(text: recipe?.time ?? '');
    _notesController = TextEditingController(text: recipe?.notes ?? '');

    // Convert ingredients to editable text
    _ingredientsController = TextEditingController(
      text: recipe?.ingredients.map((i) => i.displayText).join('\n') ?? '',
    );

    // Convert directions to editable text
    _directionsController = TextEditingController(
      text: recipe?.directions.join('\n\n') ?? '',
    );

    if (recipe != null) {
      _selectedCourse = recipe.course;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cuisineController.dispose();
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Recipe' : 'New Recipe'),
        actions: [
          if (widget.rawOcrText != null)
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
                DropdownMenuItem(value: 'Apps', child: Text('Apps')),
                DropdownMenuItem(value: 'Mains', child: Text('Mains')),
                DropdownMenuItem(value: 'Not Meat', child: Text('Not Meat')),
                DropdownMenuItem(value: 'Soups', child: Text('Soups')),
                DropdownMenuItem(value: 'Brunch', child: Text('Brunch')),
                DropdownMenuItem(value: 'Sides', child: Text('Sides')),
                DropdownMenuItem(value: 'Desserts', child: Text('Desserts')),
                DropdownMenuItem(value: 'Breads', child: Text('Breads')),
                DropdownMenuItem(value: 'Rubs', child: Text('Rubs')),
                DropdownMenuItem(value: 'Sauces', child: Text('Sauces')),
                DropdownMenuItem(value: 'Pickles', child: Text('Pickles/Brines')),
                DropdownMenuItem(value: 'Molecular', child: Text('Molecular')),
                DropdownMenuItem(value: 'Pizzas', child: Text('Pizzas')),
                DropdownMenuItem(value: 'Smoking', child: Text('Smoking')),
                DropdownMenuItem(value: 'Cheese', child: Text('Cheese')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCourse = value);
                }
              },
            ),

            const SizedBox(height: 16),

            // Cuisine and metadata row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cuisineController,
                    decoration: const InputDecoration(
                      labelText: 'Cuisine',
                      hintText: 'e.g., Korean',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
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
      final recipe = widget.initialRecipe ?? Recipe();
      
      recipe
        ..uuid = recipe.uuid.isEmpty ? _uuid.v4() : recipe.uuid
        ..name = _nameController.text.trim()
        ..course = _selectedCourse.toLowerCase()
        ..cuisine = _cuisineController.text.trim().isEmpty 
            ? null 
            : _cuisineController.text.trim()
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
        ..source = widget.initialRecipe?.source ?? RecipeSource.personal
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
                    widget.rawOcrText ?? '',
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
