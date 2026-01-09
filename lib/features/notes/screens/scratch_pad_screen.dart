import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/ingredient_parser.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
import '../models/scratch_pad.dart';
import '../repository/scratch_pad_repository.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import 'draft_editor_screen.dart';

/// Scratch Pad screen for quick notes and temporary recipes
class ScratchPadScreen extends ConsumerStatefulWidget {
  /// Optional UUID of draft to open immediately
  final String? draftToEdit;
  
  const ScratchPadScreen({super.key, this.draftToEdit});

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
    // If opening a specific draft, start on the Recipe Drafts tab
    _tabController = TabController(
      length: 2, 
      vsync: this,
      initialIndex: widget.draftToEdit != null ? 1 : 0,
    );
    _tabController.addListener(() {
      // Rebuild when tab changes to update FAB visibility
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _notesController = TextEditingController();
    
    // Auto-open draft editor if UUID was provided
    if (widget.draftToEdit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openDraftByUuid(widget.draftToEdit!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(quickNotesProvider);
    final draftsAsync = ref.watch(recipeDraftsProvider);

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
          notesAsync.when(
            data: (notes) {
              // Sync text controller with provider
              if (_notesController.text != notes) {
                _notesController.text = notes;
              }
              return _QuickNotesTab(
                controller: _notesController,
                onChanged: (value) {
                  ref.read(scratchPadRepositoryProvider).saveQuickNotes(value);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          // Recipe Drafts Tab
          draftsAsync.when(
            data: (drafts) => _RecipeDraftsTab(
              drafts: drafts,
              onAddDraft: () => _addNewDraft(context, ref),
              onEditDraft: (draft) => _editDraft(context, ref, draft),
              onDeleteDraft: (draft) => _deleteDraft(ref, draft),
              onConvertToRecipe: (draft) => _convertToRecipe(context, ref, draft),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
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

  Future<void> _addNewDraft(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(scratchPadRepositoryProvider);
    final drafts = await repo.getAllDrafts();
    final draft = await repo.createDraft(name: 'New Recipe ${drafts.length + 1}');
    if (context.mounted) {
      _editDraft(context, ref, draft);
    }
  }

  void _openDraftByUuid(String uuid) async {
    // Add a small delay to ensure provider has refreshed with new draft
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) return;
    
    final draftsAsync = ref.read(recipeDraftsProvider);
    draftsAsync.whenData((drafts) {
      final draft = drafts.where((d) => d.uuid == uuid).firstOrNull;
      if (draft != null && mounted) {
        // Open the editor directly (tab is already set to 1 in initState)
        _editDraft(context, ref, draft);
      }
    });
  }
  
  void _editDraft(BuildContext context, WidgetRef ref, RecipeDraft draft) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // Use the new external screen
        builder: (_) => DraftEditorScreen(
          initialDraft: draft,
        ),
      ),
    ).then((_) => ref.refresh(recipeDraftsProvider)); 
  }
  
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DraftEditorScreen(
            initialDraft: draft,
          ),
        ),
      ).then((_) => ref.refresh(recipeDraftsProvider)); // Refresh list on return

  Future<void> _deleteDraft(WidgetRef ref, RecipeDraft draft) async {
    await ref.read(scratchPadRepositoryProvider).deleteDraft(draft.uuid);
  }

  void _convertToRecipe(BuildContext context, WidgetRef ref, RecipeDraft draft) {
    // Parse ingredients using the shared IngredientParser (same as URL/OCR imports)
    final ingredientLines = draft.ingredients
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    
    final ingredients = <Ingredient>[];
    String? currentSection;
    
    for (final line in ingredientLines) {
      final parsed = IngredientParser.parse(line);
      
      // Handle section headers
      if (parsed.isSection) {
        currentSection = parsed.sectionName;
        continue;
      }
      
      // Skip lines that don't look like ingredients
      if (!parsed.looksLikeIngredient) continue;
      
      final ingredient = Ingredient()
        ..name = parsed.name
        ..amount = parsed.amount
        ..unit = parsed.unit
        ..preparation = parsed.preparation
        ..section = currentSection;
      
      ingredients.add(ingredient);
    }
    
    // Parse directions from text (split by numbered steps, blank lines, or sentence endings)
    final directionsText = draft.directions.trim();
    List<String> directions;
    
    // Try numbered step format first (1. Step one, 2. Step two)
    final numberedSteps = RegExp(r'^\d+[.)]\s*', multiLine: true);
    if (numberedSteps.hasMatch(directionsText)) {
      directions = directionsText
          .split(numberedSteps)
          .where((step) => step.trim().isNotEmpty)
          .map((step) => step.trim())
          .toList();
    } else {
      // Fall back to blank line separation
      directions = directionsText
          .split(RegExp(r'\n\s*\n'))
          .where((step) => step.trim().isNotEmpty)
          .map((step) => step.trim())
          .toList();
    }
    
    // Create Recipe object from draft
    final recipe = Recipe()
      ..uuid = const Uuid().v4()
      ..name = draft.name
      ..course = 'mains'
      ..serves = draft.serves
      ..time = draft.time
      ..ingredients = ingredients
      ..directions = directions
      ..comments = draft.comments.isNotEmpty ? draft.comments : null
      ..imageUrl = draft.imagePath
      ..source = RecipeSource.personal
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    
    // Navigate to recipe edit screen - draft is NOT deleted here
    // User can keep it or delete manually
    // Use Navigator to await returning, then prompt for deletion
    Future<void>(() async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeEditScreen(importedRecipe: recipe),
        ),
      );
      if (context.mounted) {
        _askDeleteDraft(context, ref, draft);
      }
    });
  }

  void _askDeleteDraft(BuildContext context, WidgetRef ref, RecipeDraft draft) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Draft?'),
        content: const Text(
          'Do you want to remove this draft from the scratch pad?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Draft'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(scratchPadRepositoryProvider).deleteDraft(draft.uuid);
            },
            child: const Text('Delete Draft'),
          ),
        ],
      ),
    );
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
              Expanded(
                child: Text(
                  'Jot down quick notes, ingredients to buy, or cooking ideas',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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

class _RecipeDraftsTab extends ConsumerStatefulWidget {
  final List<RecipeDraft> drafts;
  final VoidCallback onAddDraft;
  final ValueChanged<RecipeDraft> onEditDraft;
  final ValueChanged<RecipeDraft> onDeleteDraft;
  final ValueChanged<RecipeDraft> onConvertToRecipe;

  const _RecipeDraftsTab({
    required this.drafts,
    required this.onAddDraft,
    required this.onEditDraft,
    required this.onDeleteDraft,
    required this.onConvertToRecipe,
  });

  @override
  ConsumerState<_RecipeDraftsTab> createState() => _RecipeDraftsTabState();
}

class _RecipeDraftsTabState extends ConsumerState<_RecipeDraftsTab> {
  static const _undoDuration = Duration(seconds: 4);

  void _startDeleteTimer(String uuid) {
    final service = ref.read(draftDeletionServiceProvider);
    
    // Schedule delete at service level (persists across widget rebuilds)
    service.scheduleDraftDelete(
      uuid: uuid,
      undoDuration: _undoDuration,
      onComplete: () {
        // Refresh the UI after delete completes (only if still mounted)
        if (mounted) {
          ref.invalidate(recipeDraftsProvider);
        }
      },
    );
    
    // Trigger rebuild to show pending state
    setState(() {});
  }

  void _undoDelete(String uuid) {
    ref.read(draftDeletionServiceProvider).cancelPendingDelete(uuid);
    setState(() {});
  }

  bool _isPendingDelete(String uuid) {
    return ref.read(draftDeletionServiceProvider).isPendingDelete(uuid);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.drafts.isEmpty) {
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
      itemCount: widget.drafts.length,
      itemBuilder: (context, index) {
        final draft = widget.drafts[index];
        
        // Show inline undo placeholder if pending delete
        if (_isPendingDelete(draft.uuid)) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 72,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${draft.name} deleted',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _undoDelete(draft.uuid),
                    child: Text(
                      'UNDO',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return Dismissible(
          key: Key('draft_${draft.uuid}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.delete, color: theme.colorScheme.secondary),
          ),
          confirmDismiss: (direction) async {
            // Start inline undo timer instead of immediate delete
            _startDeleteTimer(draft.uuid);
            return false; // Don't dismiss - show placeholder instead
          },
          child: Card(
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
                      widget.onEditDraft(draft);
                      break;
                    case 'convert':
                      widget.onConvertToRecipe(draft);
                      break;
                    case 'delete':
                      // Use inline undo instead of immediate delete
                      _startDeleteTimer(draft.uuid);
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
            onTap: () => widget.onEditDraft(draft),
          ),
        ),
        );
      },
    );
  }
}


