import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../core/widgets/memoix_snackbar.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
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

  const DraftEditorScreen({Key? key, this.initialDraft}) : super(key: key);

  @override
  ConsumerState<DraftEditorScreen> createState() => _DraftEditorScreenState();
}

class _DraftEditorScreenState extends ConsumerState<DraftEditorScreen> {
  static const _uuid = Uuid();

  late final TextEditingController _nameController;
  late final TextEditingController _servesController;
  late final TextEditingController _timeController;
  late final TextEditingController _commentsController;

  final List<_DraftIngredientRow> _ingredientRows = [];
  final List<_DirectionRow> _directionRows = [];
  final List<String> _stepImages = [];
  final Map<int, int> _stepImageMap = {}; 
  final List<String> _pairedRecipeIds = [];

  String? _headerImage;
  bool _isSaving = false;
  bool _isLoading = true;
  RecipeDraft? _existingDraft;

  String _selectedCourse = 'mains';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _servesController = TextEditingController();
    _timeController = TextEditingController();
    _commentsController = TextEditingController();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    RecipeDraft? draft = widget.initialDraft;
    if (draft != null) {
      _existingDraft = draft;
      _nameController.text = draft.name;
      _servesController.text = draft.serves ?? '';
      _timeController.text = draft.time ?? '';
      _commentsController.text = draft.notes;
      
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
      _pairedRecipeIds.addAll(draft.pairedRecipeIds);
      
      _selectedCourse = (draft.course != null && draft.course!.isNotEmpty)
          ? draft.course!
          : 'mains';

      for (final ingredient in draft.structuredIngredients) {
        String amountText = '';
        if (ingredient.quantity != null && ingredient.quantity!.isNotEmpty) {
          amountText = ingredient.quantity!;
          if (ingredient.unit != null && ingredient.unit!.isNotEmpty) {
            amountText += ' ${ingredient.unit}';
          }
        }

        // Check if this was saved as a section header
        final isSection = ingredient.preparation == '__SECTION__';
        final notes = isSection ? '' : (ingredient.preparation ?? '');

        _ingredientRows.add(_DraftIngredientRow(
          nameController: TextEditingController(text: ingredient.name),
          amountController: TextEditingController(text: amountText),
          prepController: TextEditingController(text: notes),
          isSection: isSection,
        ));
      }

      for (final direction in draft.structuredDirections) {
        _directionRows.add(_DirectionRow(controller: TextEditingController(text: direction)));
      }
      
      _headerImage = draft.imagePath;
    }

    if (_ingredientRows.isEmpty) _addIngredientRow();
    if (_directionRows.isEmpty) _addDirectionRow();

    setState(() => _isLoading = false);
  }

  void _addIngredientRow({bool isSection = false}) {
    _ingredientRows.add(_DraftIngredientRow(
      nameController: TextEditingController(),
      amountController: TextEditingController(),
      prepController: TextEditingController(),
      isSection: isSection,
    ));
  }

  void _addDirectionRow() {
    _directionRows.add(_DirectionRow(controller: TextEditingController()));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servesController.dispose();
    _timeController.dispose();
    _commentsController.dispose();
    for (final row in _ingredientRows) row.dispose();
    for (final row in _directionRows) row.dispose();
    super.dispose();
  }

  /// Saves the current state as a Draft (RecipeDrafts table)
  /// Does NOT delete the draft.
  Future<void> _saveDraft({bool silent = false}) async {
    if (_nameController.text.trim().isEmpty) {
      MemoixSnackBar.showError('Please enter a recipe name');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final draft = _buildDraftFromForm();
      await ref.read(scratchPadRepositoryProvider).updateDraft(draft);
      
      // Update local state to ensure subsequent saves update the same draft
      _existingDraft = draft;

      if (!silent && mounted) {
        Navigator.pop(context);
        MemoixSnackBar.showSaved(itemName: draft.name, actionLabel: 'View', onView: () {});
      }
    } catch (e) {
      MemoixSnackBar.showError('Error saving draft: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  /// Promotes the draft to a full Recipe.
  /// 1. Creates Recipe in DB.
  /// 2. Deletes Draft from DB.
  /// 3. Navigates to Recipe Edit Screen (Edit Mode).
  Future<void> _convertToRecipe() async {
    // 1. Validate
    if (_nameController.text.trim().isEmpty) {
      MemoixSnackBar.showError('Please enter a recipe name');
      return;
    }
    
    // Although we default to 'mains', ensure safety
    if (_selectedCourse.isEmpty) {
      MemoixSnackBar.showError('Please select a course');
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 2. Create Recipe Object from current form data
      final recipeIngredients = <Ingredient>[];
      String? currentSection;

      for (final row in _ingredientRows) {
        final name = row.nameController.text.trim();
        if (name.isEmpty) continue;

        if (row.isSection) {
          currentSection = name;
          continue;
        }

        String? amount;
        String? unit;
        final amountText = row.amountController.text.trim();
        if (amountText.isNotEmpty) {
          final normalized = _normalizeFractions(amountText);
          final parts = normalized.split(RegExp(r'\s+'));
          if (parts.length >= 2) {
            amount = parts.first;
            unit = parts.sublist(1).join(' ');
          } else {
            amount = normalized;
          }
        }

        recipeIngredients.add(Ingredient()
          ..name = name
          ..amount = amount
          ..unit = unit
          ..preparation = row.prepController.text.trim().isEmpty ? null : row.prepController.text.trim()
          ..section = currentSection
        );
      }

      final directions = _directionRows
          .map((row) => row.controller.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // Create new UUID for the promoted recipe
      final newRecipeUuid = _uuid.v4();

      final recipe = Recipe.create(
        uuid: newRecipeUuid,
        name: _nameController.text.trim(),
        course: _selectedCourse,
        ingredients: recipeIngredients,
        directions: directions,
        comments: _commentsController.text.trim(),
        imageUrl: _headerImage,
      );
      
      recipe.serves = _servesController.text.trim().isEmpty ? null : _servesController.text.trim();
      recipe.time = _timeController.text.trim().isEmpty ? null : _timeController.text.trim();
      recipe.stepImages = List.from(_stepImages);
      recipe.stepImageMap = _stepImageMap.entries.map((e) => '${e.key}:${e.value}').toList();
      recipe.pairedRecipeIds = List.from(_pairedRecipeIds);
      recipe.source = RecipeSource.personal;

      // 3. Perform the Transaction: Save Recipe, Delete Draft
      // Save Recipe
      await ref.read(recipeRepositoryProvider).saveRecipe(recipe);
      
      // Delete Draft (if it exists)
      if (_existingDraft != null) {
        await ref.read(scratchPadRepositoryProvider).deleteDraft(_existingDraft!.uuid);
      }

      if (mounted) {
        // 4. Navigate: Replace current screen with Recipe Editor loaded from the new ID
        // pushReplacement ensures the user can't go "back" to the deleted draft
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RecipeEditScreen(recipeId: newRecipeUuid),
          ),
        );
        
        MemoixSnackBar.show('Promoted to $_selectedCourse');
      }
    } catch (e) {
      MemoixSnackBar.showError('Error converting recipe: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  RecipeDraft _buildDraftFromForm() {
    final ingredients = <DraftIngredient>[];
    
    for (final row in _ingredientRows) {
      final name = row.nameController.text.trim();
      // Only skip empty non-section rows. Empty sections are allowed as placeholders.
      if (name.isEmpty && !row.isSection) continue;

      String? qty;
      String? unit;
      final rawAmount = row.amountController.text.trim();
      if (rawAmount.isNotEmpty) {
        final normalized = _normalizeFractions(rawAmount);
        final parts = normalized.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          qty = parts.first;
          unit = parts.sublist(1).join(' ');
        } else {
          qty = normalized;
        }
      }

      // Mark sections using a special string in preparation field for drafts
      final prep = row.isSection 
          ? '__SECTION__' 
          : (row.prepController.text.trim().isEmpty ? null : row.prepController.text.trim());

      ingredients.add(DraftIngredient(
        name: name,
        quantity: qty,
        unit: unit,
        preparation: prep,
      ));
    }

    final directions = _directionRows
        .map((row) => row.controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    final draft = _existingDraft ?? RecipeDraft();
    draft
      ..uuid = draft.uuid.isNotEmpty ? draft.uuid : _uuid.v4()
      ..name = _nameController.text.trim()
      ..serves = _servesController.text.trim().isEmpty ? null : _servesController.text.trim()
      ..time = _timeController.text.trim().isEmpty ? null : _timeController.text.trim()
      ..structuredIngredients = ingredients
      ..structuredDirections = directions
      ..notes = _commentsController.text.trim()
      ..stepImages = List<String>.from(_stepImages)
      ..stepImageMap = _stepImageMap.entries.map((e) => '${e.key}:${e.value}').toList()
      ..pairedRecipeIds = List<String>.from(_pairedRecipeIds)
      ..imagePath = _headerImage
      ..updatedAt = DateTime.now()
      ..course = _selectedCourse;
      
    return draft;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allRecipesAsync = ref.watch(allRecipesProvider);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_existingDraft != null ? 'Edit Draft' : 'New Draft'),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : () => _saveDraft(silent: false),
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
              decoration: const InputDecoration(labelText: 'Recipe Name *'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            
            // Course
            DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: const InputDecoration(labelText: 'Course'),
              items: const [
                DropdownMenuItem(value: 'mains', child: Text('Mains')),
                DropdownMenuItem(value: 'desserts', child: Text('Desserts')),
                DropdownMenuItem(value: 'drinks', child: Text('Drinks')),
                DropdownMenuItem(value: 'sides', child: Text('Sides')),
                DropdownMenuItem(value: 'apps', child: Text('Apps')),
                DropdownMenuItem(value: 'breads', child: Text('Breads')),
                DropdownMenuItem(value: 'pizzas', child: Text('Pizzas')),
                DropdownMenuItem(value: 'sandwiches', child: Text('Sandwiches')),
                DropdownMenuItem(value: 'scratch', child: Text('Scratch')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedCourse = value);
              },
            ),
            const SizedBox(height: 16),

            // Serves / Time
            Row(
              children: [
                Expanded(child: TextField(controller: _servesController, decoration: const InputDecoration(labelText: 'Serves'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: _timeController, decoration: const InputDecoration(labelText: 'Time'))),
              ],
            ),
            
            // Pairs With (Moved to Top)
            const SizedBox(height: 16),
            _buildPairsWithSection(theme, allRecipesAsync),

            const SizedBox(height: 24),

            // Ingredients Header with Section Button
            Row(
              children: [
                Text('Ingredients', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                       _addIngredientRow(isSection: true);
                       _addIngredientRow(); // Add empty row after section
                    });
                  }, 
                  icon: const Icon(Icons.title, size: 18),
                  label: const Text('Section'),
                ),
              ],
            ),
            
            // Column Labels
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
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

            // Ingredients List
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
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

            // Directions
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
                    final item = _directionRows.removeAt(oldIndex);
                    _directionRows.insert(newIndex, item);
                    // Fix Image Maps
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

            // Comments
            Text('Comments', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentsController,
              decoration: const InputDecoration(hintText: 'Optional notes, tips, variations...'),
              maxLines: 4,
              minLines: 2,
            ),

            const SizedBox(height: 24),

            // Gallery
            _buildStepImagesGallery(theme),

            const SizedBox(height: 32),

            // Convert Button
            FilledButton.icon(
              icon: const Icon(Icons.restaurant_menu),
              label: const Text('Convert to Recipe'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _convertToRecipe,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // --- Pairs With UI ---
  Widget _buildPairsWithSection(ThemeData theme, AsyncValue<List<Recipe>> allRecipesAsync) {
    final allRecipes = allRecipesAsync.valueOrNull ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pairs With', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_pairedRecipeIds.isNotEmpty)
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _pairedRecipeIds.map((uuid) {
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
            onPressed: () => _showRecipeSelector(allRecipes),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Recipe'),
          ),
        ],
      ],
    );
  }

  void _showRecipeSelector(List<Recipe> allRecipes) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
       title: const Text('Select Recipe'),
       content: SizedBox(
         width: double.maxFinite, height: 300,
         child: ListView(
            children: allRecipes.where((r) => !_pairedRecipeIds.contains(r.uuid)).map((r) => 
               ListTile(title: Text(r.name), onTap: () {
                  setState(() => _pairedRecipeIds.add(r.uuid));
                  Navigator.pop(ctx);
               })
            ).toList(),
         ),
       ),
    ));
  }

  // --- Row Widgets ---

  Widget _buildIngredientRowWidget(int index, {Key? key}) {
    final row = _ingredientRows[index];
    final theme = Theme.of(context);
    final isLast = index == _ingredientRows.length - 1;

    // Section Header Style
    if (row.isSection) {
       return Container(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
             color: theme.colorScheme.primaryContainer.withOpacity(0.3),
             border: isLast ? null : Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
          ),
          child: Row(
             children: [
                ReorderableDragStartListener(index: index, child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.drag_indicator, color: Colors.grey))),
                Icon(Icons.label_outline, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                   child: TextField(
                      controller: row.nameController,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                         hintText: 'Section Name (e.g. For the Sauce)',
                         isDense: true,
                         border: const OutlineInputBorder(),
                         fillColor: theme.colorScheme.surface,
                         filled: true,
                      ),
                   ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _ingredientRows.removeAt(index))),
             ],
          ),
       );
    }

    // Standard Ingredient Row
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ReorderableDragStartListener(index: index, child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.drag_indicator, size: 20, color: Colors.grey))),
          
          Expanded(
            flex: 3,
            child: TextField(
              controller: row.nameController,
              decoration: const InputDecoration(hintText: 'Ingredient', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
              onChanged: (val) {
                 // Auto add new row if typing in last row
                 if (isLast && val.isNotEmpty && !row.isSection) {
                    setState(() => _addIngredientRow());
                 }
              },
            ),
          ),
          
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextField(
              controller: row.amountController,
              decoration: const InputDecoration(hintText: 'Amount', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
            ),
          ),
          
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.prepController,
              decoration: const InputDecoration(hintText: 'Notes', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
            ),
          ),
          
          SizedBox(
             width: 40,
             child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                onSelected: (val) {
                   if (val == 'delete') setState(() => _ingredientRows.removeAt(index));
                   if (val == 'section') setState(() => row.isSection = true);
                },
                itemBuilder: (c) => [
                   const PopupMenuItem(value: 'section', child: Text('Convert to Section')),
                   const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
             ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionRowWidget(int index, ThemeData theme, {Key? key}) {
    final row = _directionRows[index];
    final isLast = index == _directionRows.length - 1;
    final hasImage = _stepImageMap.containsKey(index);
    
    return Container(
       key: key,
       padding: const EdgeInsets.symmetric(vertical: 8),
       decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1))),
       ),
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           ReorderableDragStartListener(index: index, child: const Padding(padding: EdgeInsets.only(top: 12, right: 8), child: Icon(Icons.drag_handle, size: 20, color: Colors.grey))),
           
           Padding(
             padding: const EdgeInsets.only(top: 12, right: 8),
             child: Container(
               width: 24, height: 24,
               decoration: BoxDecoration(color: theme.colorScheme.secondary.withOpacity(0.15), shape: BoxShape.circle),
               child: Center(child: Text('${index + 1}', style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 11))),
             ),
           ),

           Expanded(
             child: TextField(
               controller: row.controller,
               decoration: InputDecoration(
                  hintText: 'Enter step ${index + 1}...',
                  isDense: true,
                  border: const OutlineInputBorder(),
               ),
               maxLines: 3, minLines: 1,
               onChanged: (val) {
                  if (isLast && val.isNotEmpty) setState(() => _addDirectionRow());
               },
             ),
           ),
           
           Column(
              children: [
                 IconButton(
                    icon: Icon(hasImage ? Icons.image : Icons.add_photo_alternate_outlined, 
                       color: hasImage ? theme.colorScheme.primary : Colors.grey, size: 20),
                    onPressed: () => _pickStepImage(index),
                 ),
                 IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    onPressed: _directionRows.length > 1 ? () {
                       setState(() {
                          row.dispose(); 
                          _directionRows.removeAt(index);
                          _stepImageMap.remove(index); // Ensure map is cleaned
                       });
                    } : null,
                 ),
              ],
           ),
         ],
       ),
    );
  }

  // --- Image Logic ---
  Widget _buildImagePicker(ThemeData theme) {
    final hasImage = _headerImage != null && _headerImage!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recipe Photo', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickHeaderImage,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
            ),
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: _buildHeaderImageWidget(),
                      ),
                      Positioned(
                        top: 8, right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _imageActionButton(icon: Icons.edit, onTap: _pickHeaderImage, theme: theme),
                            const SizedBox(width: 8),
                            _imageActionButton(icon: Icons.delete, onTap: _removeHeaderImage, theme: theme),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(child: Icon(Icons.add_a_photo, size: 40, color: theme.colorScheme.onSurfaceVariant)),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderImageWidget() {
    if (_headerImage == null) return const SizedBox.shrink();
    if (_headerImage!.startsWith('http')) {
      return Image.network(_headerImage!, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image));
    }
    return Image.file(File(_headerImage!), fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image));
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
  
  void _removeHeaderImage() => setState(() => _headerImage = null);

  Widget _imageActionButton({required IconData icon, required VoidCallback onTap, required ThemeData theme}) {
    return Material(
      color: theme.colorScheme.surface.withOpacity(0.9),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 20)),
      ),
    );
  }

  // Step Images Logic
  Future<void> _pickStepImage(int stepIndex) async {
     final picker = ImagePicker();
     final file = await picker.pickImage(source: ImageSource.gallery);
     if (file != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${const Uuid().v4()}${path.extension(file.path)}';
        final saved = await File(file.path).copy('${appDir.path}/$fileName');
        setState(() {
           _stepImages.add(saved.path);
           _stepImageMap[stepIndex] = _stepImages.length - 1;
        });
     }
  }

  void _removeGalleryImage(int index) {
    setState(() {
      _stepImageMap.removeWhere((k, v) => v == index);
      final newMap = <int, int>{};
      for(final e in _stepImageMap.entries) {
         if (e.value > index) newMap[e.key] = e.value - 1;
         else newMap[e.key] = e.value;
      }
      _stepImageMap.clear();
      _stepImageMap.addAll(newMap);
      _stepImages.removeAt(index);
    });
  }

  Widget _buildStepImagesGallery(ThemeData theme) {
     if (_stepImages.isEmpty) return const SizedBox.shrink();
     return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text('Gallery', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
           const SizedBox(height: 8),
           SizedBox(
              height: 100,
              child: ListView.builder(
                 scrollDirection: Axis.horizontal,
                 itemCount: _stepImages.length,
                 itemBuilder: (context, index) {
                    return Padding(
                       padding: const EdgeInsets.only(right: 8),
                       child: Stack(
                          children: [
                             ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(_stepImages[index]), width: 100, height: 100, fit: BoxFit.cover)),
                             Positioned(top: 4, right: 4, child: GestureDetector(
                                onTap: () => _removeGalleryImage(index),
                                child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16)),
                             )),
                          ],
                       ),
                    );
                 },
              ),
           ),
        ],
     );
  }
}

class _DraftIngredientRow {
  final TextEditingController nameController;
  final TextEditingController amountController; // Combined
  final TextEditingController prepController;
  bool isSection;

  _DraftIngredientRow({
    required this.nameController,
    required this.amountController,
    required this.prepController,
    this.isSection = false,
  });

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    prepController.dispose();
  }
}

class _DirectionRow {
  final TextEditingController controller;
  _DirectionRow({required this.controller});
  void dispose() { controller.dispose(); }
}