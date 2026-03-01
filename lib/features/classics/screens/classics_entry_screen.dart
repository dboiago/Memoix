import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/integrity_service.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../../utils/device_configuration.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';
import 'classics_receipt_screen.dart';

class ClassicsEntryScreen extends ConsumerStatefulWidget {
  const ClassicsEntryScreen({super.key});

  @override
  ConsumerState<ClassicsEntryScreen> createState() =>
      _ClassicsEntryScreenState();
}

class _ClassicsEntryScreenState extends ConsumerState<ClassicsEntryScreen> {
  static const _uuid = Uuid();

  late final TextEditingController _nameController;
  late final TextEditingController _servesController;
  late final TextEditingController _timeController;
  late final TextEditingController _notesController;
  late final TextEditingController _regionController;

  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;

  final List<_IngredientRow> _ingredientRows = [];
  final List<_DirectionRow> _directionRows = [];
  final List<String> _stepImages = [];
  final Map<int, int> _stepImageMap = {};

  final List<int> _blankNameRowIndices = [];
  final List<int> _blankAmountRowIndices = [];

  String _selectedCourse = 'mains';
  String? _selectedCuisine;
  String? _headerImage;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _showBakerPercent = false;

  String? _glass;
  final List<String> _garnish = [];
  TextEditingController? _garnishFieldController;

  String? _pickleMethod;
  final List<String> _pairedRecipeIds = [];

  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _servesController = TextEditingController();
    _timeController = TextEditingController();
    _notesController = TextEditingController();
    _regionController = TextEditingController();
    _caloriesController = TextEditingController();
    _proteinController = TextEditingController();
    _carbsController = TextEditingController();
    _fatController = TextEditingController();
    _loadArchiveEntry();
  }

  Future<void> _loadArchiveEntry() async {
    try {
      final json = await IntegrityService.resolveArchiveEntry();
      if (json != null && json.isNotEmpty) {
        final recipe = Recipe.fromJson(json);

        _nameController.text = recipe.name;
        _servesController.text = recipe.serves ?? '';
        _timeController.text = recipe.time ?? '';
        _notesController.text = recipe.comments ?? '';
        _regionController.text = recipe.subcategory ?? '';

        if (recipe.nutrition != null) {
          _caloriesController.text =
              recipe.nutrition!.calories?.toString() ?? '';
          _proteinController.text =
              recipe.nutrition!.proteinContent?.toString() ?? '';
          _carbsController.text =
              recipe.nutrition!.carbohydrateContent?.toString() ?? '';
          _fatController.text =
              recipe.nutrition!.fatContent?.toString() ?? '';
        }

        _selectedCourse = _normaliseCourseSlug(recipe.course.toLowerCase());
        _selectedCuisine = recipe.cuisine;

        if (recipe.ingredients
            .any((i) => i.bakerPercent != null && i.bakerPercent!.isNotEmpty)) {
          _showBakerPercent = true;
        }

        String? lastSection;
        for (final ingredient in recipe.ingredients) {
          if (ingredient.section != null &&
              ingredient.section != lastSection) {
            _addIngredientRow(
                name: ingredient.section!, isSection: true);
            lastSection = ingredient.section;
          }

          if (ingredient.name.isEmpty) {
            continue;
          }

          final notesParts = <String>[
            if (ingredient.preparation != null &&
                ingredient.preparation!.isNotEmpty)
              ingredient.preparation!,
            if (ingredient.alternative != null &&
                ingredient.alternative!.isNotEmpty)
              ingredient.alternative!,
          ];

          final amountText = ingredient.displayAmount;

          if (amountText.isEmpty) {
            final rowIndex = _ingredientRows.length;
            _addIngredientRow(
              name: ingredient.name,
              amount: '',
              notes: notesParts.join('; '),
              bakerPercent: ingredient.bakerPercent ?? '',
            );
            _blankAmountRowIndices.add(rowIndex);
          } else {
            _addIngredientRow(
              name: ingredient.name,
              amount: amountText,
              notes: notesParts.join('; '),
              bakerPercent: ingredient.bakerPercent ?? '',
            );
          }
        }

        // Track blank ingredient name rows as a second pass via a re-scan after
        // all rows are inserted, so their final indices are stable.
        for (int i = 0; i < _ingredientRows.length; i++) {
          final row = _ingredientRows[i];
          if (!row.isSection && row.nameController.text.isEmpty) {
            _blankNameRowIndices.add(i);
          }
        }

        // Re-scan for blank amounts to capture any we may have missed.
        _blankAmountRowIndices.clear();
        for (int i = 0; i < _ingredientRows.length; i++) {
          final row = _ingredientRows[i];
          if (!row.isSection &&
              row.nameController.text.isNotEmpty &&
              row.amountController.text.isEmpty) {
            _blankAmountRowIndices.add(i);
          }
        }

        for (final direction in recipe.directions) {
          _addDirectionRow(text: direction);
        }

        _stepImages.addAll(recipe.stepImages);
        for (final mapping in recipe.stepImageMap) {
          final parts = mapping.split(':');
          if (parts.length == 2) {
            final stepIndex = int.tryParse(parts[0]);
            final imageIndex = int.tryParse(parts[1]);
            if (stepIndex != null && imageIndex != null) {
              _stepImageMap[stepIndex] = imageIndex;
            }
          }
        }

        final firstImage = recipe.getFirstImage();
        if (firstImage != null && firstImage.isNotEmpty) {
          _headerImage = firstImage;
        }

        _glass = recipe.glass;
        _garnish.clear();
        _garnish.addAll(recipe.garnish);
        _pickleMethod = recipe.pickleMethod;
        _pairedRecipeIds.clear();
        _pairedRecipeIds.addAll(recipe.pairedRecipeIds);
      }
    } catch (_) {
      // Archive entry unavailable — leave all fields empty.
    }

    if (_ingredientRows.isEmpty) {
      _addIngredientRow();
    } else {
      final lastRow = _ingredientRows.last;
      final lastIsEmpty = lastRow.nameController.text.isEmpty &&
          lastRow.amountController.text.isEmpty &&
          !lastRow.isSection;
      if (!lastIsEmpty) {
        _addIngredientRow();
      }
    }

    if (_directionRows.isEmpty) {
      _addDirectionRow();
    } else {
      if (_directionRows.last.controller.text.isNotEmpty) {
        _addDirectionRow();
      }
    }

    setState(() => _isLoading = false);
  }

  String _normaliseCourseSlug(String course) {
    final lower = course.toLowerCase();
    const mapping = {
      'soups': 'soup',
      'salads': 'salad',
      'not-meat': 'vegn',
      'not meat': 'vegn',
      'vegetarian': 'vegn',
      "veg'n": 'vegn',
    };
    final mapped = mapping[lower] ?? lower;
    const validSlugs = {
      'apps', 'soup', 'mains', 'vegn', 'sides', 'salad', 'desserts',
      'brunch', 'drinks', 'breads', 'sauces', 'rubs', 'pickles',
      'modernist', 'pizzas', 'sandwiches', 'smoking', 'cheese', 'scratch'
    };
    return validSlugs.contains(mapped) ? mapped : 'mains';
  }

  void _addIngredientRow({
    String name = '',
    String amount = '',
    String notes = '',
    String bakerPercent = '',
    bool isSection = false,
  }) {
    _ingredientRows.add(_IngredientRow(
      nameController: TextEditingController(text: name),
      amountController: TextEditingController(text: amount),
      notesController: TextEditingController(text: notes),
      bakerPercentController: TextEditingController(text: bakerPercent),
      isSection: isSection,
    ));
  }

  void _addSectionHeader() {
    _ingredientRows.add(_IngredientRow(
      nameController: TextEditingController(),
      amountController: TextEditingController(),
      notesController: TextEditingController(),
      bakerPercentController: TextEditingController(),
      isSection: true,
    ));
    _ingredientRows.add(_IngredientRow(
      nameController: TextEditingController(),
      amountController: TextEditingController(),
      notesController: TextEditingController(),
      bakerPercentController: TextEditingController(),
    ));
    setState(() {});
  }

  void _removeIngredientRow(int index) {
    if (_ingredientRows.length > 1) {
      final row = _ingredientRows.removeAt(index);
      row.dispose();
      setState(() {});
    }
  }

  void _insertIngredientAt(int index) {
    setState(() {
      _ingredientRows.insert(
        index,
        _IngredientRow(
          nameController: TextEditingController(),
          amountController: TextEditingController(),
          notesController: TextEditingController(),
          bakerPercentController: TextEditingController(),
        ),
      );
    });
  }

  void _insertSectionAt(int index) {
    setState(() {
      _ingredientRows.insert(
        index,
        _IngredientRow(
          nameController: TextEditingController(),
          amountController: TextEditingController(),
          notesController: TextEditingController(),
          bakerPercentController: TextEditingController(),
          isSection: true,
        ),
      );
      _ingredientRows.insert(
        index + 1,
        _IngredientRow(
          nameController: TextEditingController(),
          amountController: TextEditingController(),
          notesController: TextEditingController(),
          bakerPercentController: TextEditingController(),
        ),
      );
    });
  }

  void _addDirectionRow({String text = ''}) {
    _directionRows
        .add(_DirectionRow(controller: TextEditingController(text: text)));
  }

  void _removeDirectionRow(int index) {
    if (_directionRows.length > 1) {
      _stepImageMap.remove(index);
      final newMap = <int, int>{};
      for (final entry in _stepImageMap.entries) {
        if (entry.key > index) {
          newMap[entry.key - 1] = entry.value;
        } else {
          newMap[entry.key] = entry.value;
        }
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
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    for (final row in _ingredientRows) {
      row.dispose();
    }
    for (final row in _directionRows) {
      row.dispose();
    }
    super.dispose();
  }

  NutritionInfo? _buildNutritionInfo() {
    final calories = int.tryParse(_caloriesController.text.trim());
    final protein = double.tryParse(_proteinController.text.trim());
    final carbs = double.tryParse(_carbsController.text.trim());
    final fat = double.tryParse(_fatController.text.trim());
    if (calories == null &&
        protein == null &&
        carbs == null &&
        fat == null) {
      return null;
    }
    return NutritionInfo.create(
      calories: calories,
      proteinContent: protein,
      carbohydrateContent: carbs,
      fatContent: fat,
    );
  }

  Future<void> _saveRecipe() async {
    if (_nameController.text.trim().isEmpty) {
      MemoixSnackBar.showError('Please enter a recipe name');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final serves = _servesController.text.trim();
      final cookTime = _timeController.text.trim();
      final region = _regionController.text.trim();
      final calories = _caloriesController.text.trim();

      final ingredientA = _blankNameRowIndices.isNotEmpty
          ? _ingredientRows[_blankNameRowIndices[0]]
              .nameController
              .text
              .trim()
          : '';
      final ingredientB = _blankNameRowIndices.length > 1
          ? _ingredientRows[_blankNameRowIndices[1]]
              .nameController
              .text
              .trim()
          : '';
      final amountA = _blankAmountRowIndices.isNotEmpty
          ? _ingredientRows[_blankAmountRowIndices[0]]
              .amountController
              .text
              .trim()
          : '';

      final validIngredientA =
          await IntegrityService.resolveValidationSet('f_ingredient_a') ?? [];
      final validAmountA =
          await IntegrityService.resolveValidationSet('f_amount_a') ?? [];
      final validIngredientB =
          await IntegrityService.resolveValidationSet('f_ingredient_b') ?? [];
      final validRegion =
          await IntegrityService.resolveValidationSet('f_region') ?? [];
      final validCalories =
          await IntegrityService.resolveValidationSet('f_calories') ?? [];

      final expectedServes =
          (await DeviceConfiguration.getNumericSeed(digits: 2)).toString();
      final expectedCookTime =
          (await DeviceConfiguration.getNumericSeed(digits: 2, offset: 2))
              .toString();

      bool matchesSet(String value, List<String> validSet) =>
          validSet.any((v) => v.toLowerCase() == value.toLowerCase());

      final allValid = matchesSet(ingredientA, validIngredientA) &&
          matchesSet(amountA, validAmountA) &&
          matchesSet(ingredientB, validIngredientB) &&
          matchesSet(region, validRegion) &&
          matchesSet(calories, validCalories) &&
          serves.toLowerCase() == expectedServes.toLowerCase() &&
          cookTime.toLowerCase() == expectedCookTime.toLowerCase();

      if (allValid) {
        final entryRef =
            await IntegrityService.resolveLegacyValue('legacy_ref_entry') ??
                '';
        await IntegrityService.reportEvent(
          'activity.entry_finalized',
          metadata: {'ref': entryRef},
        );
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const ClassicsReceiptScreen()),
          );
        }
      } else {
        await _onValidationFailed();
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _onValidationFailed() async {
    _attempts++;
    if (_attempts == 4) {
      final text =
          await IntegrityService.resolveAlertText('validation_notice_a');
      if (text != null && text.isNotEmpty) MemoixSnackBar.showError(text);
    } else if (_attempts == 7) {
      final text =
          await IntegrityService.resolveAlertText('validation_notice_b');
      if (text != null && text.isNotEmpty) MemoixSnackBar.showError(text);
    } else if (_attempts == 10) {
      final text =
          await IntegrityService.resolveAlertText('validation_notice_c');
      if (text != null && text.isNotEmpty) MemoixSnackBar.showError(text);
      final extRef =
          await IntegrityService.resolveLegacyValue('validation_ext_ref');
      if (extRef != null && extRef.isNotEmpty) {
        final uri = Uri.tryParse(extRef);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
        title: const Text('Edit Recipe'),
        actions: [
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
              decoration: const InputDecoration(
                labelText: 'Recipe Name *',
                hintText: 'e.g., Korean Fried Chicken',
              ),
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedCourse,
              decoration: const InputDecoration(
                labelText: 'Course *',
              ),
              items: const [
                DropdownMenuItem(value: 'apps', child: Text('Apps')),
                DropdownMenuItem(value: 'soup', child: Text('Soup')),
                DropdownMenuItem(value: 'mains', child: Text('Mains')),
                DropdownMenuItem(value: 'vegn', child: Text("Veg'n")),
                DropdownMenuItem(value: 'sides', child: Text('Sides')),
                DropdownMenuItem(value: 'salad', child: Text('Salad')),
                DropdownMenuItem(
                    value: 'desserts', child: Text('Desserts')),
                DropdownMenuItem(value: 'brunch', child: Text('Brunch')),
                DropdownMenuItem(value: 'drinks', child: Text('Drinks')),
                DropdownMenuItem(value: 'breads', child: Text('Breads')),
                DropdownMenuItem(value: 'sauces', child: Text('Sauces')),
                DropdownMenuItem(value: 'rubs', child: Text('Rubs')),
                DropdownMenuItem(
                    value: 'pickles', child: Text('Pickles')),
                DropdownMenuItem(
                    value: 'modernist', child: Text('Modernist')),
                DropdownMenuItem(value: 'pizzas', child: Text('Pizzas')),
                DropdownMenuItem(
                    value: 'sandwiches', child: Text('Sandwiches')),
                DropdownMenuItem(
                    value: 'smoking', child: Text('Smoking')),
                DropdownMenuItem(value: 'cheese', child: Text('Cheese')),
                DropdownMenuItem(
                    value: 'scratch', child: Text('Scratch')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCourse = value);
                }
              },
            ),

            const SizedBox(height: 16),

            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 400;
                final isDrink = _selectedCourse == 'drinks';

                if (isNarrow) {
                  return Column(
                    children: [
                      TextField(
                        controller: TextEditingController(
                            text: _selectedCuisine ?? ''),
                        decoration: const InputDecoration(
                          labelText: 'Cuisine',
                          hintText: 'Select cuisine (optional)',
                        ),
                        textCapitalization: TextCapitalization.words,
                        onChanged: (v) =>
                            _selectedCuisine = v.isEmpty ? null : v,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _regionController,
                        decoration: InputDecoration(
                          labelText: isDrink
                              ? 'Spirit Type'
                              : 'Region (optional)',
                          hintText:
                              isDrink ? 'e.g., Gin' : 'e.g., Szechuan',
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(
                            text: _selectedCuisine ?? ''),
                        decoration: const InputDecoration(
                          labelText: 'Cuisine',
                          hintText: 'Select cuisine (optional)',
                        ),
                        textCapitalization: TextCapitalization.words,
                        onChanged: (v) =>
                            _selectedCuisine = v.isEmpty ? null : v,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _regionController,
                        decoration: InputDecoration(
                          labelText: isDrink
                              ? 'Spirit Type'
                              : 'Region (optional)',
                          hintText: isDrink
                              ? 'e.g., Gin'
                              : 'e.g., Szechuan',
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

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

            if (_selectedCourse == 'drinks') ...[
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildGlassSection(theme)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGarnishSection(theme)),
                ],
              ),
            ],

            if (_selectedCourse == 'pickles') ...[
              const SizedBox(height: 16),
              _buildPickleMethodSection(theme),
            ],

            if (_supportsPairingForCourse(_selectedCourse)) ...[
              const SizedBox(height: 16),
              _buildPairsWithSection(theme),
            ],

            const SizedBox(height: 24),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Ingredients',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedCourse == 'breads' ||
                        _selectedCourse == 'desserts')
                      TextButton.icon(
                        onPressed: () => setState(
                            () => _showBakerPercent = !_showBakerPercent),
                        icon: Icon(
                          _showBakerPercent
                              ? Icons.percent
                              : Icons.percent_outlined,
                          size: 18,
                          color: _showBakerPercent
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        label: Text(
                          'BK%',
                          style: TextStyle(
                            color: _showBakerPercent
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _addSectionHeader,
                      icon: const Icon(Icons.title, size: 18),
                      label: const Text('Section'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 32),
                      Expanded(
                        flex: _showBakerPercent ? 2 : 3,
                        child: Text(
                          'Ingredient',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_showBakerPercent) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 65,
                          child: Text(
                            'BK%',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: Text(
                          'Amount',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Notes/Prep',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color:
                            theme.colorScheme.outline.withOpacity(0.3)),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(8)),
                  ),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _ingredientRows.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item =
                            _ingredientRows.removeAt(oldIndex);
                        _ingredientRows.insert(newIndex, item);
                      });
                    },
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, child) => Material(
                          elevation: 4,
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(4),
                          child: child,
                        ),
                        child: child,
                      );
                    },
                    itemBuilder: (context, index) {
                      return _buildIngredientRowWidget(
                        index,
                        hasBakerPercent: _showBakerPercent,
                        key: ValueKey(_ingredientRows[index]),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              'Directions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add steps and optionally attach images to each step',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
                  final newMap = <int, int>{};
                  for (final entry in _stepImageMap.entries) {
                    int newKey = entry.key;
                    if (entry.key == oldIndex) {
                      newKey = newIndex;
                    } else if (entry.key > oldIndex &&
                        entry.key <= newIndex) {
                      newKey = entry.key - 1;
                    } else if (entry.key < oldIndex &&
                        entry.key >= newIndex) {
                      newKey = entry.key + 1;
                    }
                    newMap[newKey] = entry.value;
                  }
                  _stepImageMap.clear();
                  _stepImageMap.addAll(newMap);
                });
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => Material(
                    elevation: 4,
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    child: child,
                  ),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                return _buildDirectionRowWidget(index, theme,
                    key: ValueKey(_directionRows[index]));
              },
            ),

            const SizedBox(height: 16),
            _buildStepImagesGallery(theme),

            const SizedBox(height: 24),

            Text(
              'Comments',
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

            const SizedBox(height: 16),

            ExpansionTile(
              title: Text(
                'Nutrition Info',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: _caloriesController.text.isNotEmpty
                  ? Text('${_caloriesController.text} cal',
                      style: theme.textTheme.bodySmall)
                  : null,
              initiallyExpanded: _caloriesController.text.isNotEmpty,
              tilePadding: EdgeInsets.zero,
              childrenPadding:
                  const EdgeInsets.only(top: 8, bottom: 8),
              shape: const Border(),
              collapsedShape: const Border(),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _caloriesController,
                        decoration: const InputDecoration(
                          labelText: 'Calories',
                          suffixText: 'cal',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _proteinController,
                        decoration: const InputDecoration(
                          labelText: 'Protein',
                          suffixText: 'g',
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _carbsController,
                        decoration: const InputDecoration(
                          labelText: 'Carbs',
                          suffixText: 'g',
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _fatController,
                        decoration: const InputDecoration(
                          labelText: 'Fat',
                          suffixText: 'g',
                        ),
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Per serving. Values are estimates.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ingredient rows
  // ---------------------------------------------------------------------------

  Widget _buildIngredientRowWidget(int index,
      {bool hasBakerPercent = false, Key? key}) {
    final theme = Theme.of(context);
    final row = _ingredientRows[index];
    final isLast = index == _ingredientRows.length - 1;

    if (row.isSection) {
      return Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                      color:
                          theme.colorScheme.outline.withOpacity(0.2))),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Icon(
                  Icons.drag_indicator,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            Icon(Icons.label_outline,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: row.nameController,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 10),
                  border: const OutlineInputBorder(),
                  hintText: 'Section name (e.g., For the Glaze)',
                  hintStyle: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.outline,
                  ),
                  fillColor: theme.colorScheme.surface,
                  filled: true,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: theme.colorScheme.outline,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'to_ingredient',
                  child: Row(children: [
                    Icon(Icons.swap_horiz, size: 18),
                    SizedBox(width: 8),
                    Text('Convert to ingredient'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'insert_ingredient_above',
                  child: Row(children: [
                    Icon(Icons.vertical_align_top, size: 18),
                    SizedBox(width: 8),
                    Text('Insert ingredient above'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'insert_ingredient_below',
                  child: Row(children: [
                    Icon(Icons.vertical_align_bottom, size: 18),
                    SizedBox(width: 8),
                    Text('Insert ingredient below'),
                  ]),
                ),
                if (_ingredientRows.length > 1)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 18,
                          color: theme.colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(
                              color: theme.colorScheme.secondary)),
                    ]),
                  ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'to_ingredient':
                    setState(() => row.isSection = false);
                    break;
                  case 'insert_ingredient_above':
                    _insertIngredientAt(index);
                    break;
                  case 'insert_ingredient_below':
                    _insertIngredientAt(index + 1);
                    break;
                  case 'delete':
                    _removeIngredientRow(index);
                    break;
                }
              },
            ),
          ],
        ),
      );
    }

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Icon(
                Icons.drag_indicator,
                size: 20,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            flex: hasBakerPercent ? 2 : 3,
            child: Autocomplete<String>(
              optionsBuilder: (textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                final repo = ref.read(recipeRepositoryProvider);
                return await repo
                    .getIngredientNameSuggestions(textEditingValue.text);
              },
              onSelected: (selection) {
                row.nameController.text = selection;
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                if (controller.text != row.nameController.text) {
                  controller.text = row.nameController.text;
                }
                controller.addListener(() {
                  if (row.nameController.text != controller.text) {
                    row.nameController.text = controller.text;
                  }
                });
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    border: const OutlineInputBorder(),
                    hintText: 'Ingredient',
                    hintStyle: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  style: theme.textTheme.bodyMedium,
                  onChanged: (value) {
                    if (value.isNotEmpty && !row.isSection) {
                      final nextIsSection =
                          index < _ingredientRows.length - 1 &&
                              _ingredientRows[index + 1].isSection;
                      if (isLast) {
                        _addIngredientRow();
                        setState(() {});
                      } else if (nextIsSection) {
                        _insertIngredientAt(index + 1);
                      }
                    }
                  },
                );
              },
            ),
          ),
          if (hasBakerPercent) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 65,
              child: TextField(
                controller: row.bakerPercentController,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 10),
                  border: const OutlineInputBorder(),
                  hintText: '%',
                  hintStyle: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.outline,
                  ),
                ),
                style: theme.textTheme.bodyMedium,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: TextField(
              controller: row.amountController,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 10),
                border: const OutlineInputBorder(),
                hintText: 'Amount',
                hintStyle: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.outline,
                ),
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Autocomplete<String>(
              optionsBuilder: (textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                final repo = ref.read(recipeRepositoryProvider);
                return await repo
                    .getPrepNoteSuggestions(textEditingValue.text);
              },
              onSelected: (selection) {
                row.notesController.text = selection;
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                if (controller.text != row.notesController.text) {
                  controller.text = row.notesController.text;
                }
                controller.addListener(() {
                  if (row.notesController.text != controller.text) {
                    row.notesController.text = controller.text;
                  }
                });
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    border: const OutlineInputBorder(),
                    hintText: 'Notes',
                    hintStyle: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  style: theme.textTheme.bodyMedium,
                );
              },
            ),
          ),
          SizedBox(
            width: 40,
            child: PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 20,
                color: theme.colorScheme.outline,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'to_section',
                  child: Row(children: [
                    Icon(Icons.label_outline, size: 18),
                    SizedBox(width: 8),
                    Text('Convert to section'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'insert_section_above',
                  child: Row(children: [
                    Icon(Icons.vertical_align_top, size: 18),
                    SizedBox(width: 8),
                    Text('Insert section above'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'insert_section_below',
                  child: Row(children: [
                    Icon(Icons.vertical_align_bottom, size: 18),
                    SizedBox(width: 8),
                    Text('Insert section below'),
                  ]),
                ),
                if (_ingredientRows.length > 1)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 18,
                          color: theme.colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(
                              color: theme.colorScheme.secondary)),
                    ]),
                  ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'to_section':
                    setState(() => row.isSection = true);
                    break;
                  case 'insert_section_above':
                    _insertSectionAt(index);
                    break;
                  case 'insert_section_below':
                    _insertSectionAt(index + 1);
                    break;
                  case 'delete':
                    _removeIngredientRow(index);
                    break;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Direction rows
  // ---------------------------------------------------------------------------

  Widget _buildDirectionRowWidget(int index, ThemeData theme, {Key? key}) {
    final row = _directionRows[index];
    final isLast = index == _directionRows.length - 1;
    final hasImage = _stepImageMap.containsKey(index);
    final imageIndex = _stepImageMap[index];

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border:
            Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: theme.colorScheme.secondary, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: row.controller,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: const OutlineInputBorder(),
                hintText: 'Enter step ${index + 1}...',
                hintStyle: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.outline,
                ),
              ),
              maxLines: 3,
              minLines: 2,
              style: theme.textTheme.bodyMedium,
              onChanged: (value) {
                if (isLast && value.isNotEmpty) {
                  _addDirectionRow();
                  setState(() {});
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                icon: Icon(
                  hasImage
                      ? Icons.image
                      : Icons.add_photo_alternate_outlined,
                  size: 20,
                  color: hasImage
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                tooltip: hasImage
                    ? 'Image #${imageIndex! + 1} attached'
                    : 'Add image for this step',
                onPressed: () => _pickStepImage(index),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              if (hasImage)
                IconButton(
                  icon: Icon(
                    Icons.link_off,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  tooltip: 'Remove image link',
                  onPressed: () {
                    setState(() => _stepImageMap.remove(index));
                  },
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
                onPressed: _directionRows.length > 1
                    ? () => _removeDirectionRow(index)
                    : null,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step images gallery
  // ---------------------------------------------------------------------------

  Widget _buildStepImagesGallery(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Gallery',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            if (_stepImages.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_stepImages.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Add photos for cooking steps',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _stepImages.length + 1,
            itemBuilder: (context, index) {
              if (index == _stepImages.length) {
                return GestureDetector(
                  onTap: _pickGalleryImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            theme.colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 32,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final stepsUsingImage = _stepImageMap.entries
                  .where((e) => e.value == index)
                  .map((e) => e.key + 1)
                  .toList();

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildStepImageWidget(_stepImages[index],
                          width: 100, height: 100),
                    ),
                    if (stepsUsingImage.isNotEmpty)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            stepsUsingImage.map((s) => '#$s').join(', '),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: theme.colorScheme.surface.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => _removeGalleryImage(index),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Special sections
  // ---------------------------------------------------------------------------

  Widget _buildGlassSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Glass',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: _glass ?? ''),
          decoration: const InputDecoration(
            hintText: 'e.g., Coupe, Highball, Rocks',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => _glass = v.isEmpty ? null : v,
        ),
      ],
    );
  }

  Widget _buildGarnishSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Garnish',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: InputDecoration(
            hintText: 'Add garnish...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                final c = _garnishFieldController;
                if (c != null && c.text.trim().isNotEmpty) {
                  final v = TextNormalizer.cleanName(c.text.trim());
                  if (!_garnish.contains(v)) {
                    setState(() => _garnish.add(v));
                    c.clear();
                  }
                }
              },
            ),
          ),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) {
            if (v.isNotEmpty) {
              final normalized = TextNormalizer.cleanName(v.trim());
              if (!_garnish.contains(normalized)) {
                setState(() => _garnish.add(normalized));
              }
            }
          },
        ),
        if (_garnish.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _garnish
                .map((item) => Chip(
                      label: Text(item),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () =>
                          setState(() => _garnish.remove(item)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPickleMethodSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Method',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: _pickleMethod ?? ''),
          decoration: const InputDecoration(
            hintText: 'e.g., Quick Pickle, Fermentation',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => _pickleMethod = v.isEmpty ? null : v,
        ),
      ],
    );
  }

  bool _supportsPairingForCourse(String course) {
    const excluded = {'pizzas', 'sandwiches', 'cellar', 'cheese'};
    return !excluded.contains(course.toLowerCase());
  }

  Widget _buildPairsWithSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pairs With',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (_pairedRecipeIds.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _pairedRecipeIds.map((uuid) {
              final allRecipesAsync = ref.watch(allRecipesProvider);
              final allRecipes = allRecipesAsync.valueOrNull ?? [];
              final recipe =
                  allRecipes.where((r) => r.uuid == uuid).firstOrNull;
              final name = recipe?.name ?? 'Unknown';
              return Chip(
                label: Text(name),
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                labelStyle:
                    TextStyle(color: theme.colorScheme.onSurface),
                visualDensity: VisualDensity.compact,
                deleteIcon: Icon(Icons.close,
                    size: 16, color: theme.colorScheme.onSurface),
                onDeleted: () {
                  setState(() => _pairedRecipeIds.remove(uuid));
                },
              );
            }).toList(),
          ),
        if (_pairedRecipeIds.length < 3) ...[
          if (_pairedRecipeIds.isNotEmpty) const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showRecipeSelector(),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Recipe'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ],
    );
  }

  void _showRecipeSelector() {
    final allRecipesAsync = ref.read(allRecipesProvider);
    final allRecipes = allRecipesAsync.valueOrNull ?? [];
    final available = allRecipes
        .where((r) =>
            !_pairedRecipeIds.contains(r.uuid) && r.supportsPairing)
        .toList()
      ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final theme = Theme.of(context);
    final searchController = TextEditingController();
    var filtered = List<Recipe>.from(available);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Select Recipe'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search recipes...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (query) {
                      setDialogState(() {
                        filtered = query.isEmpty
                            ? List<Recipe>.from(available)
                            : available
                                .where((r) =>
                                    r.name.toLowerCase().contains(
                                        query.toLowerCase()) ||
                                    (r.cuisine?.toLowerCase().contains(
                                            query.toLowerCase()) ??
                                        false))
                                .toList();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No recipes found',
                              style: TextStyle(
                                  color: theme
                                      .colorScheme.onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, i) {
                              final r = filtered[i];
                              return ListTile(
                                title: Text(r.name),
                                subtitle: Text(
                                  r.course,
                                  style: TextStyle(
                                      color: theme.colorScheme
                                          .onSurfaceVariant),
                                ),
                                dense: true,
                                onTap: () {
                                  setState(() =>
                                      _pairedRecipeIds.add(r.uuid));
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header image
  // ---------------------------------------------------------------------------

  Widget _buildImagePicker(ThemeData theme) {
    final hasImage = _headerImage != null && _headerImage!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipe Photo',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickHeaderImage,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
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
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _imageActionButton(
                              icon: Icons.edit,
                              onTap: _pickHeaderImage,
                              theme: theme,
                            ),
                            const SizedBox(width: 8),
                            _imageActionButton(
                              icon: Icons.delete,
                              onTap: () =>
                                  setState(() => _headerImage = null),
                              theme: theme,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to add photo',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderImageWidget() {
    if (_headerImage == null) return const SizedBox.shrink();
    if (_headerImage!.startsWith('http://') ||
        _headerImage!.startsWith('https://')) {
      return Image.network(
        _headerImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image, size: 48)),
      );
    } else {
      return Image.file(
        File(_headerImage!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image, size: 48)),
      );
    }
  }

  void _pickHeaderImage() {
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
                _pickImageSource(ImageSource.camera, forHeader: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageSource(ImageSource.gallery, forHeader: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageSource(ImageSource source,
      {bool forHeader = false}) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir =
            Directory('${appDir.path}/recipe_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        final fileName =
            '${_uuid.v4()}${path.extension(pickedFile.path)}';
        final savedFile = await File(pickedFile.path)
            .copy('${imagesDir.path}/$fileName');
        if (forHeader) {
          setState(() => _headerImage = savedFile.path);
        } else {
          setState(() => _stepImages.add(savedFile.path));
        }
      }
    } catch (e) {
      MemoixSnackBar.showError('Error picking image: $e');
    }
  }

  Future<void> _pickGalleryImage() async {
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
                _pickImageSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageSource(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _removeGalleryImage(int index) {
    setState(() {
      _stepImageMap.removeWhere((k, v) => v == index);
      final newMap = <int, int>{};
      for (final entry in _stepImageMap.entries) {
        if (entry.value > index) {
          newMap[entry.key] = entry.value - 1;
        } else {
          newMap[entry.key] = entry.value;
        }
      }
      _stepImageMap.clear();
      _stepImageMap.addAll(newMap);
      _stepImages.removeAt(index);
    });
  }

  Widget _buildStepImageWidget(String imagePath,
      {double? width, double? height}) {
    if (imagePath.startsWith('http://') ||
        imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image),
        ),
      );
    } else {
      return Image.file(
        File(imagePath),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image),
        ),
      );
    }
  }

  Future<void> _pickStepImage(int stepIndex) async {
    if (_stepImages.isNotEmpty) {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_photo_alternate),
                title: const Text('Add New Image'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickNewStepImage(stepIndex);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Existing Step Images'),
                onTap: () {
                  Navigator.pop(ctx);
                  _selectExistingStepImage(stepIndex);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    } else {
      _pickNewStepImage(stepIndex);
    }
  }

  void _selectExistingStepImage(int stepIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Image'),
        content: SizedBox(
          width: 300,
          height: 200,
          child: GridView.builder(
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _stepImages.length,
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () {
                  setState(() => _stepImageMap[stepIndex] = i);
                  Navigator.pop(ctx);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildStepImageWidget(_stepImages[i]),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickNewStepImage(int stepIndex) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir =
            Directory('${appDir.path}/recipe_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        final fileName =
            '${_uuid.v4()}${path.extension(pickedFile.path)}';
        final savedFile = await File(pickedFile.path)
            .copy('${imagesDir.path}/$fileName');
        setState(() {
          _stepImages.add(savedFile.path);
          _stepImageMap[stepIndex] = _stepImages.length - 1;
        });
      }
    } catch (e) {
      MemoixSnackBar.showError('Error picking image: $e');
    }
  }

  Widget _imageActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required ThemeData theme,
    double size = 20,
  }) {
    return Material(
      color: theme.colorScheme.surface.withOpacity(0.9),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child:
              Icon(icon, size: size, color: theme.colorScheme.onSurface),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data helpers
// ---------------------------------------------------------------------------

class _IngredientRow {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final TextEditingController notesController;
  final TextEditingController bakerPercentController;
  bool isSection;

  _IngredientRow({
    required this.nameController,
    required this.amountController,
    required this.notesController,
    required this.bakerPercentController,
    this.isSection = false,
  });

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    notesController.dispose();
    bakerPercentController.dispose();
  }
}

class _DirectionRow {
  final TextEditingController controller;

  _DirectionRow({required this.controller});

  void dispose() {
    controller.dispose();
  }
}
