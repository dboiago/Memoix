# Scratch Pad Refactor Plan: From Free-Text to Structured Recipe Drafts

## Current State Analysis

### Existing Model (`lib/features/notes/models/scratch_pad.dart`)
```dart
@collection
class RecipeDraft {
  Id id = Isar.autoIncrement;
  late String uuid;
  String name = '';
  String? imagePath;
  String? serves;
  String? time;
  String ingredients = '';      // ❌ Raw text, one per line
  String directions = '';        // ❌ Raw text, steps separated by blank lines
  String comments = '';
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}
```

**Problem:** Ingredients and directions are stored as raw strings, making them incompatible with structured Recipe operations.

---

## Target State: Structured Draft Model

### Proposed New Model Structure

```dart
@collection
class RecipeDraft {
  Id id = Isar.autoIncrement;
  
  @Index(unique: true, replace: true)
  late String uuid;
  
  String name = '';
  String? imagePath;
  String? serves;
  String? time;
  
  // NEW: Structured ingredients (embedded objects)
  List<DraftIngredient> ingredients = [];
  
  // NEW: Structured directions (list of strings)
  List<String> directions = [];
  
  // NEW: Freeform notes section (preserves legacy data)
  String notes = '';
  
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
}

@embedded
class DraftIngredient {
  String name = '';
  String? quantity;
  String? unit;
  String? preparation;
  
  DraftIngredient({
    this.name = '',
    this.quantity,
    this.unit,
    this.preparation,
  });
  
  /// Convert from Recipe.Ingredient
  factory DraftIngredient.fromIngredient(Ingredient ingredient) {
    return DraftIngredient(
      name: ingredient.name,
      quantity: ingredient.quantity,
      unit: ingredient.unit,
      preparation: ingredient.preparation,
    );
  }
  
  /// Convert to Recipe.Ingredient
  Ingredient toIngredient() {
    return Ingredient(
      name: name,
      quantity: quantity ?? '',
      unit: unit ?? '',
      preparation: preparation,
    );
  }
}
```

---

## Migration Strategy

### 1. Database Migration (Isar Schema Upgrade)

**Location:** `lib/core/database/database.dart`

When Isar schema changes are detected:
1. **Read all existing drafts** before migration
2. **Parse raw text** into structured format:
   - Split `ingredients` string by newlines
   - Use `IngredientParser.parseIngredient()` for each line
   - Split `directions` string by double newlines
3. **Preserve raw text** in the new `notes` field
4. **Write migrated data** back to the new schema

```dart
Future<void> _migrateDraftsV1ToV2() async {
  // This runs automatically when Isar detects schema changes
  final oldDrafts = await isar.recipeDrafts.where().findAll();
  
  for (final oldDraft in oldDrafts) {
    final ingredients = <DraftIngredient>[];
    final ingredientLines = oldDraft.ingredients.split('\n');
    
    for (final line in ingredientLines) {
      if (line.trim().isEmpty) continue;
      final parsed = IngredientParser.parseIngredient(line);
      ingredients.add(DraftIngredient(
        name: parsed.name,
        quantity: parsed.quantity,
        unit: parsed.unit,
      ));
    }
    
    final directions = oldDraft.directions
        .split('\n\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    
    // Preserve original raw text in notes
    final notes = '''
[Legacy free-text data]

Original Ingredients:
${oldDraft.ingredients}

Original Directions:
${oldDraft.directions}
''';
    
    // Update with new structure
    await isar.writeTxn(() async {
      oldDraft.ingredients = ingredients;
      oldDraft.directions = directions;
      oldDraft.notes = notes;
      await isar.recipeDrafts.put(oldDraft);
    });
  }
}
```

### 2. UI Refactor

**Location:** `lib/features/notes/screens/scratch_pad_screen.dart`

#### Before (Current):
- `TextField` for ingredients (multiline string)
- `TextField` for directions (multiline string)

#### After (New):
- **Structured List View** for ingredients (like recipe edit screen)
  - Add/remove ingredient rows
  - Each row has: quantity, unit, name fields
- **Structured List View** for directions
  - Add/remove step items
  - Numbered automatically
- **New "Notes" Tab** for freeform text (preserves legacy behavior)

**Code Pattern to Follow:**
```dart
// Reuse existing ingredient editor from RecipeEditScreen
class _DraftIngredientsSection extends StatelessWidget {
  final List<DraftIngredient> ingredients;
  final Function(int index, DraftIngredient updated) onUpdate;
  final VoidCallback onAdd;
  final Function(int index) onRemove;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...List.generate(ingredients.length, (index) {
          return _IngredientRow(
            ingredient: ingredients[index],
            onChanged: (updated) => onUpdate(index, updated),
            onDelete: () => onRemove(index),
          );
        }),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add Ingredient'),
        ),
      ],
    );
  }
}
```

### 3. Repository Updates

**Location:** `lib/features/notes/repository/scratch_pad_repository.dart`

No breaking changes needed - Isar handles schema migrations automatically. However, add helper methods:

```dart
/// Create a structured draft from selected recipe elements (for comparison tool)
Future<RecipeDraft> createDraftFromSelection({
  required List<Ingredient> ingredients,
  required List<String> steps,
  String? name,
}) async {
  final draft = RecipeDraft()
    ..uuid = const Uuid().v4()
    ..name = name ?? 'Recipe Draft'
    ..ingredients = ingredients.map((i) => DraftIngredient.fromIngredient(i)).toList()
    ..directions = steps
    ..createdAt = DateTime.now()
    ..updatedAt = DateTime.now();
  
  await _isar.writeTxn(() async {
    await _isar.recipeDrafts.put(draft);
  });
  
  return draft;
}

/// Convert draft to full Recipe for saving
Recipe draftToRecipe(RecipeDraft draft, {
  required String course,
  String? cuisine,
}) {
  return Recipe.create(
    uuid: const Uuid().v4(),
    name: draft.name,
    course: course,
    cuisine: cuisine,
    serves: draft.serves,
    time: draft.time,
    ingredients: draft.ingredients.map((d) => d.toIngredient()).toList(),
    directions: draft.directions,
    comments: draft.notes, // Freeform notes go to comments
    source: RecipeSource.personal,
  );
}
```

---

## Backward Compatibility Guarantee

1. **No Data Loss:** All existing raw text is preserved in the `notes` field during migration
2. **Graceful Degradation:** If parsing fails, the entire string is stored in a single ingredient/step
3. **User Control:** Users can see "migrated from legacy format" indicator and manually edit if needed

---

## Testing Checklist

- [ ] Create draft with old code, verify it migrates correctly
- [ ] Verify freeform notes still work for users who prefer text
- [ ] Test comparison tool → scratch pad flow
- [ ] Test draft → recipe conversion
- [ ] Verify images/metadata preserved during migration

---

## Future Enhancements (Phase 2)

1. **Import from URL directly to Draft** (skip save step)
2. **Merge multiple drafts** (combine 2+ drafts into one)
3. **Draft templates** (pre-filled ingredient lists for common bases)
4. **Share drafts** (via QR code, like saved recipes)

---

## Implementation Order

1. ✅ Create `DraftIngredient` embedded class
2. ✅ Update `RecipeDraft` schema
3. ⏳ Write migration logic in database.dart
4. ⏳ Update UI to use structured lists
5. ⏳ Update repository helper methods
6. ⏳ Test migration with sample data
7. ⏳ Update comparison tool integration
