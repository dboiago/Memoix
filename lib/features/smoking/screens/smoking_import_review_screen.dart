import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/smoking_recipe.dart';
import '../models/smoking_import_result.dart';
import '../repository/smoking_repository.dart';
import 'smoking_edit_screen.dart';

/// Screen for reviewing and mapping imported smoking recipe data
/// Shown when confidence is below threshold or user wants to review
class SmokingImportReviewScreen extends ConsumerStatefulWidget {
  final SmokingImportResult importResult;

  const SmokingImportReviewScreen({
    super.key,
    required this.importResult,
  });

  @override
  ConsumerState<SmokingImportReviewScreen> createState() =>
      _SmokingImportReviewScreenState();
}

class _SmokingImportReviewScreenState
    extends ConsumerState<SmokingImportReviewScreen> {
  late TextEditingController _nameController;
  late TextEditingController _temperatureController;
  late TextEditingController _timeController;
  late TextEditingController _woodController;

  // Track which raw ingredients user has marked as seasonings
  late Set<int> _selectedSeasoningIndices;

  // Track selected values from detected options
  String? _selectedTemperature;
  String? _selectedWood;

  @override
  void initState() {
    super.initState();
    final result = widget.importResult;

    _nameController = TextEditingController(text: result.name ?? '');
    _temperatureController =
        TextEditingController(text: result.temperature ?? '');
    _timeController = TextEditingController(text: result.time ?? '');
    _woodController = TextEditingController(text: result.wood ?? '');

    _selectedTemperature = result.temperature;
    _selectedWood = result.wood;

    // Pre-select ingredients that were auto-classified as seasonings
    _selectedSeasoningIndices = {};
    for (int i = 0; i < result.rawIngredients.length; i++) {
      if (result.rawIngredients[i].isSeasoning) {
        _selectedSeasoningIndices.add(i);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _temperatureController.dispose();
    _timeController.dispose();
    _woodController.dispose();
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

          // Recipe name (usually high confidence)
          _buildSectionTitle(theme, 'Recipe Name', Icons.restaurant,
              confidence: result.nameConfidence),
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

          // Temperature selection
          _buildSectionTitle(theme, 'Temperature', Icons.thermostat,
              confidence: result.temperatureConfidence),
          const SizedBox(height: 8),
          if (result.detectedTemperatures.isNotEmpty) ...[
            Text('Detected temperatures (tap to select):',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.detectedTemperatures.map((temp) {
                final isSelected = _selectedTemperature == temp;
                return ChoiceChip(
                  label: Text(temp),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedTemperature = temp;
                      _temperatureController.text = temp;
                    });
                  },
                  selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _temperatureController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g., 225°F',
              helperText: 'Or enter manually',
            ),
          ),
          const SizedBox(height: 24),

          // Time
          _buildSectionTitle(theme, 'Cooking Time', Icons.timer,
              confidence: result.timeConfidence),
          const SizedBox(height: 8),
          TextField(
            controller: _timeController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g., 8-12 hrs',
            ),
          ),
          const SizedBox(height: 24),

          // Wood selection
          _buildSectionTitle(theme, 'Wood Type', Icons.park,
              confidence: result.woodConfidence),
          const SizedBox(height: 8),
          if (result.detectedWoods.isNotEmpty) ...[
            Text('Detected wood types (tap to select):',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.detectedWoods.map((wood) {
                final isSelected = _selectedWood == wood;
                return ChoiceChip(
                  label: Text(wood),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedWood = wood;
                      _woodController.text = wood;
                    });
                  },
                  selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          Autocomplete<String>(
            initialValue: TextEditingValue(text: _woodController.text),
            optionsBuilder: (textEditingValue) {
              return WoodSuggestions.getSuggestions(textEditingValue.text);
            },
            onSelected: (selection) {
              _woodController.text = selection;
            },
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              controller.addListener(() {
                _woodController.text = controller.text;
              });
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Hickory, Cherry',
                  helperText: 'Or enter manually',
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Ingredients mapping
          _buildSectionTitle(theme, 'Ingredients → Seasonings', Icons.grain,
              confidence: result.seasoningsConfidence),
          const SizedBox(height: 8),
          Text(
            'Select which ingredients are seasonings/rub:',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          _buildIngredientsList(theme, result),
          const SizedBox(height: 24),

          // Directions preview
          _buildSectionTitle(
              theme, 'Directions', Icons.format_list_numbered,
              confidence: result.directionsConfidence),
          const SizedBox(height: 8),
          if (result.directions.isEmpty)
            Card(
              color: theme.colorScheme.errorContainer.withOpacity(0.3),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No directions found. You can add them after saving.'),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${result.directions.length} steps imported',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...result.directions.take(3).map((step) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• ${step.length > 80 ? '${step.substring(0, 80)}...' : step}',
                            style: theme.textTheme.bodySmall,
                          ),
                        )),
                    if (result.directions.length > 3)
                      Text(
                        '... and ${result.directions.length - 3} more steps',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 32),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _openInEditScreen(),
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

  Widget _buildConfidenceCard(ThemeData theme, SmokingImportResult result) {
    final confidence = result.overallConfidence;
    final Color cardColor;
    final IconData icon;
    final String message;

    if (confidence >= 0.8) {
      cardColor = Colors.green.withOpacity(0.1);
      icon = Icons.check_circle;
      message = 'High confidence import! Review and save.';
    } else if (confidence >= 0.5) {
      cardColor = Colors.orange.withOpacity(0.1);
      icon = Icons.warning;
      message = 'Some fields need your attention.';
    } else {
      cardColor = Colors.red.withOpacity(0.1);
      icon = Icons.error_outline;
      message = 'Low confidence. Please review all fields.';
    }

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: confidence,
                    backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    ThemeData theme,
    String title,
    IconData icon, {
    double confidence = 1.0,
  }) {
    final Color indicatorColor;
    if (confidence >= 0.7) {
      indicatorColor = Colors.green;
    } else if (confidence >= 0.4) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = Colors.red;
    }

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
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
          confidence >= 0.7
              ? 'Good'
              : confidence >= 0.4
                  ? 'Review'
                  : 'Needs input',
          style: theme.textTheme.bodySmall?.copyWith(
            color: indicatorColor,
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsList(ThemeData theme, SmokingImportResult result) {
    if (result.rawIngredients.isEmpty) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('No ingredients found in the recipe.'),
        ),
      );
    }

    return Card(
      child: Column(
        children: result.rawIngredients.asMap().entries.map((entry) {
          final index = entry.key;
          final ingredient = entry.value;
          final isSelected = _selectedSeasoningIndices.contains(index);

          // Color-code by type
          Color? leadingColor;
          String? typeLabel;
          if (ingredient.isMainProtein) {
            leadingColor = Colors.red.withOpacity(0.3);
            typeLabel = 'Meat';
          } else if (ingredient.isLiquid) {
            leadingColor = Colors.blue.withOpacity(0.3);
            typeLabel = 'Liquid';
          } else if (ingredient.isSeasoning) {
            leadingColor = Colors.green.withOpacity(0.3);
            typeLabel = 'Seasoning';
          }

          return CheckboxListTile(
            value: isSelected,
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  _selectedSeasoningIndices.add(index);
                } else {
                  _selectedSeasoningIndices.remove(index);
                }
              });
            },
            title: Text(
              ingredient.name,
              style: TextStyle(
                decoration:
                    ingredient.isMainProtein ? TextDecoration.lineThrough : null,
                color: ingredient.isMainProtein
                    ? theme.colorScheme.outline
                    : null,
              ),
            ),
            subtitle: Row(
              children: [
                if (ingredient.amount != null)
                  Text(
                    ingredient.amount!,
                    style: theme.textTheme.bodySmall,
                  ),
                if (typeLabel != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: leadingColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      typeLabel,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ],
            ),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
          );
        }).toList(),
      ),
    );
  }

  void _openInEditScreen() {
    final recipe = _buildRecipe();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SmokingEditScreen(importedRecipe: recipe),
      ),
    );
  }

  SmokingRecipe _buildRecipe() {
    // Build seasonings from selected ingredients
    final seasonings = <SmokingSeasoning>[];
    for (final index in _selectedSeasoningIndices) {
      if (index < widget.importResult.rawIngredients.length) {
        seasonings.add(widget.importResult.rawIngredients[index].toSeasoning());
      }
    }

    return SmokingRecipe.create(
      uuid: const Uuid().v4(),
      name: _nameController.text.trim(),
      temperature: _temperatureController.text.trim().isEmpty
          ? '225°F'
          : _temperatureController.text.trim(),
      time: _timeController.text.trim(),
      wood: _woodController.text.trim(),
      seasonings: seasonings,
      directions: widget.importResult.directions,
      notes: widget.importResult.notes,
      imageUrl: widget.importResult.imageUrl,
      source: SmokingSource.imported,
    );
  }

  Future<void> _saveRecipe() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipe name')),
      );
      return;
    }

    final recipe = _buildRecipe();
    await ref.read(smokingRepositoryProvider).saveRecipe(recipe);

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${recipe.name}')),
      );
    }
  }
}
