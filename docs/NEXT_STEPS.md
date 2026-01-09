# Next Steps for Memoix Development

## Immediate Actions Required

### 1. Run Build Runner (CRITICAL - Blocks Scratch Pad Features)
**Command:**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

**Purpose:** Generate Isar schema files for updated RecipeDraft model

**Why Needed:**
- RecipeDraft model has new fields: `structuredIngredients`, `structuredDirections`, `legacyIngredients`, `legacyDirections`, `notes`
- DraftIngredient embedded class needs schema generation
- Current code has backward-compatible getters/setters but schema is out of sync

**Files Generated:**
- `lib/features/notes/models/scratch_pad.g.dart`

**Impact:**
- ✅ App will compile and run with new model
- ✅ Existing drafts will load correctly (backward compatibility)
- ✅ New drafts can be created
- ❌ Structured ingredient/direction UI is NOT yet implemented (still uses TextFields)

**Expected Time:** < 1 minute

---

## Short-Term Priorities (Next 1-2 Weeks)

### 2. Implement Scratch Pad Structured UI
**Effort:** 3-5 days  
**Priority:** HIGH  
**Blocks:** Recipe Comparison structured draft creation

**Deliverables:**
1. Migration logic in `database.dart` to parse existing drafts
2. `DraftIngredientEditor` widget (dialog with 4 fields)
3. Replace ingredients TextField with structured list view
4. Replace directions TextField with numbered step editor
5. Update `_buildUpdatedDraft()` to save structured data
6. Update `_convertToRecipe()` to use structured data
7. Update Recipe Comparison `_sendToScratchPad()` to create structured drafts

**Documentation:** [SCRATCH_PAD_IMPLEMENTATION_GUIDE.md](vscode-vfs://github/dboiago/Memoix/docs/SCRATCH_PAD_IMPLEMENTATION_GUIDE.md)

**Testing Checklist:**
- [ ] Existing drafts load and display correctly
- [ ] Migration parses ingredients from text
- [ ] Add/edit/delete ingredients works
- [ ] Reorder ingredients via drag handle
- [ ] Add/edit/delete directions works
- [ ] Reorder directions via drag handle
- [ ] Convert to recipe preserves structured data
- [ ] Recipe Comparison creates structured drafts

---

### 3. Implement Import Return Flow
**Effort:** 1-2 days  
**Priority:** MEDIUM  
**Blocks:** None (enhancement to Recipe Comparison)

**Current Behavior:**
1. User in Recipe Comparison screen
2. Taps "Select Recipe" → "Import from URL"
3. URL importer opens
4. User imports recipe and saves
5. User is on recipe detail screen (NOT back in comparison)

**Target Behavior:**
1-4. Same as above
5. User returns to Recipe Comparison with imported recipe in slot

**Implementation:**
1. Add `ComparisonContext` class:
   ```dart
   class ComparisonContext {
     final int targetSlot; // 1 or 2
     final Recipe? otherRecipe; // Pre-filled recipe in other slot
   }
   ```

2. Update import routes to accept context:
   ```dart
   static void toURLImport(BuildContext, {ComparisonContext? context})
   static void toOCRImport(BuildContext, {ComparisonContext? context})
   ```

3. Store context in ImportReviewScreen state

4. After saving recipe, check for context:
   ```dart
   if (context != null) {
     AppRoutes.toRecipeComparison(
       context: context,
       prefilledRecipe: savedRecipe,
     );
   }
   ```

5. Update RecipeComparisonScreen to accept context and restore state

**Files to Modify:**
- `lib/app/routes/router.dart` - Add context parameters
- `lib/features/import/screens/import_review_screen.dart` - Store and check context
- `lib/features/tools/recipe_comparison_screen.dart` - Restore state from context

**Testing:**
- [ ] Import from URL returns to comparison
- [ ] Import from OCR returns to comparison
- [ ] Other slot remains filled after import
- [ ] Imported recipe loads in correct slot
- [ ] Navigation stack is correct (can back out to previous screen)

---

## Medium-Term Enhancements (Next 1-3 Months)

### 4. Add Automated Tests
**Effort:** 5-7 days  
**Priority:** MEDIUM (good hygiene, not blocking features)

**Coverage Targets:**
- Recipe Comparison provider (state transitions)
- Recipe Picker Modal (search/filter logic)
- Type conversion helpers (Smoking/Modernist → Recipe)
- Draft deletion timer logic
- Ingredient parsing

**Test Types:**
- **Unit Tests:** Providers, helpers, parsers
- **Widget Tests:** RecipePickerModal, SelectableItem, DraftIngredientEditor
- **Integration Tests:** Full comparison → scratch pad → recipe flow

**Files to Create:**
- `test/features/tools/recipe_comparison_provider_test.dart`
- `test/shared/widgets/recipe_picker_modal_test.dart`
- `test/features/notes/draft_deletion_test.dart`
- `test/core/utils/ingredient_parser_test.dart`

---

### 5. Inline Recipe Editing in Comparison View
**Effort:** 2-3 days  
**Priority:** LOW (nice-to-have)

**Feature:**
- Pencil icon next to serves/time in comparison view
- Tap to show inline TextField
- Save/cancel buttons
- Updates recipe in database (not just comparison state)

**Use Case:** User realizes Recipe A serves 4 but needs 6 - adjust directly in comparison

**UI Pattern:**
```dart
Row(
  children: [
    Text('Serves: ${recipe.serves}'),
    IconButton(
      icon: Icon(Icons.edit, size: 16),
      onPressed: () => _editServes(recipe),
    ),
  ],
)

void _editServes(Recipe recipe) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Edit Serves'),
      content: TextField(
        controller: _servesController,
        decoration: InputDecoration(hintText: 'e.g., 4-6'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            recipe.serves = _servesController.text;
            await ref.read(recipeDatabaseProvider).saveRecipe(recipe);
            Navigator.pop(context);
            setState(() {}); // Refresh comparison view
          },
          child: Text('Save'),
        ),
      ],
    ),
  );
}
```

---

### 6. Ratio Scaling for Ingredient Quantities
**Effort:** 2-3 days  
**Priority:** LOW (nice-to-have)

**Feature:**
- Dropdown or slider next to recipe name in comparison view
- Options: 0.5x, 1x, 1.5x, 2x, 3x
- Automatically recalculates ingredient quantities
- Shows scaled values with original in parentheses

**Implementation:**
1. Add `scale` field to RecipeComparisonState
2. Parse quantity from ingredient (handle fractions, decimals, ranges)
3. Multiply by scale factor
4. Format result with original in parentheses

**Example:**
```
Original (1x): 1½ cups flour
Scaled (2x): 3 cups flour (originally 1½ cups)
```

**Challenges:**
- Handle fractions (½, ⅓, ¼) - convert to decimal, scale, convert back
- Handle ranges (1-2 cups) - scale both bounds
- Handle non-numeric quantities ("pinch", "to taste") - leave unchanged
- Handle unit conversions (e.g., 2 cups → 1 pint when scaled)

**Helper Methods:**
```dart
double? parseQuantity(String amount); // "1½" → 1.5
String formatQuantity(double value); // 1.5 → "1½"
String scaleIngredient(Ingredient ing, double scale);
```

---

## Long-Term Vision (3-6+ Months)

### 7. Collaborative Recipe Editing
**Feature:** Multiple users can edit same recipe simultaneously  
**Tech Stack:** Firebase Firestore or Supabase realtime subscriptions  
**Effort:** 2-3 weeks (backend + sync logic)

### 8. AI-Powered Recipe Suggestions
**Feature:** "You might also like..." based on comparison history  
**Tech Stack:** TensorFlow Lite or cloud ML API  
**Effort:** 3-4 weeks (model training + integration)

### 9. Video Step-by-Step Instructions
**Feature:** Attach short video clips to direction steps  
**Tech Stack:** Video player package + cloud storage  
**Effort:** 2-3 weeks (video upload + playback)

### 10. Ingredient Substitution Database
**Feature:** Suggest alternatives (e.g., "buttermilk" → "milk + lemon juice")  
**Tech Stack:** Local JSON database or cloud API  
**Effort:** 1-2 weeks (data curation + UI)

---

## Decision Points

### Should we add more than 2 recipe slots?
**Current:** Maximum 2 recipes  
**Pros of expanding:**
- Power users may want to compare 3+ variations
- Tablet/desktop has screen space

**Cons of expanding:**
- Cognitive load increases significantly
- Mobile layout becomes cramped
- Selection UI complexity grows (3-4 sets of checkboxes)

**Recommendation:** Keep at 2 for now, gather user feedback

---

### Should comparison state persist across app restarts?
**Current:** Session-only (resets on app close)  
**Pros of persisting:**
- User can resume comparison later
- Useful for long research sessions

**Cons of persisting:**
- Adds database complexity (need ComparisonSession collection)
- May confuse users (stale state on app open)
- Scratch Pad already serves this purpose

**Recommendation:** Keep session-only, users can save to Scratch Pad if needed

---

### Should we support comparing non-standard recipe types?
**Current:** Standard recipes only (Modernist/Smoking converted, Pizza/Sandwich excluded)  
**Pros of expanding:**
- More comprehensive comparison tool
- Pizza/Sandwich types have structured data

**Cons of expanding:**
- Component assembly model doesn't map to linear lists
- Conversion loses nuance (e.g., topping order, assembly sequence)
- UI becomes more complex (need to show bases, components, etc.)

**Recommendation:** Keep standard only, provide "Convert to Recipe" option for Pizza/Sandwich types

---

## Resources

### Documentation
- [AGENTS.md](vscode-vfs://github/dboiago/Memoix/AGENTS.md) - Development rules
- [RECIPE_COMPARISON_FEATURE.md](vscode-vfs://github/dboiago/Memoix/docs/RECIPE_COMPARISON_FEATURE.md) - Feature specs
- [SCRATCH_PAD_IMPLEMENTATION_GUIDE.md](vscode-vfs://github/dboiago/Memoix/docs/SCRATCH_PAD_IMPLEMENTATION_GUIDE.md) - Implementation guide
- [DEVELOPMENT_SUMMARY.md](vscode-vfs://github/dboiago/Memoix/docs/DEVELOPMENT_SUMMARY.md) - Recent work summary

### Key Files
- Recipe Comparison: [lib/features/tools/recipe_comparison_screen.dart](vscode-vfs://github/dboiago/Memoix/lib/features/tools/recipe_comparison_screen.dart)
- Recipe Picker: [lib/shared/widgets/recipe_picker_modal.dart](vscode-vfs://github/dboiago/Memoix/lib/shared/widgets/recipe_picker_modal.dart)
- Scratch Pad: [lib/features/notes/screens/scratch_pad_screen.dart](vscode-vfs://github/dboiago/Memoix/lib/features/notes/screens/scratch_pad_screen.dart)
- Draft Model: [lib/features/notes/models/scratch_pad.dart](vscode-vfs://github/dboiago/Memoix/lib/features/notes/models/scratch_pad.dart)

### Quick Start
```bash
# 1. Generate Isar schema (REQUIRED)
flutter pub run build_runner build --delete-conflicting-outputs

# 2. Run app
flutter run -d windows

# 3. Test Recipe Comparison
# - Open app drawer
# - Tap "Compare Recipes"
# - Select 2 recipes from library
# - Select ingredients/steps
# - Tap "Send to Scratch Pad"

# 4. Test Scratch Pad
# - Open app drawer
# - Tap "Scratch Pad"
# - Switch to "Recipe Drafts" tab
# - View draft created from comparison
# - Edit draft
# - Convert to recipe
```

---

## Questions?

If you encounter issues or have questions:
1. Check [AGENTS.md](vscode-vfs://github/dboiago/Memoix/AGENTS.md) for architecture rules
2. Review [RECIPE_COMPARISON_FEATURE.md](vscode-vfs://github/dboiago/Memoix/docs/RECIPE_COMPARISON_FEATURE.md) for feature specs
3. Consult [SCRATCH_PAD_IMPLEMENTATION_GUIDE.md](vscode-vfs://github/dboiago/Memoix/docs/SCRATCH_PAD_IMPLEMENTATION_GUIDE.md) for implementation details
4. Check git history for recent changes and context
