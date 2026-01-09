import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/ingredient_parser.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
import '../models/scratch_pad.dart';
import '../repository/scratch_pad_repository.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import 'draft_editor_screen.dart'; // Import the new external screen

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
    _tabController = TabController(
      length: 2, 
      vsync: this,
      initialIndex: widget.draftToEdit != null ? 1 : 0,
    );
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
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    
    final draftsAsync = ref.read(recipeDraftsProvider);
    draftsAsync.whenData((drafts) {
      final draft = drafts.where((d) => d.uuid == uuid).firstOrNull;
      if (draft != null && mounted) {
        _editDraft(context, ref, draft);
      }
    });
  }
  
  void _editDraft(BuildContext context, WidgetRef ref, RecipeDraft draft) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DraftEditorScreen(
          initialDraft: draft,
        ),
      ),
    ).then((_) => ref.refresh(recipeDraftsProvider));
  }

  Future<void> _deleteDraft(WidgetRef ref, RecipeDraft draft) async {
    await ref.read(scratchPadRepositoryProvider).deleteDraft(draft.uuid);
  }

  void _convertToRecipe(BuildContext context, WidgetRef ref, RecipeDraft draft) {
    // Navigate to editor directly; the DraftEditorScreen handles the conversion logic now
    // via its own internal "Convert" button. But if we need to convert from the list:
    
    // Create skeleton recipe
    final recipe = Recipe()
      ..uuid = const Uuid().v4()
      ..name = draft.name
      ..course = 'mains' // Default
      ..ingredients = [] // Populate if you want simple conversion
      ..directions = draft.directions.split('\n')
      ..source = RecipeSource.personal;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeEditScreen(importedRecipe: recipe),
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
              Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Jot down quick notes, ingredients to buy, or cooking ideas',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                hintText: 'Start typing...\n\n• Grocery list\n• Recipe ideas\n• Cooking tips',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLowest,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                controller.clear();
                onChanged('');
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
            ),
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
    service.scheduleDraftDelete(
      uuid: uuid,
      undoDuration: _undoDuration,
      onComplete: () {
        if (mounted) ref.invalidate(recipeDraftsProvider);
      },
    );
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
            Icon(Icons.receipt_long, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No recipe drafts yet', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.drafts.length,
      itemBuilder: (context, index) {
        final draft = widget.drafts[index];
        
        if (_isPendingDelete(draft.uuid)) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text('${draft.name} deleted'),
              trailing: TextButton(
                onPressed: () => _undoDelete(draft.uuid),
                child: const Text('UNDO'),
              ),
            ),
          );
        }
        
        return Dismissible(
          key: Key('draft_${draft.uuid}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            color: theme.colorScheme.errorContainer,
            child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
          ),
          confirmDismiss: (direction) async {
            _startDeleteTimer(draft.uuid);
            return false;
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: draft.imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(draft.imagePath!), width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image)),
                    )
                  : CircleAvatar(child: Icon(Icons.restaurant_menu, color: theme.colorScheme.primary)),
              title: Text(draft.name),
              subtitle: Text(
                draft.ingredients.isEmpty ? 'No ingredients' : draft.ingredients.split('\n').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => widget.onEditDraft(draft),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') _startDeleteTimer(draft.uuid);
                  if (value == 'edit') widget.onEditDraft(draft);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}