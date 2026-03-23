## @Embedded Types — Drift Migration Strategy

| Embedded class | Parent collection(s) | List or single | Queried/filtered independently (Isar) | Recommended strategy | Justification |
|---|---|---|---|---|---|
| `Ingredient` | `Recipe` | List | **Yes** — `ingredientsElement((i) => i.nameContains(...))` called in `RecipeRepository.searchRecipes()` | **SEPARATE TABLE** | The only embedded type actively used as an Isar query filter target; `name` field is searched across all recipes. |
| `NutritionInfo` | `Recipe` | Single (nullable) | No | **JSON COLUMN** | Populated from URL/OCR import and displayed as a block; no individual field is ever filtered, sorted, or queried in any repository. |
| `PlannedMeal` | `MealPlan` | List | No — filtering done in Dart memory by `instanceId` after loading parent | **SEPARATE TABLE** | Each item carries its own UUID (`instanceId`) and is individually added, removed, and moved by that ID; row-level access in Drift removes the need for full list reloads on each mutation. |
| `SmokingSeasoning` | `SmokingRecipe` (`seasonings`, `ingredients`) | List (×2 fields) | No | **JSON COLUMN** | Both lists are read and written in full with the parent record; the only downstream operation is unit normalization on the in-memory list. |
| `ModernistIngredient` | `ModernistRecipe` | List | No — `.ingredientsElement()` exists in generated code but is **not called** in any repository | **JSON COLUMN** | No repository query ever filters on ingredient fields; always fetched and written as a bulk list with the parent. |
| `DraftIngredient` | `RecipeDraft` | List | No | **JSON COLUMN** | Transient draft data with no individual query semantics; always loaded and saved as part of the parent `RecipeDraft` record. |
| `ShoppingItem` | `ShoppingList` | List | No — item lookup uses in-memory `items.indexWhere((i) => i.uuid == itemUuid)` | **SEPARATE TABLE** | Items carry individual `uuid` identity and independently mutable `isChecked` state; per-item toggle and delete operations map directly to row-level `UPDATE`/`DELETE` in Drift without rewriting the entire list. |

