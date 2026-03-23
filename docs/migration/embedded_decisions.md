## @Embedded Types — Drift Migration Strategy

| Embedded class | Parent collection(s) | List or single | Queried/filtered independently | Recommended strategy | Justification |
|---|---|---|---|---|---|
| `Ingredient` | `Recipe`, `ModernistRecipe` (merged) | List | **Yes** — `ingredientsElement((i) => i.nameContains(...))` in `RecipeRepository.searchRecipes()` | **SEPARATE TABLE** | Searched by name across all recipes. ModernistIngredient folds into this table via null fill-in on richer fields (`preparation`, `alternative`, `isOptional`, `bakerPercent`). |
| `NutritionInfo` | `Recipe` | Single (nullable) | No | **JSON COLUMN** | Always read/written as a block with its parent. Never filtered or sorted on individual fields. |
| `PlannedMeal` | `MealPlan` | List | No — filtered in Dart memory by `instanceId` | **SEPARATE TABLE** | Individual items are added, removed, and moved by UUID. Row-level access avoids full list reloads on each mutation. |
| `SmokingSeasoning` | `SmokingRecipe` (×2 fields: `seasonings`, `ingredients`) | List | No | **JSON COLUMN** | Both lists always read/written in full with parent. Unit normalization happens in memory. SmokingRecipe remains a separate table — this decision is unaffected by the Recipe merge. |
| `DraftIngredient` | `RecipeDraft` | List | No | **JSON COLUMN** | Transient draft data, no individual query semantics. Always saved as part of the parent record. |
| `ShoppingItem` | `ShoppingList` | List | No — lookup via in-memory `items.indexWhere((i) => i.uuid == itemUuid)` | **SEPARATE TABLE** | Individual `uuid` identity and independently mutable `isChecked` state. Per-item toggle and delete map directly to row-level `UPDATE`/`DELETE`. |

## Notes on Schema Changes
- `ModernistIngredient` removed as a separate entry — it is now covered by the `Ingredient` row above following the ModernistRecipe → Recipes merge decision.
- `SmokingRecipe` remains a separate table by design. See `docs/migration/schema_decisions_rationale.md` for full reasoning.