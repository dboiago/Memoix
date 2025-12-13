import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../app/routes/router.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/models/ingredient.dart';

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
      createdAt: DateTime.now(),
    );
    ref.read(tempRecipeDraftsProvider.notifier).state = [...drafts, newDraft];
    // Open the draft editor
    _editDraft(context, ref, newDraft);
  }

  void _editDraft(BuildContext context, WidgetRef ref, TempRecipeDraft draft) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _EditDraftScreen(
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
          onConvertToRecipe: () {
            // Get the latest version of the draft
            final drafts = ref.read(tempRecipeDraftsProvider);
            final latestDraft = drafts.firstWhere(
              (d) => d.id == draft.id,
              orElse: () => draft,
            );
            // Remove from drafts since it's being converted
            ref.read(tempRecipeDraftsProvider.notifier).state =
                drafts.where((d) => d.id != draft.id).toList();
            // Convert to recipe
            _convertToRecipe(context, latestDraft);
          },
        ),
      ),
    );
  }

  void _deleteDraft(WidgetRef ref, TempRecipeDraft draft) {
    final drafts = ref.read(tempRecipeDraftsProvider);
    ref.read(tempRecipeDraftsProvider.notifier).state =
        drafts.where((d) => d.id != draft.id).toList();
  }

  void _convertToRecipe(BuildContext context, TempRecipeDraft draft) {
    // Parse ingredients from text (one per line)
    final ingredientLines = draft.ingredients
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    
    final ingredients = ingredientLines.map((line) {
      // Try to parse amount from beginning of line (e.g., "1 cup flour")
      final match = RegExp(r'^([\d\s\/\.-]+\s*(?:cup|cups|tbsp|tsp|oz|lb|lbs|g|kg|ml|l|can|cans|bunch|clove|cloves)?)\s*(.+)$', caseSensitive: false)
          .firstMatch(line.trim());
      
      if (match != null) {
        return Ingredient()
          ..name = match.group(2)?.trim() ?? line.trim()
          ..amount = double.tryParse(match.group(1)?.trim().split(RegExp(r'\s+')).first ?? '') ?? 1.0
          ..unit = match.group(1)?.trim().split(RegExp(r'\s+')).skip(1).join(' ') ?? '';
      }
      
      return Ingredient()
        ..name = line.trim()
        ..amount = 1.0
        ..unit = '';
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
      ..serves = draft.serves
      ..time = draft.time
      ..ingredients = ingredients
      ..directions = directions
      ..notes = draft.comments.isNotEmpty ? draft.comments : null
      ..imageUrl = draft.imagePath
      ..source = RecipeSource.personal
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    
    // Navigate to recipe edit screen with pre-filled data
    Navigator.pop(context);
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

/// Screen for editing a recipe draft
/// Has Save (keeps as draft), Back (discard changes), and Convert to Recipe options
class _EditDraftScreen extends StatefulWidget {
  final TempRecipeDraft draft;
  final ValueChanged<TempRecipeDraft> onSave;
  final VoidCallback onConvertToRecipe;

  const _EditDraftScreen({
    required this.draft,
    required this.onSave,
    required this.onConvertToRecipe,
  });

  @override
  State<_EditDraftScreen> createState() => _EditDraftScreenState();
}

class _EditDraftScreenState extends State<_EditDraftScreen> {
  late TextEditingController _nameController;
  late TextEditingController _servesController;
  late TextEditingController _timeController;
  late TextEditingController _ingredientsController;
  late TextEditingController _directionsController;
  late TextEditingController _commentsController;
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.name);
    _servesController = TextEditingController(text: widget.draft.serves ?? '');
    _timeController = TextEditingController(text: widget.draft.time ?? '');
    _ingredientsController = TextEditingController(text: widget.draft.ingredients);
    _directionsController = TextEditingController(text: widget.draft.directions);
    _commentsController = TextEditingController(text: widget.draft.comments);
    _imagePath = widget.draft.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servesController.dispose();
    _timeController.dispose();
    _ingredientsController.dispose();
    _directionsController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _imagePath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _imagePath = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  TempRecipeDraft _buildUpdatedDraft() {
    return widget.draft.copyWith(
      name: _nameController.text,
      imagePath: _imagePath,
      serves: _servesController.text.isEmpty ? null : _servesController.text,
      time: _timeController.text.isEmpty ? null : _timeController.text,
      ingredients: _ingredientsController.text,
      directions: _directionsController.text,
      comments: _commentsController.text,
      clearImage: _imagePath == null && widget.draft.imagePath != null,
    );
  }

  void _save() {
    widget.onSave(_buildUpdatedDraft());
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft saved')),
    );
  }

  void _convertToRecipe() {
    // Save the current state first
    widget.onSave(_buildUpdatedDraft());
    Navigator.pop(context);
    // Then trigger conversion
    widget.onConvertToRecipe();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Draft'),
        actions: [
          // Convert to Recipe button
          TextButton.icon(
            onPressed: _convertToRecipe,
            icon: const Icon(Icons.restaurant_menu),
            label: const Text('Convert'),
          ),
          // Save button
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, 
                    size: 20, 
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Save keeps this as a draft. Use "Convert" when ready to make it a full recipe.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // Image picker
            Center(
              child: GestureDetector(
                onTap: _showImagePicker,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withAlpha(100),
                    ),
                  ),
                  child: _imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? Image.network(
                                  _imagePath!,
                                  fit: BoxFit.cover,
                                  width: 150,
                                  height: 150,
                                )
                              : Image.file(
                                  File(_imagePath!),
                                  fit: BoxFit.cover,
                                  width: 150,
                                  height: 150,
                                ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 40,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add Photo',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Recipe name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Recipe Name *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            // Serves and Time (optional)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _servesController,
                    decoration: const InputDecoration(
                      labelText: 'Serves (optional)',
                      hintText: 'e.g., 4-6',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _timeController,
                    decoration: const InputDecoration(
                      labelText: 'Time (optional)',
                      hintText: 'e.g., 40 min',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Ingredients section
            Text(
              'Ingredients',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'One per line. Add notes like (optional), (diced), (alt: butter)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ingredientsController,
              decoration: const InputDecoration(
                hintText: '1 can white beans\n2 tbsp olive oil (alt: butter)\n1 onion, diced\n1 tsp salt (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              minLines: 5,
            ),

            const SizedBox(height: 24),

            // Directions section
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
                hintText: 'Melt butter in a large pot...\n\nAdd onions and sauté...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 10,
              minLines: 6,
            ),

            const SizedBox(height: 24),

            // Comments section
            Text(
              'Notes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Additional notes, tips, or variations (optional)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentsController,
              decoration: const InputDecoration(
                hintText: 'Works great with fresh herbs...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
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
}
