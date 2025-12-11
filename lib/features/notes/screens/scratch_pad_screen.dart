import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../recipes/models/recipe.dart';
import '../../../app/routes/router.dart';

/// Provider to store scratch pad notes
final scratchPadNotesProvider = StateProvider<String>((ref) => '');

/// Provider to store temporary recipe drafts
final tempRecipeDraftsProvider = StateProvider<List<TempRecipeDraft>>((ref) => []);

/// Temporary recipe draft model
class TempRecipeDraft {
  final String id;
  final String name;
  final String notes;
  final DateTime createdAt;

  TempRecipeDraft({
    required this.id,
    required this.name,
    required this.notes,
    required this.createdAt,
  });

  TempRecipeDraft copyWith({
    String? name,
    String? notes,
  }) {
    return TempRecipeDraft(
      id: id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'About Scratch Pad',
            onPressed: () => _showHelpDialog(context),
          ),
        ],
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
            onConvertToRecipe: (draft) => _convertToRecipe(context, draft),
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
    final drafts = ref.read(tempRecipeDraftsProvider);
    final newDraft = TempRecipeDraft(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'New Recipe ${drafts.length + 1}',
      notes: '',
      createdAt: DateTime.now(),
    );
    ref.read(tempRecipeDraftsProvider.notifier).state = [...drafts, newDraft];
    _editDraft(context, ref, newDraft);
  }

  void _editDraft(BuildContext context, WidgetRef ref, TempRecipeDraft draft) {
    showDialog(
      context: context,
      builder: (context) => _EditDraftDialog(
        draft: draft,
        onSave: (updatedDraft) {
          final drafts = ref.read(tempRecipeDraftsProvider);
          final index = drafts.indexWhere((d) => d.id == draft.id);
          if (index != -1) {
            final updated = [...drafts];
            updated[index] = updatedDraft;
            ref.read(tempRecipeDraftsProvider.notifier).state = updated;
          }
        },
      ),
    );
  }

  void _deleteDraft(WidgetRef ref, TempRecipeDraft draft) {
    final drafts = ref.read(tempRecipeDraftsProvider);
    ref.read(tempRecipeDraftsProvider.notifier).state =
        drafts.where((d) => d.id != draft.id).toList();
  }

  void _convertToRecipe(BuildContext context, TempRecipeDraft draft) {
    // Navigate to recipe edit screen with pre-filled data
    Navigator.pop(context);
    AppRoutes.toRecipeEdit(context);
    // Note: Could enhance RecipeEditScreen to accept initial notes
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
              'Tap the button below to start a new recipe idea',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withAlpha((0.7 * 255).round()),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddDraft,
              icon: const Icon(Icons.add),
              label: const Text('New Draft'),
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
            title: Text(draft.name),
            subtitle: Text(
              draft.notes.isEmpty
                  ? 'No notes yet'
                  : draft.notes.length > 50
                      ? '${draft.notes.substring(0, 50)}...'
                      : draft.notes,
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

class _EditDraftDialog extends StatefulWidget {
  final TempRecipeDraft draft;
  final ValueChanged<TempRecipeDraft> onSave;

  const _EditDraftDialog({
    required this.draft,
    required this.onSave,
  });

  @override
  State<_EditDraftDialog> createState() => _EditDraftDialogState();
}

class _EditDraftDialogState extends State<_EditDraftDialog> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.name);
    _notesController = TextEditingController(text: widget.draft.notes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Draft'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Recipe Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Ingredients, directions, ideas...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(widget.draft.copyWith(
              name: _nameController.text,
              notes: _notesController.text,
            ));
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
