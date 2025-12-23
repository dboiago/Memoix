import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/colors.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/models/course.dart';
import '../../recipes/models/cuisine.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
import '../../recipes/screens/recipe_detail_screen.dart';
import '../../modernist/models/modernist_recipe.dart';
import '../../modernist/screens/modernist_edit_screen.dart';
import '../../modernist/screens/modernist_detail_screen.dart';
import '../../modernist/repository/modernist_repository.dart';
import '../../pizzas/models/pizza.dart';
import '../../pizzas/screens/pizza_edit_screen.dart';
import '../../pizzas/screens/pizza_detail_screen.dart';
import '../../pizzas/repository/pizza_repository.dart';
import '../../smoking/models/smoking_recipe.dart';
import '../../smoking/screens/smoking_edit_screen.dart';
import '../../smoking/screens/smoking_detail_screen.dart';
import '../../smoking/repository/smoking_repository.dart';
import '../models/recipe_import_result.dart';

/// Screen for reviewing and mapping imported recipe data
/// Shown when confidence is below threshold or user wants to review
class ImportReviewScreen extends ConsumerStatefulWidget {
  final RecipeImportResult importResult;

  const ImportReviewScreen({
    super.key,
    required this.importResult,
  });

  @override
  ConsumerState<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends ConsumerState<ImportReviewScreen> {
  late TextEditingController _nameController;
  late TextEditingController _servesController;
  late TextEditingController _timeController;
  late TextEditingController _techniqueController;

  // Track selections
  String _selectedCourse = 'Mains';
  String? _selectedCuisine;
  
  // Modernist-specific fields
  ModernistType _selectedModernistType = ModernistType.concept;

  // Drinks-specific fields
  String? _glass;
  final List<String> _garnish = [];
  TextEditingController? _garnishFieldController;

  // Sanitized ingredients list (removes empty/invalid entries)
  late List<RawIngredientData> _sanitizedIngredients;

  // Track which raw ingredients to include
  late Set<int> _selectedIngredientIndices;

  // Track which directions to include
  late Set<int> _selectedDirectionIndices;

  @override
  void initState() {
    super.initState();
    final result = widget.importResult;

    _nameController = TextEditingController(text: result.name ?? '');
    _servesController = TextEditingController(text: result.serves ?? '');
    _timeController = TextEditingController(text: result.time ?? '');
    _techniqueController = TextEditingController();

    // Normalize course to match Course.defaults names (proper capitalization)
    final rawCourse = result.course ?? 'Mains';
    _selectedCourse = _normalizeCourse(rawCourse);
    _selectedCuisine = result.cuisine;

    // Initialize drinks-specific fields
    _glass = result.glass;
    _garnish.clear();
    _garnish.addAll(result.garnish);

    // Sanitize ingredients to remove empty/invalid entries
    _sanitizedIngredients = RawIngredientData.sanitize(result.rawIngredients);

    // Pre-select all sanitized ingredients
    _selectedIngredientIndices =
        Set.from(List.generate(_sanitizedIngredients.length, (i) => i));

    // Pre-select all directions
    _selectedDirectionIndices =
        Set.from(List.generate(result.rawDirections.length, (i) => i));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servesController.dispose();
    _timeController.dispose();
    _techniqueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.importResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Import'),
        actions: [
          TextButton(
            onPressed: _saveRecipe,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Confidence overview
          _buildConfidenceCard(theme, result),
          const SizedBox(height: 16),

          // Raw text preview (for OCR)
          if (result.rawText != null) ...[
            _buildRawTextCard(theme, result.rawText!),
            const SizedBox(height: 16),
          ],

          // Recipe name
          _buildSectionTitle(theme, 'Recipe Name', Icons.restaurant,
              confidence: result.nameConfidence,),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Enter recipe name',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 24),

          // Course selection
          _buildSectionTitle(theme, 'Course', Icons.category,
              confidence: result.courseConfidence,),
          const SizedBox(height: 8),
          _buildCourseSelector(theme, result),
          const SizedBox(height: 24),

          // Cuisine OR Category/Technique based on course type
          if (_isModernistCourse) ...[
            // Modernist: show Category (Concept/Technique) and Technique
            _buildSectionTitle(theme, 'Category', Icons.science),
            const SizedBox(height: 8),
            _buildModernistCategorySelector(theme),
            const SizedBox(height: 24),
            
            _buildSectionTitle(theme, 'Technique', Icons.precision_manufacturing),
            const SizedBox(height: 8),
            _buildModernistTechniqueSelector(theme),
            const SizedBox(height: 24),
          ] else ...[
            // Regular recipes: show Cuisine
            _buildSectionTitle(theme, 'Cuisine', Icons.public,
                confidence: result.cuisineConfidence,),
            const SizedBox(height: 8),
            _buildCuisineSelector(theme, result),
            const SizedBox(height: 24),
          ],

          // Servings and time
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(theme, 'Servings', Icons.people,
                        confidence: result.servesConfidence,),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _servesController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 4',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(theme, 'Time', Icons.timer,
                        confidence: result.timeConfidence,),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _timeController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 30 min',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Glass and Garnish (for Drinks) - side by side for consistency with edit screen
          if (_isDrinksCourse) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(theme, 'Glass', Icons.local_bar),
                      const SizedBox(height: 8),
                      _buildGlassField(theme),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(theme, 'Garnish', Icons.eco),
                      const SizedBox(height: 8),
                      _buildGarnishSection(theme),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Ingredients
          _buildSectionTitle(theme, 'Ingredients', Icons.kitchen,
              confidence: result.ingredientsConfidence,),
          const SizedBox(height: 8),
          _buildIngredientsList(theme, result),
          const SizedBox(height: 24),

          // Equipment (for Modernist recipes)
          if (result.equipment.isNotEmpty) ...[
            _buildSectionTitle(theme, 'Equipment', Icons.build_outlined),
            const SizedBox(height: 8),
            _buildEquipmentList(theme, result),
            const SizedBox(height: 24),
          ],

          // Directions
          _buildSectionTitle(theme, 'Directions', Icons.format_list_numbered,
              confidence: result.directionsConfidence,),
          const SizedBox(height: 8),
          _buildDirectionsList(theme, result),
          const SizedBox(height: 24),

          // Notes (if any)
          if (result.notes != null && result.notes!.isNotEmpty) ...[
            _buildSectionTitle(theme, 'Notes', Icons.notes),
            const SizedBox(height: 8),
            _buildNotesCard(theme, result.notes!),
            const SizedBox(height: 24),
          ],
          
          // Nutrition (if parsed from OCR)
          if (result.nutrition != null) ...[
            _buildSectionTitle(theme, 'Nutrition', Icons.restaurant_menu),
            const SizedBox(height: 8),
            _buildNutritionCard(theme, result.nutrition!),
            const SizedBox(height: 24),
          ],

          const SizedBox(height: 8),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _openInEditScreen,
                  child: const Text('Edit More Details'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _saveRecipe,
                  child: const Text('Save Recipe'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildConfidenceCard(ThemeData theme, RecipeImportResult result) {
    final confidence = result.overallConfidence;
    final IconData icon;
    final String message;

    if (confidence >= 0.8) {
      icon = Icons.check_circle;
      message = 'High confidence import! Review and save.';
    } else if (confidence >= 0.5) {
      icon = Icons.info_outline;
      message = 'Some fields need your attention.';
    } else {
      icon = Icons.help_outline;
      message = 'Low confidence. Please review all fields.';
    }

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message, style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  )),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: confidence,
                    backgroundColor: theme.colorScheme.outline.withOpacity(0.3),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (result.fieldsNeedingAttention.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Review: ${result.fieldsNeedingAttention.join(", ")}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawTextCard(ThemeData theme, String rawText) {
    return ExpansionTile(
      leading: const Icon(Icons.text_fields),
      title: const Text('Raw Extracted Text'),
      subtitle: const Text('Tap to view original OCR text'),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: theme.colorScheme.surfaceContainerHighest,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Copy button at top for easy access
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: rawText));
                    MemoixSnackBar.showSuccess('Raw text copied to clipboard');
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy All'),
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                rawText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Fields that are optional and shouldn't show "Needs input"
  static const _optionalFields = {'Cuisine', 'Servings', 'Time'};

  /// Normalize course string to match Course.defaults names
  String _normalizeCourse(String course) {
    final lower = course.toLowerCase();
    for (final c in Course.defaults) {
      if (c.slug == lower || c.name.toLowerCase() == lower) {
        return c.name;
      }
    }
    // Fallback: capitalize first letter
    if (course.isEmpty) return 'Mains';
    return course[0].toUpperCase() + course.substring(1);
  }
  
  Widget _buildSectionTitle(
    ThemeData theme,
    String title,
    IconData icon, {
    double confidence = 1.0,
  }) {
    final Color indicatorColor;
    final String label;
    
    // For optional fields with low confidence, show "Optional" instead of "Needs input"
    final isOptional = _optionalFields.contains(title);
    
    if (confidence >= 0.7) {
      indicatorColor = theme.colorScheme.primary;
      label = 'Good';
    } else if (confidence >= 0.4) {
      indicatorColor = theme.colorScheme.secondary;
      label = 'Review';
    } else if (isOptional) {
      // Optional fields with no data - subtle indicator
      indicatorColor = theme.colorScheme.outline;
      label = 'Optional';
    } else {
      // Required fields with no data - use secondary color
      indicatorColor = theme.colorScheme.secondary;
      label = 'Needs input';
    }

    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: indicatorColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: indicatorColor),
        ),
      ],
    );
  }

  /// Check if current course is Modernist
  bool get _isModernistCourse => _selectedCourse.toLowerCase() == 'modernist';
  
  /// Check if current course is Smoking
  bool get _isSmokingCourse => _selectedCourse.toLowerCase() == 'smoking';
  
  /// Check if current course is Pizzas
  bool get _isPizzasCourse => _selectedCourse.toLowerCase() == 'pizzas';
  
  /// Check if current course is Drinks
  bool get _isDrinksCourse => _selectedCourse.toLowerCase() == 'drinks';
  
  /// Check if current course has a specialized edit screen
  bool get _hasSpecializedScreen => _isModernistCourse || _isSmokingCourse || _isPizzasCourse;

  /// Convert course code to display name
  String _courseDisplayName(String course) {
    switch (course.toLowerCase()) {
      case 'modernist':
        return 'Modernist';
      default:
        return course;
    }
  }

  Widget _buildCourseSelector(ThemeData theme, RecipeImportResult result) {
    // Get all available courses
    final allCourses = Course.defaults.map((c) => c.name).toList();
    
    // Combine detected + all available
    final courses = <String>{
      ...result.detectedCourses,
      ...allCourses,
    }.toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: courses.map((course) {
        final isSelected = _selectedCourse == course;
        return ChoiceChip(
          label: Text(_courseDisplayName(course)),
          selected: isSelected,
          onSelected: (_) => setState(() => _selectedCourse = course),
          selectedColor: theme.colorScheme.primary.withOpacity(0.2),
          showCheckmark: false,
        );
      }).toList(),
    );
  }

  Widget _buildCuisineSelector(ThemeData theme, RecipeImportResult result) {
    return InkWell(
      onTap: () => _showCuisineSheet(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Cuisine',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          _selectedCuisine != null
              ? '${Cuisine.byCode(_selectedCuisine!)?.flag ?? ''} ${Cuisine.byCode(_selectedCuisine!)?.name ?? _selectedCuisine}'
              : 'Select cuisine (optional)',
          style: TextStyle(
            color: _selectedCuisine != null
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// Category selector for Modernist recipes (Concept/Technique)
  Widget _buildModernistCategorySelector(ThemeData theme) {
    return Row(
      children: [
        _buildModernistCategoryChip('Concept', ModernistType.concept, theme),
        const SizedBox(width: 12),
        _buildModernistCategoryChip('Technique', ModernistType.technique, theme),
      ],
    );
  }

  Widget _buildModernistCategoryChip(String label, ModernistType type, ThemeData theme) {
    final isSelected = _selectedModernistType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedModernistType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.secondary.withOpacity(0.15)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.secondary
                : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected
                ? theme.colorScheme.secondary
                : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Technique selector for Modernist recipes (with autocomplete)
  Widget _buildModernistTechniqueSelector(ThemeData theme) {
    return Autocomplete<String>(
      optionsBuilder: (value) =>
          ModernistTechniques.getSuggestions(value.text),
      initialValue: TextEditingValue(text: _techniqueController.text),
      onSelected: (value) => _techniqueController.text = value,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        controller.text = _techniqueController.text;
        controller.addListener(() => _techniqueController.text = controller.text);
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'e.g., Spherification, Foams, Sous Vide',
          ),
          textCapitalization: TextCapitalization.words,
        );
      },
    );
  }
  
  void _showCuisineSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CuisinePickerSheet(
        selectedCuisine: _selectedCuisine,
        onChanged: (code) {
          setState(() => _selectedCuisine = code);
          Navigator.pop(ctx);
        },
        onClear: () {
          setState(() => _selectedCuisine = null);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _buildIngredientsList(ThemeData theme, RecipeImportResult result) {
    if (_sanitizedIngredients.isEmpty) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No ingredients found in source. You can add them after saving.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Select all row
        Row(
          children: [
            Text(
              '${_selectedIngredientIndices.length} of ${_sanitizedIngredients.length} selected',
              style: theme.textTheme.bodySmall,
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _selectedIngredientIndices = Set.from(
                    List.generate(_sanitizedIngredients.length, (i) => i),);
              }),
              child: const Text('All'),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _selectedIngredientIndices.clear()),
              child: const Text('None'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Check if any ingredient has baker's percentage
        Builder(builder: (context) {
          final hasBakerPercent = _sanitizedIngredients.any((i) => i.bakerPercent != null);
          
          return Column(
            children: [
              // Column headers - matching edit screen style
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    // Space for checkbox
                    const SizedBox(width: 32),
                    Expanded(
                      flex: hasBakerPercent ? 2 : 3,
                      child: Text('Ingredient', 
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (hasBakerPercent) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: Text('BK%', 
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text('Amount', 
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text('Notes/Prep', 
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Ingredient rows in bordered container
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                child: Column(
                  children: _sanitizedIngredients.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ingredient = entry.value;
                    final isSelected = _selectedIngredientIndices.contains(index);
                    final isLast = index == _sanitizedIngredients.length - 1;
                    
                    // Clean the name - remove colons and trim
                    final cleanName = ingredient.name.replaceAll(':', '').trim();
                    
                    // Check if this is a section-only header (empty name, has section)
                    // Sanitization already removed truly empty entries, so if name is empty here it's a section header
                    final isSectionHeader = cleanName.isEmpty && ingredient.sectionName != null;
                    
                    // Skip empty entries that aren't proper section headers
                    // This catches edge cases where an entry has empty name but no section
                    if (cleanName.isEmpty && !isSectionHeader) {
                      return const SizedBox.shrink();
                    }

                    // Section header row - spans full width
                    if (isSectionHeader) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                          border: isLast 
                              ? null 
                              : Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
                        ),
                        child: Row(
                          children: [
                            // Checkbox for section
                            SizedBox(
                              width: 32,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedIngredientIndices.add(index);
                                    } else {
                                      _selectedIngredientIndices.remove(index);
                                    }
                                  });
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            Text(
                              ingredient.sectionName!,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isSelected 
                                    ? theme.colorScheme.primary 
                                    : theme.colorScheme.outline,
                                decoration: isSelected ? null : TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        border: isLast 
                            ? null 
                            : Border(bottom: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2))),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Checkbox
                          SizedBox(
                            width: 32,
                            child: Checkbox(
                              value: isSelected,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedIngredientIndices.add(index);
                                  } else {
                                    _selectedIngredientIndices.remove(index);
                                  }
                                });
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          // Ingredient name
                          Expanded(
                            flex: hasBakerPercent ? 2 : 3,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                ingredient.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  decoration: isSelected ? null : TextDecoration.lineThrough,
                                  color: isSelected ? null : theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          ),
                          // Baker's percentage (conditional)
                          if (hasBakerPercent) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 60,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                  ingredient.bakerPercent ?? '',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    decoration: isSelected ? null : TextDecoration.lineThrough,
                                    color: isSelected ? null : theme.colorScheme.outline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          // Amount (includes unit)
                          Expanded(
                            flex: 2,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                [ingredient.amount, ingredient.unit]
                                    .where((s) => s != null && s.isNotEmpty)
                                    .join(' '),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  decoration: isSelected ? null : TextDecoration.lineThrough,
                                  color: isSelected ? null : theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Notes/Prep (includes alternative if present)
                          Expanded(
                            flex: 3,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                border: OutlineInputBorder(),
                              ),
                              child: Text(
                                _buildIngredientNotes(ingredient),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  decoration: isSelected ? null : TextDecoration.lineThrough,
                                  color: isSelected ? null : theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },),
      ],
    );
  }

  Widget _buildEquipmentList(ThemeData theme, RecipeImportResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: result.equipment.map((item) {
            return Chip(
              avatar: const Icon(Icons.build_outlined, size: 18),
              label: Text(item),
              backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.5),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGlassField(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Autocomplete<String>(
          optionsBuilder: (value) {
            return _glassSuggestions.where(
              (s) => s.toLowerCase().contains(value.text.toLowerCase()),
            );
          },
          initialValue: TextEditingValue(text: _glass ?? ''),
          onSelected: (value) {
            setState(() => _glass = value);
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                hintText: 'e.g., Coupe, Highball, Rocks',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (value) {
                _glass = value.isEmpty ? null : value;
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildGarnishSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Autocomplete<String>(
              optionsBuilder: (value) {
                return _garnishSuggestions.where(
                  (s) => s.toLowerCase().contains(value.text.toLowerCase()) &&
                         !_garnish.contains(s),
                );
              },
              onSelected: (value) {
                final normalized = normalizeGarnish(value);
                if (!_garnish.contains(normalized)) {
                  setState(() => _garnish.add(normalized));
                  _garnishFieldController?.clear();
                }
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                _garnishFieldController = controller;
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Add garnish...',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        final value = controller.text.trim();
                        if (value.isNotEmpty) {
                          final normalized = normalizeGarnish(value);
                          if (!_garnish.contains(normalized)) {
                            setState(() => _garnish.add(normalized));
                            controller.clear();
                          }
                        }
                      },
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      final normalized = normalizeGarnish(value);
                      if (!_garnish.contains(normalized)) {
                        setState(() => _garnish.add(normalized));
                        controller.clear();
                      }
                    }
                  },
                );
              },
            ),
            if (_garnish.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _garnish.map((item) => Chip(
                  label: Text(item),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => setState(() => _garnish.remove(item)),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Common glass types for autocomplete
  static const List<String> _glassSuggestions = [
    'Coupe',
    'Highball',
    'Rocks',
    'Collins',
    'Martini',
    'Nick & Nora',
    'Old Fashioned',
    'Wine Glass',
    'Flute',
    'Hurricane',
    'Copper Mug',
    'Julep Cup',
    'Tiki Mug',
    'Shot Glass',
    'Snifter',
    'Goblet',
    'Tumbler',
    'Pint Glass',
    'Margarita Glass',
    'Pilsner',
  ];

  /// Common garnish types for autocomplete
  static const List<String> _garnishSuggestions = [
    'Lemon twist',
    'Lemon wheel',
    'Lemon wedge',
    'Lime twist',
    'Lime wheel',
    'Lime wedge',
    'Orange twist',
    'Orange wheel',
    'Orange slice',
    'Cherry',
    'Maraschino cherry',
    'Luxardo cherry',
    'Brandied cherry',
    'Olive',
    'Cocktail onion',
    'Mint sprig',
    'Basil leaf',
    'Rosemary sprig',
    'Cucumber slice',
    'Celery stalk',
    'Pineapple wedge',
    'Edible flower',
    'Salt rim',
    'Sugar rim',
    'Tajin rim',
    'Cinnamon stick',
    'Nutmeg (grated)',
    'Coffee beans',
    'Candied ginger',
    'Pickled jalapeño',
    'Bacon strip',
  ];

  Widget _buildDirectionsList(ThemeData theme, RecipeImportResult result) {
    if (result.rawDirections.isEmpty) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No directions found in source. You can add them after saving.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Select/Deselect all header
        Row(
          children: [
            Text(
              '${_selectedDirectionIndices.length} of ${result.rawDirections.length} steps',
              style: theme.textTheme.bodySmall,
            ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _selectedDirectionIndices = Set.from(
                    List.generate(result.rawDirections.length, (i) => i),);
              }),
              child: const Text('All'),
            ),
            TextButton(
              onPressed: () =>
                  setState(() => _selectedDirectionIndices.clear()),
              child: const Text('None'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Direction rows - matching edit screen style
        ...result.rawDirections.asMap().entries.map((entry) {
          final index = entry.key;
          final direction = entry.value;
          final isSelected = _selectedDirectionIndices.contains(index);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox and step number
                Column(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedDirectionIndices.add(index);
                          } else {
                            _selectedDirectionIndices.remove(index);
                          }
                        });
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.secondary, width: 1.5),
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
                
                // Direction text - using InputDecorator to match TextField
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      direction,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: isSelected ? null : TextDecoration.lineThrough,
                        color: isSelected ? null : theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNotesCard(ThemeData theme, String notes) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          notes,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
  
  Widget _buildNutritionCard(ThemeData theme, NutritionInfo nutrition) {
    final items = <Widget>[];
    
    if (nutrition.servingSize != null) {
      items.add(_nutritionRow('Serving Size', nutrition.servingSize!));
    }
    if (nutrition.calories != null) {
      items.add(_nutritionRow('Calories', '${nutrition.calories}'));
    }
    if (nutrition.fatContent != null) {
      items.add(_nutritionRow('Fat', '${nutrition.fatContent}g'));
    }
    if (nutrition.carbohydrateContent != null) {
      items.add(_nutritionRow('Carbs', '${nutrition.carbohydrateContent}g'));
    }
    if (nutrition.proteinContent != null) {
      items.add(_nutritionRow('Protein', '${nutrition.proteinContent}g'));
    }
    if (nutrition.fiberContent != null) {
      items.add(_nutritionRow('Fiber', '${nutrition.fiberContent}g'));
    }
    if (nutrition.sugarContent != null) {
      items.add(_nutritionRow('Sugar', '${nutrition.sugarContent}g'));
    }
    if (nutrition.sodiumContent != null) {
      items.add(_nutritionRow('Sodium', '${nutrition.sodiumContent}mg'));
    }
    
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 8,
          children: items,
        ),
      ),
    );
  }
  
  Widget _nutritionRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Text(value),
      ],
    );
  }

  void _openInEditScreen() {
    // Route to appropriate edit screen based on course type
    if (_isModernistCourse) {
      final modernistRecipe = _buildModernistRecipe();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ModernistEditScreen(importedRecipe: modernistRecipe),
        ),
      );
    } else if (_isSmokingCourse) {
      final smokingRecipe = _buildSmokingRecipe();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SmokingEditScreen(importedRecipe: smokingRecipe),
        ),
      );
    } else if (_isPizzasCourse) {
      final pizzaRecipe = _buildPizzaRecipe();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PizzaEditScreen(importedRecipe: pizzaRecipe),
        ),
      );
    } else {
      final recipe = _buildRecipe();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RecipeEditScreen(importedRecipe: recipe),
        ),
      );
    }
  }

  /// Build a ModernistRecipe from import data
  ModernistRecipe _buildModernistRecipe() {
    // Build ingredients from selected
    // Section headers (empty name) are tracked to assign sections to following ingredients
    final ingredients = <ModernistIngredient>[];
    String? currentSection;
    for (final index in _selectedIngredientIndices.toList()..sort()) {
      if (index < _sanitizedIngredients.length) {
        final rawIngredient = _sanitizedIngredients[index];
        
        // If this is a section header, track it but don't add
        if (rawIngredient.name.isEmpty && rawIngredient.sectionName != null) {
          currentSection = rawIngredient.sectionName;
          continue;
        }
        
        // Skip any ingredient with empty name (even without sectionName)
        // This catches edge cases where empty entries slip through sanitization
        if (rawIngredient.name.trim().isEmpty) {
          continue;
        }
        
        // Add the ingredient with current section
        ingredients.add(ModernistIngredient.create(
          name: rawIngredient.name,
          amount: rawIngredient.amount,
          unit: rawIngredient.unit,
          notes: rawIngredient.preparation,
          section: currentSection,
        ));
      }
    }

    // Build directions from selected
    final directions = <String>[];
    for (final index in _selectedDirectionIndices.toList()..sort()) {
      if (index < widget.importResult.rawDirections.length) {
        directions.add(widget.importResult.rawDirections[index]);
      }
    }

    // Get the header image - first from imagePaths, fallback to imageUrl
    String? headerImage;
    List<String>? stepImages;
    if (widget.importResult.imagePaths != null &&
        widget.importResult.imagePaths!.isNotEmpty) {
      headerImage = widget.importResult.imagePaths!.first;
      if (widget.importResult.imagePaths!.length > 1) {
        stepImages = widget.importResult.imagePaths!.sublist(1);
      }
    } else if (widget.importResult.imageUrl != null) {
      headerImage = widget.importResult.imageUrl;
    }

    return ModernistRecipe.create(
      uuid: const Uuid().v4(),
      name: _nameController.text.trim().isEmpty
          ? 'Untitled Recipe'
          : _nameController.text.trim(),
      type: _selectedModernistType,
      technique: _techniqueController.text.trim().isEmpty
          ? null
          : _techniqueController.text.trim(),
      serves: _servesController.text.trim().isEmpty
          ? null
          : _servesController.text.trim(),
      time: _timeController.text.trim().isEmpty
          ? null
          : _timeController.text.trim(),
      equipment: widget.importResult.equipment,
      ingredients: ingredients,
      directions: directions,
      notes: widget.importResult.notes,
      sourceUrl: widget.importResult.sourceUrl,
      headerImage: headerImage,
      stepImages: stepImages,
      source: ModernistSource.imported,
    );
  }

  Recipe _buildRecipe() {
    // Build ingredients from selected
    // Section headers (empty name) are tracked to assign sections to following ingredients
    final ingredients = <Ingredient>[];
    String? currentSection;
    for (final index in _selectedIngredientIndices.toList()..sort()) {
      if (index < _sanitizedIngredients.length) {
        final rawIngredient = _sanitizedIngredients[index];
        
        // If this is a section header (empty name with section), track it but don't add
        if (rawIngredient.name.isEmpty && rawIngredient.sectionName != null) {
          currentSection = rawIngredient.sectionName;
          continue;
        }
        
        // Skip any ingredient with empty name (even without sectionName)
        // This catches edge cases where empty entries slip through sanitization
        if (rawIngredient.name.trim().isEmpty) {
          continue;
        }
        
        // Add the ingredient with current section
        ingredients.add(rawIngredient.toIngredient(section: currentSection));
      }
    }

    // Build directions from selected
    final directions = <String>[];
    for (final index in _selectedDirectionIndices.toList()..sort()) {
      if (index < widget.importResult.rawDirections.length) {
        directions.add(widget.importResult.rawDirections[index]);
      }
    }

    // Build notes - include equipment if present
    String? notes = widget.importResult.notes;
    if (widget.importResult.equipment.isNotEmpty) {
      final equipmentText = 'Equipment: ${widget.importResult.equipment.join(', ')}';
      notes = notes != null && notes.isNotEmpty 
          ? '$notes\n\n$equipmentText' 
          : equipmentText;
    }

    final recipe = Recipe.create(
      uuid: const Uuid().v4(),
      name: _nameController.text.trim().isEmpty
          ? 'Untitled Recipe'
          : _nameController.text.trim(),
      course: _selectedCourse,
      cuisine: _selectedCuisine,
      subcategory: widget.importResult.subcategory,
      serves: _servesController.text.trim().isEmpty
          ? null
          : _servesController.text.trim(),
      time: _timeController.text.trim().isEmpty
          ? null
          : _timeController.text.trim(),
      ingredients: ingredients,
      directions: directions,
      notes: notes,
      imageUrl: widget.importResult.imageUrl,
      sourceUrl: widget.importResult.sourceUrl,
      source: widget.importResult.source,
      nutrition: widget.importResult.nutrition,
      glass: _isDrinksCourse ? _glass : null,
      garnish: _isDrinksCourse ? _garnish : const [],
    );

    // Add multiple images if available (from multi-image import)
    // First image becomes the header, rest go to step images gallery
    if (widget.importResult.imagePaths != null &&
        widget.importResult.imagePaths!.isNotEmpty) {
      recipe.headerImage = widget.importResult.imagePaths!.first;
      if (widget.importResult.imagePaths!.length > 1) {
        recipe.stepImages = widget.importResult.imagePaths!.sublist(1);
      }
    }

    return recipe;
  }

  /// Build a SmokingRecipe from import data
  SmokingRecipe _buildSmokingRecipe() {
    // Build directions from selected
    final directions = <String>[];
    for (final index in _selectedDirectionIndices.toList()..sort()) {
      if (index < widget.importResult.rawDirections.length) {
        directions.add(widget.importResult.rawDirections[index]);
      }
    }
    
    // Try to detect wood type from ingredients or notes
    String woodType = 'Hickory'; // Default
    final allText = [...directions, widget.importResult.notes ?? ''].join(' ').toLowerCase();
    for (final wood in WoodSuggestions.common) {
      if (allText.contains(wood.toLowerCase())) {
        woodType = wood;
        break;
      }
    }
    
    // Try to detect temperature from directions or notes
    String temperature = '';
    final tempMatch = RegExp(r'(\d{2,3})\s*[°]?\s*[FCfc]').firstMatch(allText);
    if (tempMatch != null) {
      temperature = tempMatch.group(0) ?? '';
    }
    
    // Convert ingredients to seasonings
    final seasonings = <SmokingSeasoning>[];
    for (final index in _selectedIngredientIndices.toList()..sort()) {
      if (index < _sanitizedIngredients.length) {
        final rawIngredient = _sanitizedIngredients[index];
        if (rawIngredient.name.isNotEmpty) {
          seasonings.add(SmokingSeasoning.create(
            name: rawIngredient.name,
            amount: rawIngredient.amount,
            unit: rawIngredient.unit,
          ));
        }
      }
    }

    // Get the header image - first from imagePaths, fallback to imageUrl
    String? headerImage;
    List<String>? stepImages;
    if (widget.importResult.imagePaths != null &&
        widget.importResult.imagePaths!.isNotEmpty) {
      headerImage = widget.importResult.imagePaths!.first;
      if (widget.importResult.imagePaths!.length > 1) {
        stepImages = widget.importResult.imagePaths!.sublist(1);
      }
    } else if (widget.importResult.imageUrl != null) {
      headerImage = widget.importResult.imageUrl;
    }

    return SmokingRecipe.create(
      uuid: const Uuid().v4(),
      name: _nameController.text.trim().isEmpty
          ? 'Untitled Recipe'
          : _nameController.text.trim(),
      item: _nameController.text.trim(), // Use recipe name as item being smoked
      temperature: temperature,
      time: _timeController.text.trim().isEmpty ? '' : _timeController.text.trim(),
      wood: woodType,
      seasonings: seasonings,
      directions: directions,
      notes: widget.importResult.notes,
      headerImage: headerImage,
      stepImages: stepImages,
      source: SmokingSource.imported,
    );
  }
  
  /// Build ingredient notes string combining preparation and alternative
  String _buildIngredientNotes(RawIngredientData ingredient) {
    final parts = <String>[];
    if (ingredient.preparation != null && ingredient.preparation!.isNotEmpty) {
      parts.add(ingredient.preparation!);
    }
    if (ingredient.alternative != null && ingredient.alternative!.isNotEmpty) {
      parts.add('alt: ${ingredient.alternative}');
    }
    return parts.join('; ');
  }

  /// Build a Pizza from import data
  Pizza _buildPizzaRecipe() {
    // Try to detect base sauce from ingredients
    PizzaBase base = PizzaBase.marinara; // Default
    final allIngredients = _sanitizedIngredients.map((i) => i.name.toLowerCase()).join(' ');
    if (allIngredients.contains('pesto')) {
      base = PizzaBase.pesto;
    } else if (allIngredients.contains('cream') || allIngredients.contains('alfredo')) {
      base = PizzaBase.cream;
    } else if (allIngredients.contains('bbq') || allIngredients.contains('barbecue')) {
      base = PizzaBase.bbq;
    } else if (allIngredients.contains('buffalo')) {
      base = PizzaBase.buffalo;
    } else if (allIngredients.contains('garlic') && allIngredients.contains('butter')) {
      base = PizzaBase.garlic;
    } else if (allIngredients.contains('oil') || allIngredients.contains('olive')) {
      base = PizzaBase.oil;
    }
    
    // Separate cheeses, proteins, and vegetables
    final cheeses = <String>[];
    final proteins = <String>[];
    final vegetables = <String>[];
    const cheeseKeywords = ['mozzarella', 'parmesan', 'cheddar', 'gouda', 'provolone', 
        'ricotta', 'gorgonzola', 'feta', 'goat cheese', 'burrata', 'fontina', 'asiago',
        'pecorino', 'gruyere', 'brie', 'cheese'];
    const proteinKeywords = ['pepperoni', 'sausage', 'bacon', 'ham', 'prosciutto', 
        'salami', 'chicken', 'beef', 'pork', 'anchov', 'shrimp', 'meat', 'turkey',
        'chorizo', 'pancetta', 'nduja', 'capicola', 'egg'];
    
    for (final index in _selectedIngredientIndices.toList()..sort()) {
      if (index < _sanitizedIngredients.length) {
        final rawIngredient = _sanitizedIngredients[index];
        if (rawIngredient.name.isEmpty) continue;
        
        final lower = rawIngredient.name.toLowerCase();
        final isCheese = cheeseKeywords.any((c) => lower.contains(c));
        final isProtein = proteinKeywords.any((p) => lower.contains(p));
        
        if (isCheese) {
          cheeses.add(rawIngredient.name);
        } else if (isProtein) {
          proteins.add(rawIngredient.name);
        } else {
          // Skip base sauce ingredients, treat rest as vegetables
          if (!lower.contains('sauce') && !lower.contains('dough') && 
              !lower.contains('flour') && !lower.contains('yeast')) {
            vegetables.add(rawIngredient.name);
          }
        }
      }
    }

    return Pizza.create(
      uuid: const Uuid().v4(),
      name: _nameController.text.trim().isEmpty
          ? 'Untitled Pizza'
          : _nameController.text.trim(),
      base: base,
      cheeses: cheeses,
      proteins: proteins,
      vegetables: vegetables,
      notes: widget.importResult.notes,
      imageUrl: widget.importResult.imageUrl,
      source: PizzaSource.imported,
    );
  }

  Future<void> _saveRecipe() async {
    if (_nameController.text.trim().isEmpty) {
      MemoixSnackBar.showError('Please enter a recipe name');
      return;
    }

    // Save to appropriate repository based on course type
    String savedName;
    Widget Function(BuildContext) detailScreenBuilder;
    
    if (_isModernistCourse) {
      final recipe = _buildModernistRecipe();
      await ref.read(modernistRepositoryProvider).save(recipe);
      savedName = recipe.name;
      final savedId = recipe.id; // Modernist uses int id
      detailScreenBuilder = (_) => ModernistDetailScreen(recipeId: savedId);
    } else if (_isSmokingCourse) {
      final recipe = _buildSmokingRecipe();
      await ref.read(smokingRepositoryProvider).saveRecipe(recipe);
      savedName = recipe.name;
      final savedId = recipe.uuid; // Smoking uses String uuid
      detailScreenBuilder = (_) => SmokingDetailScreen(recipeId: savedId);
    } else if (_isPizzasCourse) {
      final recipe = _buildPizzaRecipe();
      await ref.read(pizzaRepositoryProvider).savePizza(recipe);
      savedName = recipe.name;
      final savedId = recipe.uuid; // Pizza uses String uuid
      detailScreenBuilder = (_) => PizzaDetailScreen(pizzaId: savedId);
    } else {
      final recipe = _buildRecipe();
      await ref.read(recipeRepositoryProvider).saveRecipe(recipe);
      savedName = recipe.name;
      final savedId = recipe.uuid; // Recipe uses String uuid
      detailScreenBuilder = (_) => RecipeDetailScreen(recipeId: savedId);
    }

    if (mounted) {
      // Capture navigator before navigating
      final navigator = Navigator.of(context);
      
      navigator.popUntil((route) => route.isFirst);
      
      // Use MemoixSnackBar for snackbar after navigation
      MemoixSnackBar.showSaved(
        itemName: savedName,
        actionLabel: 'View',
        onView: () {
          navigator.push(
            MaterialPageRoute(builder: detailScreenBuilder),
          );
        },
        duration: const Duration(seconds: 4),
      );
    }
  }
}

/// Bottom sheet with searchable cuisine list grouped by continent
class _CuisinePickerSheet extends StatefulWidget {
  final String? selectedCuisine;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _CuisinePickerSheet({
    required this.selectedCuisine,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_CuisinePickerSheet> createState() => _CuisinePickerSheetState();
}

class _CuisinePickerSheetState extends State<_CuisinePickerSheet> {
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
    final theme = Theme.of(context);
    
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
                  'Select Cuisine',
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
                hintText: 'Search cuisines...',
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
            Icon(Icons.search_off, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'No cuisines found for "$_searchQuery"',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
        final isSelected = widget.selectedCuisine == cuisine.code;
        return ListTile(
          leading: Text(cuisine.flag, style: const TextStyle(fontSize: 24)),
          title: Text(cuisine.name),
          subtitle: Text(cuisine.continent, 
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),),
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
              final isSelected = widget.selectedCuisine == cuisine.code;
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
