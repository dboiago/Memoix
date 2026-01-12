import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../core/widgets/memoix_snackbar.dart';
import '../../recipes/models/course.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/models/cuisine.dart';
import '../../recipes/models/spirit.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_edit_screen.dart'; // For converting to recipe
import '../models/scratch_pad.dart';
import '../repository/scratch_pad_repository.dart';

/// Converts text fractions and decimals to unicode fraction symbols
String _normalizeFractions(String input) {
  var result = input;
  const fractionMap = {
    '1/2': '½', '1/3': '⅓', '2/3': '⅔', '1/4': '¼', '3/4': '¾',
    '1/5': '⅕', '2/5': '⅖', '3/5': '⅗', '4/5': '⅘', '1/6': '⅙',
    '5/6': '⅚', '1/8': '⅛', '3/8': '⅜', '5/8': '⅝', '7/8': '⅞',
  };
  const decimalMap = {
    '0.5': '½', '.5': '½', '0.25': '¼', '.25': '¼', '0.75': '¾', '.75': '¾',
    '0.33': '⅓', '.33': '⅓', '0.67': '⅔', '.67': '⅔',
  };
  for (final entry in fractionMap.entries) {
    final pattern = entry.key.replaceAll('/', r'\s*/\s*');
    result = result.replaceAll(RegExp(pattern), entry.value);
  }
  for (final entry in decimalMap.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}

class DraftEditorScreen extends ConsumerStatefulWidget {
  final RecipeDraft? initialDraft;

  const DraftEditorScreen({
    super.key,
    this.initialDraft,
  });

  @override
  ConsumerState<DraftEditorScreen> createState() => _DraftEditorScreenState();
}

class _DraftEditorScreenState extends ConsumerState<DraftEditorScreen> {
  static const _uuid = Uuid();

  late final TextEditingController _nameController;
  late final TextEditingController _servesController;
  late final TextEditingController _timeController;
  late final TextEditingController _notesController; // Maps to draft.notes (Comments in UI)
  late final TextEditingController _regionController;

  // 3-column ingredient editing: list of (name, amount, notes) controllers
  final List<_IngredientRow> _ingredientRows = [];
  
  // Direction rows for individual step editing with images
  final List<_DirectionRow> _directionRows = [];
  final List<String> _stepImages = [];
  final Map<int, int> _stepImageMap = {}; 

  String _selectedCourse = 'mains';
  String? _selectedCuisine;
  String? _headerImage;
  bool _isSaving = false;
  bool _isLoading = true;
  RecipeDraft? _existingDraft;
  
  // Paired recipe IDs
  final List<String> _pairedRecipeIds = [];

  bool get _isEditing => _existingDraft != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController();
    _servesController = TextEditingController();
    _timeController = TextEditingController();
    _notesController = TextEditingController();
    _regionController = TextEditingController();

    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final draft = widget.initialDraft;

    if (draft != null) {
      _existingDraft = draft;
      _nameController.text = draft.name;
      _servesController.text = draft.serves ?? '';
      _timeController.text = draft.time ?? '';
      _notesController.text = draft.notes;
      
      // Course normalization
      _selectedCourse = _normaliseCourseSlug(draft.course != null && (draft.course as String).isNotEmpty 
          ? draft.course as String 
          : 'mains');

      // Load Ingredients
      for (final ingredient in draft.structuredIngredients) {
        // Construct display amount: "1" + "cup" -> "1 cup"
        String amountText = '';
        if (ingredient.quantity != null && ingredient.quantity!.isNotEmpty) {
          amountText = ingredient.quantity!;
          if (ingredient.unit != null && ingredient.unit!.isNotEmpty) {
            amountText += ' ${ingredient.unit}';
          }
        }
        
        // Detect if this was saved as a section (convention: preparation == '__SECTION__')
        final isSection = ingredient.preparation == '__SECTION__';
        String notes = ingredient.preparation ?? '';
        if (isSection) notes = '';

        _addIngredientRow(
          name: ingredient.name,
          amount: amountText,
          notes: notes,
          isSection: isSection,
        );
      }

      // Load Directions
      for (final direction in draft.structuredDirections) {
        _addDirectionRow(text: direction);
      }
      
      // Load Images
      _stepImages.addAll(draft.stepImages);
      for (final mapping in draft.stepImageMap) {
        final parts = mapping.split(':');
        if (parts.length == 2) {
          final stepIndex = int.tryParse(parts[0]);
          final imageIndex = int.tryParse(parts[1]);
          if (stepIndex != null && imageIndex != null) {
            _stepImageMap[stepIndex] = imageIndex;
          }
        }
      }
      
      _headerImage = draft.imagePath;
      _pairedRecipeIds.addAll(draft.pairedRecipeIds);
    }

    // Always have at least one empty row
    if (_ingredientRows.isEmpty) _addIngredientRow();
    if (_directionRows.isEmpty) _addDirectionRow();

    setState(() => _isLoading = false);
  }

  String _normaliseCourseSlug(String course) {
    final lower = course.toLowerCase();
    const validSlugs = {
      'apps', 'soup', 'mains', 'vegn', 'sides', 'salad', 'desserts', 
      'brunch', 'drinks', 'breads', 'sauces', 'rubs', 'pickles', 
      'modernist', 'pizzas', 'sandwiches', 'smoking', 'cheese', 'scratch'
    };
    return validSlugs.contains(lower) ? lower : 'mains';
  }

  void _addIngredientRow({String name = '', String amount = '', String notes = '', bool isSection = false}) {
    _ingredientRows.add(_IngredientRow(
      nameController: TextEditingController(text: name),
      amountController: TextEditingController(text: amount),
      notesController: TextEditingController(text: notes),
      isSection: isSection,
    ));
  }

  void _addDirectionRow({String text = ''}) {
    _directionRows.add(_DirectionRow(
      controller: TextEditingController(text: text),
    ));
  }

  void _removeIngredientRow(int index) {
    if (_ingredientRows.length > 1) {
      final row = _ingredientRows.removeAt(index);
      row.dispose();
      setState(() {});
    }
  }

  void _removeDirectionRow(int index) {
    if (_directionRows.length > 1) {
      _stepImageMap.remove(index);
      final newMap = <int, int>{};
      for (final entry in _stepImageMap.entries) {
        if (entry.key > index) newMap[entry.key - 1] = entry.value;
        else newMap[entry.key] = entry.value;
      }
      _stepImageMap.clear();
      _stepImageMap.addAll(newMap);
      
      final row = _directionRows.removeAt(index);
      row.dispose();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servesController.dispose();
    _timeController.dispose();
    _notesController.dispose();
    _regionController.dispose();
    for (final row in _ingredientRows) row.dispose();
    for (final row in _directionRows) row.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    if (_nameController.text.trim().isEmpty) {
      MemoixSnackBar.showError('Please enter a recipe name');
      return;
    }
    setState(() => _isSaving = true);

    try {
      final ingredients = <DraftIngredient>[];
      
      for (final row in _ingredientRows) {
        final name = row.nameController.text.trim();
        if (name.isEmpty) continue;

        // Parse amount/unit
        String? qty;
        String? unit;
        final amountText = row.amountController.text.trim();
        if (amountText.isNotEmpty) {
          final normalized = _normalizeFractions(amountText);
          final parts = normalized.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            qty = parts.first;
            unit = parts.sublist(1).join(' ');
          } else {
            qty = normalized;
          }
        }

        // Store section marker in preparation if needed
        final prep = row.isSection 
            ? '__SECTION__' 
            : (row.notesController.text.trim().isEmpty ? null : row.notesController.text.trim());

        ingredients.add(DraftIngredient(
          name: name,
          quantity: qty,
          unit: unit,
          preparation: prep,
        ));
      }

      final directions = _directionRows
          .map((row) => row.controller.text.trim())
          .where((step) => step.isNotEmpty)
          .toList();

      final draft = _existingDraft ?? RecipeDraft();
      draft
        ..uuid = draft.uuid.isNotEmpty ? draft.uuid : _uuid.v4()
        ..name = _nameController.text.trim()
        ..course = _selectedCourse
        ..serves = _servesController.text.trim().isEmpty ? null : _servesController.text.trim()
        ..time = _timeController.text.trim().isEmpty ? null : _timeController.text.trim()
        ..notes = _notesController.text.trim()
        ..structuredIngredients = ingredients
        ..structuredDirections = directions
        ..imagePath = _headerImage
        ..stepImages = List<String>.from(_stepImages)
        ..stepImageMap = _stepImageMap.entries.map((e) => '${e.key}:${e.value}').toList()
        ..pairedRecipeIds = List<String>.from(_pairedRecipeIds)
        ..updatedAt = DateTime.now();

      await ref.read(scratchPadRepositoryProvider).updateDraft(draft);

      if (mounted) {
        Navigator.pop(context);
        MemoixSnackBar.showSaved(itemName: draft.name, actionLabel: 'View', onView: () {});
      }
    } catch (e) {
      MemoixSnackBar.showError('Error saving draft: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _convertToRecipe() async {
    await _saveDraft();
    
    // Build Recipe object for conversion
    final ingredients = <Ingredient>[];
    String? currentSection;
    
    for (final row in _ingredientRows) {
      if (row.nameController.text.trim().isEmpty) continue;
      
      if (row.isSection) {
        currentSection = row.nameController.text.trim();
        // Sections in Recipe are headers on the following ingredients, not standalone items
        // but to ensure the header is captured if there are no ingredients under it yet:
        continue;
      }
      
      String? amount;
      String? unit;
      final amountText = row.amountController.text.trim();
      if (amountText.isNotEmpty) {
          final parts = amountText.split(' ');
          if (parts.length >= 2) {
             amount = parts[0];
             unit = parts.sublist(1).join(' ');
          } else {
             amount = amountText;
          }
      }

      ingredients.add(Ingredient()
        ..name = row.nameController.text.trim()
        ..amount = amount
        ..unit = unit
        ..preparation = row.notesController.text.trim().isEmpty ? null : row.notesController.text.trim()
        ..section = currentSection
      );
    }

    final directions = _directionRows
        .map((row) => row.controller.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final recipe = Recipe.create(
        uuid: _uuid.v4(),
        name: _nameController.text.trim(),
        course: _selectedCourse,
        ingredients: ingredients,
        directions: directions,
        comments: _notesController.text.trim(),
        imageUrl: _headerImage,
    );
    // Copy images and pairs
    recipe.stepImages = List.from(_stepImages);
    recipe.stepImageMap = _stepImageMap.entries.map((e) => '${e.key}:${e.value}').toList();
    recipe.pairedRecipeIds = List.from(_pairedRecipeIds);

    if (mounted) {
        Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RecipeEditScreen(importedRecipe: recipe)),
        );
    }
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
        title: Text(_isEditing ? 'Edit Draft' : 'New Draft'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveDraft,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            label: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImagePicker(theme),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Recipe Name *', hintText: 'e.g., Sourdough Experiment'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: const InputDecoration(labelText: 'Course *'),
              items: const [
                DropdownMenuItem(value: 'apps', child: Text('Apps')),
                DropdownMenuItem(value: 'soup', child: Text('Soup')),
                DropdownMenuItem(value: 'mains', child: Text('Mains')),
                DropdownMenuItem(value: 'vegn', child: Text("Veg'n")),
                DropdownMenuItem(value: 'sides', child: Text('Sides')),
                DropdownMenuItem(value: 'salad', child: Text('Salad')),
                DropdownMenuItem(value: 'desserts', child: Text('Desserts')),
                DropdownMenuItem(value: 'brunch', child: Text('Brunch')),
                DropdownMenuItem(value: 'drinks', child: Text('Drinks')),
                DropdownMenuItem(value: 'breads', child: Text('Breads')),
                DropdownMenuItem(value: 'sauces', child: Text('Sauces')),
                DropdownMenuItem(value: 'rubs', child: Text('Rubs')),
                DropdownMenuItem(value: 'pickles', child: Text('Pickles')),
                DropdownMenuItem(value: 'pizzas', child: Text('Pizzas')),
                DropdownMenuItem(value: 'sandwiches', child: Text('Sandwiches')),
                DropdownMenuItem(value: 'scratch', child: Text('Scratch')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedCourse = value);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _servesController, decoration: const InputDecoration(labelText: 'Serves', hintText: 'e.g., 4-6'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _timeController, decoration: const InputDecoration(labelText: 'Time', hintText: 'e.g., 40 min'))),
              ],
            ),
            const SizedBox(height: 16),
            _buildPairsWithSection(theme),
            const SizedBox(height: 24),
            
            // INGREDIENTS
            Row(
              children: [
                Text('Ingredients', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                     _addIngredientRow(isSection: true);
                     _addIngredientRow(); // Add empty row after section
                     setState((){});
                  },
                  icon: const Icon(Icons.title, size: 18),
                  label: const Text('Section'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
              child: Row(
                children: [
                  const SizedBox(width: 32),
                  Expanded(flex: 3, child: Text('Ingredient', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  SizedBox(width: 80, child: Text('Amount', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: Text('Notes/Prep', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold))),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _ingredientRows.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _ingredientRows.removeAt(oldIndex);
                    _ingredientRows.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  return _buildIngredientRowWidget(index, key: ValueKey(_ingredientRows[index]));
                },
              ),
            ),
            
            const SizedBox(height: 24),

            // DIRECTIONS
            Text('Directions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _directionRows.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final row = _directionRows.removeAt(oldIndex);
                  _directionRows.insert(newIndex, row);
                  // Fix images
                  final newMap = <int, int>{};
                  for (final entry in _stepImageMap.entries) {
                    int newKey = entry.key;
                    if (entry.key == oldIndex) newKey = newIndex;
                    else if (entry.key > oldIndex && entry.key <= newIndex) newKey = entry.key - 1;
                    else if (entry.key < oldIndex && entry.key >= newIndex) newKey = entry.key + 1;
                    newMap[newKey] = entry.value;
                  }
                  _stepImageMap.clear();
                  _stepImageMap.addAll(newMap);
                });
              },
              itemBuilder: (context, index) {
                return _buildDirectionRowWidget(index, theme, key: ValueKey(_directionRows[index]));
              },
            ),

            const SizedBox(height: 24),
            Text('Comments', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(hintText: 'Optional tips, variations, etc.'),
              maxLines: 4, minLines: 2,
            ),
            const SizedBox(height: 24),
            _buildStepImagesGallery(theme),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Convert to Recipe'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _convertToRecipe,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // --- Pairs With UI ---
  Widget _buildPairsWithSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pairs With', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_pairedRecipeIds.isNotEmpty)
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _pairedRecipeIds.map((uuid) {
              final allRecipes = ref.watch(allRecipesProvider).valueOrNull ?? [];
              final recipe = allRecipes.where((r) => r.uuid == uuid).firstOrNull;
              return Chip(
                label: Text(recipe?.name ?? 'Unknown'),
                onDeleted: () => setState(() => _pairedRecipeIds.remove(uuid)),
              );
            }).toList(),
          ),
        if (_pairedRecipeIds.length < 3) ...[
          if (_pairedRecipeIds.isNotEmpty) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showRecipeSelector,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Recipe'),
            style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ],
      ],
    );
  }

  void _showRecipeSelector() {
    final allRecipes = ref.read(allRecipesProvider).valueOrNull ?? [];
    final available = allRecipes.where((r) => !_pairedRecipeIds.contains(r.uuid)).toList();
    available.sort((a,b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    showDialog(context: context, builder: (ctx) => AlertDialog(
       title: const Text('Select Recipe'),
       content: SizedBox(
         width: double.maxFinite, height: 300,
         child: ListView.builder(
            itemCount: available.length,
            itemBuilder: (ctx, i) => ListTile(
               title: Text(available[i].name), 
               onTap: (){ setState(()=>_pairedRecipeIds.add(available[i].uuid)); Navigator.pop(ctx); }
            ),
         ),
       ),
    ));
  }

  // --- Widgets: Ingredient Row ---
  Widget _buildIngredientRowWidget(int index, {Key? key}) {
    final theme = Theme.of(context);
    final row = _ingredientRows[index];
    final isLast = index == _ingredientRows.length - 1;
    
    if (row.isSection) {
      return Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(color: theme.colorScheme.primaryContainer.withOpacity(0.3)),
        child: Row(
          children: [
            ReorderableDragStartListener(index: index, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_indicator, size: 20, color: theme.colorScheme.outline))),
            Icon(Icons.label_outline, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: TextField(
                controller: row.nameController,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: 'Section name (e.g. Sauce)', filled: true),
                style: const TextStyle(fontWeight: FontWeight.bold),
            )),
            IconButton(icon: const Icon(Icons.close), onPressed: () => _removeIngredientRow(index)),
          ],
        ),
      );
    }
    
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)))),
      child: Row(
        children: [
          ReorderableDragStartListener(index: index, child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.drag_indicator, size: 20, color: theme.colorScheme.outline))),
          Expanded(
            flex: 3,
            child: TextField(
              controller: row.nameController,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(), hintText: 'Ingredient'),
              onChanged: (val) {
                 if (isLast && val.isNotEmpty) setState(() => _addIngredientRow());
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextField(
              controller: row.amountController,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(), hintText: 'Amount'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.notesController,
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(), hintText: 'Notes'),
            ),
          ),
          SizedBox(
            width: 40,
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: theme.colorScheme.outline),
              itemBuilder: (c) => [
                 const PopupMenuItem(value: 'section', child: Text('Convert to section')),
                 const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (v) {
                 if (v=='section') setState(() => row.isSection = true);
                 if (v=='delete') _removeIngredientRow(index);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets: Direction Row ---
  Widget _buildDirectionRowWidget(int index, ThemeData theme, {Key? key}) {
    final row = _directionRows[index];
    final isLast = index == _directionRows.length - 1;
    final hasImage = _stepImageMap.containsKey(index);
    final imageIndex = _stepImageMap[index];
    
    return Container(
       key: key,
       margin: const EdgeInsets.only(bottom: 8),
       padding: const EdgeInsets.all(8),
       decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Column(children: [
               ReorderableDragStartListener(index: index, child: Icon(Icons.drag_handle, size: 20, color: theme.colorScheme.outline)),
               const SizedBox(height: 4),
               Container(width: 24, height: 24, decoration: BoxDecoration(color: theme.colorScheme.secondary.withOpacity(0.15), shape: BoxShape.circle), child: Center(child: Text('${index+1}', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 11)))),
            ]),
            const SizedBox(width: 8),
            Expanded(child: TextField(
               controller: row.controller,
               decoration: InputDecoration(isDense: true, border: const OutlineInputBorder(), hintText: 'Enter step ${index+1}...'),
               maxLines: 3, minLines: 2,
               onChanged: (val) { if(isLast && val.isNotEmpty) setState(()=>_addDirectionRow()); },
            )),
            const SizedBox(width: 8),
            Column(children: [
               IconButton(
                  icon: Icon(hasImage ? Icons.image : Icons.add_photo_alternate_outlined, color: hasImage ? theme.colorScheme.primary : theme.colorScheme.outline, size: 20),
                  onPressed: () => _pickStepImage(index),
               ),
               if (hasImage) IconButton(icon: const Icon(Icons.link_off, size: 16), onPressed: () => setState(()=>_stepImageMap.remove(index))),
               IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _directionRows.length > 1 ? () => _removeDirectionRow(index) : null),
            ]),
         ],
       ),
    );
  }

  // --- Image Logic ---
  Widget _buildImagePicker(ThemeData theme) {
    final hasImage = _headerImage != null && _headerImage!.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
       Text('Recipe Photo', style: theme.textTheme.titleSmall),
       const SizedBox(height: 8),
       GestureDetector(
          onTap: _pickHeaderImage,
          child: Container(
             height: 180,
             decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
             child: hasImage 
                ? ClipRRect(borderRadius: BorderRadius.circular(11), child: _buildHeaderImageWidget())
                : Center(child: Icon(Icons.add_a_photo, size: 40, color: theme.colorScheme.onSurfaceVariant)),
          ),
       ),
    ]);
  }
  
  Widget _buildHeaderImageWidget() {
     if (_headerImage == null) return const SizedBox.shrink();
     if (_headerImage!.startsWith('http')) return Image.network(_headerImage!, fit: BoxFit.cover);
     return Image.file(File(_headerImage!), fit: BoxFit.cover);
  }
  
  void _pickHeaderImage() async {
     final picker = ImagePicker();
     final file = await picker.pickImage(source: ImageSource.gallery);
     if (file != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${const Uuid().v4()}${path.extension(file.path)}';
        final saved = await File(file.path).copy('${appDir.path}/$fileName');
        setState(() => _headerImage = saved.path);
     }
  }

  void _pickStepImage(int index) async {
     final picker = ImagePicker();
     final file = await picker.pickImage(source: ImageSource.gallery);
     if (file != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${const Uuid().v4()}${path.extension(file.path)}';
        final saved = await File(file.path).copy('${appDir.path}/$fileName');
        setState(() {
           _stepImages.add(saved.path);
           _stepImageMap[index] = _stepImages.length - 1;
        });
     }
  }

  Widget _buildStepImagesGallery(ThemeData theme) {
     if (_stepImages.isEmpty) return const SizedBox.shrink();
     return SizedBox(height: 100, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _stepImages.length, itemBuilder: (c, i) => Padding(padding: const EdgeInsets.only(right:8), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_stepImages[i]), width: 100, height: 100, fit: BoxFit.cover)))));
  }
}

class _IngredientRow {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController notesController;
  bool isSection;
  _IngredientRow({required this.nameController, required this.amountController, required this.notesController, this.isSection=false});
  void dispose() { nameController.dispose(); amountController.dispose(); notesController.dispose(); }
}

class _DirectionRow {
  final TextEditingController controller;
  _DirectionRow({required this.controller});
  void dispose() { controller.dispose(); }
}