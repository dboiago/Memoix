import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/routes/router.dart';
import '../../recipes/models/recipe.dart';

/// Provider to store scratch pad notes
final scratchPadNotesProvider = StateProvider<String>((ref) => '');

/// Provider to store temporary recipe drafts
final tempRecipeDraftsProvider = StateProvider<List<TempRecipeDraft>>((ref) => []);

/// Temporary recipe draft model
class TempRecipeDraft {
  final String id;
  final String name;
  final String? imagePath;
  final String? serves;
  final String? time;
  final String ingredients;
  final String directions;
  final String comments;
  final DateTime createdAt;

  TempRecipeDraft({
    required this.id,
    required this.name,
    this.imagePath,
    this.serves,
    this.time,
    this.ingredients = '',
    this.directions = '',
    this.comments = '',
    required this.createdAt,
  });

  TempRecipeDraft copyWith({
    String? name,
    String? imagePath,
    String? serves,
    String? time,
    String? ingredients,
    String? directions,
    String? comments,
    bool clearImage = false,
  }) {
    return TempRecipeDraft(
      id: id,
      name: name ?? this.name,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      serves: serves ?? this.serves,
      time: time ?? this.time,
      ingredients: ingredients ?? this.ingredients,
      directions: directions ?? this.directions,
      comments: comments ?? this.comments,
      createdAt: createdAt,
    );
  }
}

/// Scratch Pad screen for quick notes and temporary recipes
class ScratchPadScreen extends ConsumerStatefulWidget {
  const ScratchPadScreen({super.key});

  @override
  ConsumerState<ScratchPadScreen> createState() => _ScratchPadScreenState();
}

class _ScratchPadScreenState extends ConsumerState<ScratchPadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Rebuild when tab changes to update FAB visibility
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = ref.watch(scratchPadNotesProvider);
    final drafts = ref.watch(tempRecipeDraftsProvider);

    // Sync text controller with provider
    if (_notesController.text != notes) {
      _notesController.text = notes;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scratch Pad'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note), text: 'Quick Notes'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Recipe Drafts'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Quick Notes Tab
          _QuickNotesTab(
            controller: _notesController,
            onChanged: (value) {
              ref.read(scratchPadNotesProvider.notifier).state = value;
            },
          ),
          // Recipe Drafts Tab
          _RecipeDraftsTab(
            drafts: drafts,
            onAddDraft: () => _addNewDraft(context, ref),
            onEditDraft: (draft) => _editDraft(context, ref, draft),
            onDeleteDraft: (draft) => _deleteDraft(ref, draft),
            onConvertToRecipe: (draft) => _convertToRecipe(context, ref, draft),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _addNewDraft(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New Draft'),
            )
          : null,
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scratch Pad'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Notes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Jot down ingredients, cooking tips, or anything you want to remember while cooking.',
            ),
            SizedBox(height: 16),
            Text(
              'Recipe Drafts',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              'Start drafting a recipe idea. When you\'re ready, convert it to a full recipe.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _addNewDraft(BuildContext context, WidgetRef ref) {
    // Open RecipeEditScreen directly for a new recipe - same as adding from Mains
    AppRoutes.toRecipeEdit(context);
  }

  void _editDraft(BuildContext context, WidgetRef ref, TempRecipeDraft draft) {
    // Convert draft to Recipe and open in RecipeEditScreen
    _convertToRecipe(context, ref, draft);
  }

  void _deleteDraft(WidgetRef ref, TempRecipeDraft draft) {
    final drafts = ref.read(tempRecipeDraftsProvider);
    ref.read(tempRecipeDraftsProvider.notifier).state =
        drafts.where((d) => d.id != draft.id).toList();
  }

  void _convertToRecipe(BuildContext context, WidgetRef ref, TempRecipeDraft draft) {
    // Parse ingredients from text (one per line)
    final ingredientLines = draft.ingredients
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    
    final ingredients = ingredientLines.map((line) {
      // Try to parse amount and unit from the beginning of the line (e.g., "1 cup flour")
      final text = line.trim();
      // Capture an amount token and optional unit, then the name
      final match = RegExp(
        r'^(?<amount>[\d\s\/\.-]+)?\s*(?<unit>cup|cups|tbsp|tsp|oz|lb|lbs|g|kg|ml|l|can|cans|bunch|clove|cloves)?\s*(?<name>.+)$',
        caseSensitive: false,
      ).firstMatch(text);

      final ingredient = Ingredient();
      if (match != null) {
        final amt = match.namedGroup('amount')?.trim();
        final unit = match.namedGroup('unit')?.trim();
        final name = match.namedGroup('name')?.trim();

        ingredient.name = (name == null || name.isEmpty) ? text : name;
        if (amt != null && amt.isNotEmpty) {
          ingredient.amount = amt;
        }
        if (unit != null && unit.isNotEmpty) {
          ingredient.unit = unit;
        }
      } else {
        ingredient.name = text;
      }
      return ingredient;
    }).toList();
    
    // Parse directions from text (split by blank lines)
    final directions = draft.directions
        .split(RegExp(r'\n\s*\n'))
        .where((step) => step.trim().isNotEmpty)
        .map((step) => step.trim())
        .toList();
    
    // Create Recipe object from draft
    final recipe = Recipe()
      ..uuid = const Uuid().v4()
      ..name = draft.name
      ..course = 'mains'
      ..serves = draft.serves
      ..time = draft.time
      ..ingredients = ingredients
      ..directions = directions
      ..notes = draft.comments.isNotEmpty ? draft.comments : null
      ..imageUrl = draft.imagePath
      ..source = RecipeSource.personal
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    
    // Remove from drafts since it's being converted
    final drafts = ref.read(tempRecipeDraftsProvider);
    ref.read(tempRecipeDraftsProvider.notifier).state =
        drafts.where((d) => d.id != draft.id).toList();
    
    // Navigate to recipe edit screen with pre-filled data
    AppRoutes.toRecipeEdit(context, importedRecipe: recipe);
  }
}

class _QuickNotesTab extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _QuickNotesTab({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Jot down quick notes, ingredients to buy, or cooking ideas',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'Start typing...\n\n• Grocery list\n• Recipe ideas\n• Cooking tips\n• Measurements',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLowest,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecipeDraftsTab extends StatelessWidget {
  final List<TempRecipeDraft> drafts;
  final VoidCallback onAddDraft;
  final ValueChanged<TempRecipeDraft> onEditDraft;
  final ValueChanged<TempRecipeDraft> onDeleteDraft;
  final ValueChanged<TempRecipeDraft> onConvertToRecipe;

  const _RecipeDraftsTab({
    required this.drafts,
    required this.onAddDraft,
    required this.onEditDraft,
    required this.onDeleteDraft,
    required this.onConvertToRecipe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (drafts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withAlpha((0.5 * 255).round()),
            ),
            const SizedBox(height: 16),
            Text(
              'No recipe drafts yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to start a new recipe idea',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha((0.7 * 255).round()),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: drafts.length,
      itemBuilder: (context, index) {
        final draft = drafts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: draft.imagePath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(
                            draft.imagePath!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(draft.imagePath!),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                  )
                : CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.restaurant_menu,
                      color: theme.colorScheme.primary,
                    ),
                  ),
            title: Text(draft.name),
            subtitle: Text(
              draft.ingredients.isEmpty
                  ? 'No ingredients yet'
                  : draft.ingredients.split('\n').take(2).join(', ') +
                      (draft.ingredients.split('\n').length > 2 ? '...' : ''),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEditDraft(draft);
                    break;
                  case 'convert':
                    onConvertToRecipe(draft);
                    break;
                  case 'delete':
                    onDeleteDraft(draft);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'convert',
                  child: ListTile(
                    leading: Icon(Icons.restaurant_menu),
                    title: Text('Convert to Recipe'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete),
                    title: Text('Delete'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            onTap: () => onEditDraft(draft),
          ),
        );
      },
    );
  }
}
