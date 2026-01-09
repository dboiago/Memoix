# Scratch Pad Structured Data Implementation Guide

## Overview
This guide details the implementation of structured ingredient/direction support for Recipe Drafts in the Scratch Pad feature.

## Current Status

### Phase 1: Data Model (✅ COMPLETE)
The RecipeDraft model has been updated with backward-compatible structured fields:

**New Fields:**
- `List<DraftIngredient> structuredIngredients` - Parsed ingredient objects
- `List<String> structuredDirections` - Step-by-step directions
- `String? legacyIngredients` - Original raw text for backward compatibility
- `String? legacyDirections` - Original raw text for backward compatibility  
- `String notes` - Freeform notes (renamed from `comments`)

**Backward Compatibility:**
- Getters/setters for `ingredients`, `directions`, `comments` remain functional
- Writing to these fields stores in legacy fields and clears structured data
- Reading from these fields returns formatted structured data if available, otherwise legacy text

**DraftIngredient Embedded Class:**
```dart
@embedded
class DraftIngredient {
  String name = '';
  String? quantity;
  String? unit;
  String? preparation;
  
  String toDisplayString() {
    // Formats as "1 cup flour (sifted)"
  }
}
```

### Phase 2: Schema Generation (⏸️ PENDING)
**Action Required:** Run build_runner to generate Isar schema files:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will:
- Generate `scratch_pad.g.dart` with updated schema
- Add migration logic for DraftIngredient embedded class
- Preserve existing draft data

### Phase 3: Migration Logic (📋 PLANNED)
Create migration function in `database.dart` to parse existing draft data:

```dart
Future<void> _migrateRecipeDrafts(Isar isar) async {
  final drafts = await isar.recipeDrafts.where().findAll();
  
  for (final draft in drafts) {
    // Skip already migrated drafts
    if (draft.structuredIngredients.isNotEmpty || draft.structuredDirections.isNotEmpty) {
      continue;
    }
    
    // Parse ingredients using IngredientParser
    if (draft.legacyIngredients != null && draft.legacyIngredients!.isNotEmpty) {
      final lines = draft.legacyIngredients!.split('\n');
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        
        final parsed = IngredientParser.parse(line);
        if (parsed.looksLikeIngredient) {
          draft.structuredIngredients.add(DraftIngredient(
            name: parsed.name,
            quantity: parsed.amount?.isNotEmpty == true ? parsed.amount : null,
            unit: parsed.unit?.isNotEmpty == true ? parsed.unit : null,
            preparation: parsed.preparation?.isNotEmpty == true ? parsed.preparation : null,
          ));
        }
      }
    }
    
    // Parse directions (split by blank lines or numbered steps)
    if (draft.legacyDirections != null && draft.legacyDirections!.isNotEmpty) {
      final text = draft.legacyDirections!.trim();
      
      // Try numbered format first
      final numberedSteps = RegExp(r'^\d+[.)]\s*', multiLine: true);
      if (numberedSteps.hasMatch(text)) {
        draft.structuredDirections = text
            .split(numberedSteps)
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.trim())
            .toList();
      } else {
        // Fall back to blank line separation
        draft.structuredDirections = text
            .split(RegExp(r'\n\s*\n'))
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.trim())
            .toList();
      }
    }
    
    // Save migrated draft
    await isar.writeTxn(() => isar.recipeDrafts.put(draft));
  }
}
```

**Call this in `MemoixDatabase.initialize()` after opening the database:**
```dart
if (migration needed) {
  await _migrateRecipeDrafts(isar);
}
```

### Phase 4: UI Refactor (📋 PLANNED)

#### 4.1 Replace TextField with Structured List View

**File:** `lib/features/notes/screens/scratch_pad_screen.dart`

**Current Pattern (Ingredients):**
```dart
TextField(
  controller: _ingredientsController,
  decoration: const InputDecoration(
    hintText: '1 can white beans\n2 tbsp olive oil',
    border: OutlineInputBorder(),
  ),
  maxLines: 8,
)
```

**New Pattern (Structured List):**
```dart
// Add state management for structured lists
List<DraftIngredient> _ingredients = [];

// Replace TextField with ListView.builder
Column(
  children: [
    // List of existing ingredients
    ..._ingredients.asMap().entries.map((entry) {
      final index = entry.key;
      final ingredient = entry.value;
      
      return _IngredientItem(
        ingredient: ingredient,
        onEdit: () => _editIngredient(index),
        onDelete: () => _deleteIngredient(index),
        onReorder: (oldIndex, newIndex) => _reorderIngredient(oldIndex, newIndex),
      );
    }),
    
    // Add button
    OutlinedButton.icon(
      onPressed: _addIngredient,
      icon: const Icon(Icons.add),
      label: const Text('Add Ingredient'),
    ),
  ],
)
```

#### 4.2 Create Ingredient Editor Widget

**New File:** `lib/features/notes/widgets/draft_ingredient_editor.dart`

```dart
class DraftIngredientEditor extends StatefulWidget {
  final DraftIngredient? ingredient; // null for new
  final ValueChanged<DraftIngredient> onSave;
  
  // Shows dialog with 4 fields:
  // - Name (required)
  // - Quantity (optional)
  // - Unit (dropdown with autocomplete)
  // - Preparation (optional)
}
```

#### 4.3 Update Direction Editor

**Current:** Single multiline TextField  
**New:** Numbered list of step editors

```dart
ReorderableListView.builder(
  itemCount: _directions.length,
  itemBuilder: (context, index) {
    return _DirectionStepItem(
      key: ValueKey(_directions[index]),
      stepNumber: index + 1,
      text: _directions[index],
      onEdit: () => _editDirection(index),
      onDelete: () => _deleteDirection(index),
    );
  },
  onReorder: _reorderDirections,
)
```

#### 4.4 Update _buildUpdatedDraft()

Replace:
```dart
..ingredients = _ingredientsController.text
..directions = _directionsController.text
```

With:
```dart
..structuredIngredients = _ingredients
..structuredDirections = _directions
```

#### 4.5 Import from Recipe Comparison

**Recipe Comparison Integration:**
When "Send to Scratch Pad" is pressed, the selections should create a structured draft:

```dart
// In RecipeComparisonScreen._sendToScratchPad()
final draftIngredients = <DraftIngredient>[];

// Add selected ingredients from recipe 1
for (final index in state.selectedIngredients1) {
  final ing = state.recipe1!.ingredients[index];
  draftIngredients.add(DraftIngredient(
    name: ing.name,
    quantity: ing.amount,
    unit: ing.unit,
    preparation: ing.preparation,
  ));
}

// Add selected ingredients from recipe 2
for (final index in state.selectedIngredients2) {
  final ing = state.recipe2!.ingredients[index];
  draftIngredients.add(DraftIngredient(
    name: ing.name,
    quantity: ing.amount,
    unit: ing.unit,
    preparation: ing.preparation,
  ));
}

// Create draft with structured data
final draft = RecipeDraft()
  ..uuid = const Uuid().v4()
  ..name = 'Recipe Comparison Draft'
  ..structuredIngredients = draftIngredients
  ..structuredDirections = selectedDirections
  ..createdAt = DateTime.now()
  ..updatedAt = DateTime.now();

await ref.read(scratchPadRepositoryProvider).updateDraft(draft);
```

### Phase 5: Convert to Recipe Logic (📋 PLANNED)

**File:** `lib/features/notes/screens/scratch_pad_screen.dart`

Update `_convertToRecipe()` to use structured data:

```dart
void _convertToRecipe(BuildContext context, WidgetRef ref, RecipeDraft draft) {
  final ingredients = <Ingredient>[];
  
  // If we have structured ingredients, use them directly
  if (draft.structuredIngredients.isNotEmpty) {
    for (final draftIng in draft.structuredIngredients) {
      final ingredient = Ingredient()
        ..name = draftIng.name
        ..amount = draftIng.quantity ?? ''
        ..unit = draftIng.unit ?? ''
        ..preparation = draftIng.preparation ?? '';
      ingredients.add(ingredient);
    }
  } else {
    // Fall back to parsing legacy text
    final ingredientLines = draft.ingredients
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    
    for (final line in ingredientLines) {
      final parsed = IngredientParser.parse(line);
      if (!parsed.looksLikeIngredient) continue;
      
      final ingredient = Ingredient()
        ..name = parsed.name
        ..amount = parsed.amount
        ..unit = parsed.unit
        ..preparation = parsed.preparation;
      
      ingredients.add(ingredient);
    }
  }
  
  // Use structured directions if available
  final directions = draft.structuredDirections.isNotEmpty
      ? draft.structuredDirections
      : _parseDirectionsFromText(draft.directions);
  
  final recipe = Recipe()
    ..uuid = const Uuid().v4()
    ..name = draft.name
    ..imagePath = draft.imagePath
    ..serves = draft.serves ?? ''
    ..time = draft.time ?? ''
    ..ingredients = ingredients
    ..directions = directions
    ..notes = draft.notes
    ..createdAt = DateTime.now();
  
  // Navigate to Recipe Edit screen for final review
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RecipeEditScreen(
        recipe: recipe,
        onSave: (editedRecipe) async {
          await ref.read(recipeDatabaseProvider).saveRecipe(editedRecipe);
          await ref.read(scratchPadRepositoryProvider).deleteDraft(draft.uuid);
          
          MemoixSnackBar.showSaved(
            itemName: editedRecipe.name,
            actionLabel: 'View',
            onView: () => AppRoutes.toRecipeDetail(context, uuid: editedRecipe.uuid),
          );
        },
      ),
    ),
  );
}
```

## Testing Checklist

### Data Migration
- [ ] Existing drafts with text load correctly
- [ ] Migration parses ingredients into structured format
- [ ] Migration preserves original text in legacy fields
- [ ] Drafts without text don't crash

### UI Functionality
- [ ] Add new ingredient opens editor dialog
- [ ] Edit ingredient updates in list
- [ ] Delete ingredient removes from list
- [ ] Reorder ingredients works via drag handle
- [ ] Add direction creates new step
- [ ] Edit direction updates step text
- [ ] Delete direction removes step and renumbers
- [ ] Reorder directions works

### Import from Recipe Comparison
- [ ] Selected ingredients appear as structured items
- [ ] Selected directions appear as structured steps
- [ ] Draft opens in edit mode after creation
- [ ] Save button persists structured data

### Convert to Recipe
- [ ] Structured ingredients convert to Ingredient objects
- [ ] Structured directions convert to directions list
- [ ] Notes field transfers to recipe notes
- [ ] Recipe Edit screen opens with pre-filled data
- [ ] Saving recipe deletes the draft
- [ ] SnackBar shows success message

### Backward Compatibility
- [ ] Old drafts (text-only) still display in list
- [ ] Old drafts convert to recipe correctly
- [ ] Setting `ingredients`/`directions` via setter writes to legacy fields
- [ ] Reading `ingredients`/`directions` returns formatted text

## Implementation Timeline

1. **Day 1:** Run build_runner, implement migration logic, test data safety
2. **Day 2:** Create ingredient editor widget and list UI
3. **Day 3:** Create direction editor and reorder logic
4. **Day 4:** Update Recipe Comparison integration
5. **Day 5:** Update convert-to-recipe logic and test end-to-end

## Files to Modify

- ✅ `lib/features/notes/models/scratch_pad.dart` - Model updated
- ⏸️ Schema generation required
- 📋 `lib/core/database/database.dart` - Add migration
- 📋 `lib/features/notes/screens/scratch_pad_screen.dart` - UI refactor
- 📋 `lib/features/notes/widgets/draft_ingredient_editor.dart` - NEW
- 📋 `lib/features/notes/widgets/draft_direction_editor.dart` - NEW
- 📋 `lib/features/tools/recipe_comparison_screen.dart` - Update _sendToScratchPad()

## Rollback Plan
If issues arise, the backward-compatible getters/setters ensure the current TextField-based UI continues working. The migration can be disabled by commenting out the migration call in database.dart.
