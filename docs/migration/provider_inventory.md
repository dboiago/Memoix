Here is the analysis of Riverpod providers declared in providers.dart:

| Provider Name                  | Provider Type          | Depends On (ref.watch/ref.read) | Isar Collection/Repository Touched | Return Type Exposed to UI | Contains Business Logic Beyond Data Fetching |
|--------------------------------|------------------------|----------------------------------|-------------------------------------|----------------------------|-----------------------------------------------|
| `databaseProvider`             | `Provider`            | None                             | `MemoixDatabase`                   | `Isar`                    | No                                            |
| `mealPlanServiceProvider`      | `Provider`            | `databaseProvider`               | `MemoixDatabase`                   | `MealPlanService`         | No                                            |
| `cookingStatsServiceProvider`  | `Provider`            | `databaseProvider`               | `MemoixDatabase`                   | `CookingStatsService`     | No                                            |
| `shoppingListServiceProvider`  | `Provider`            | `databaseProvider`               | `MemoixDatabase`                   | `ShoppingListService`     | No                                            |
| `shoppingListsProvider`        | `StreamProvider`      | `shoppingListServiceProvider`    | `ShoppingListService`              | `List<ShoppingList>`      | No                                            |
| `themeModeProvider`            | `StateNotifierProvider` | None                             | None                                | `ThemeMode`               | Yes (manages theme persistence via `SharedPreferences`) |
| `classicsFinalizedProvider`    | `StateProvider`       | None                             | `IntegrityService.store`           | `bool`                    | No                                            |

This table summarizes the providers, their dependencies, and their roles in the application.

Here is the analysis of Riverpod providers declared in deep_link_service.dart:

| Provider Name            | Provider Type | Depends On (ref.watch/ref.read) | Isar Collection/Repository Touched | Return Type Exposed to UI | Contains Business Logic Beyond Data Fetching |
|--------------------------|---------------|----------------------------------|-------------------------------------|----------------------------|-----------------------------------------------|
| `deepLinkServiceProvider` | `Provider`    | None                             | None                                | `DeepLinkService`         | Yes (Handles deep link initialization, parsing, and routing logic) |

Here is the analysis of Riverpod providers declared in github_recipe_service.dart:

| Provider Name               | Provider Type   | Depends On (ref.watch/ref.read)                                                                 | Isar Collection/Repository Touched | Return Type Exposed to UI | Contains Business Logic Beyond Data Fetching |
|-----------------------------|-----------------|--------------------------------------------------------------------------------------------------|-------------------------------------|----------------------------|-----------------------------------------------|
| `githubRecipeServiceProvider` | `Provider`      | None                                                                                             | None                                | `GitHubRecipeService`      | No                                            |
| `syncRecipesProvider`       | `FutureProvider` | `githubRecipeServiceProvider`, `recipeRepositoryProvider`, `pizzaRepositoryProvider`, `sandwichRepositoryProvider`, `smokingRepositoryProvider`, `modernistRepositoryProvider`, `cheeseRepositoryProvider`, `cellarRepositoryProvider` | Multiple repositories (`Recipe`, `Pizza`, `Sandwich`, `Smoking`, `Modernist`, `Cheese`, `Cellar`) | `void`                    | Yes (Synchronizes data across multiple repositories and domains) |


Here is the analysis of Riverpod providers declared in integrity_service.dart:

| Provider Name                 | Provider Type           | Depends On (ref.watch/ref.read) | Isar Collection/Repository Touched | Return Type Exposed to UI | Contains Business Logic Beyond Data Fetching |
|-------------------------------|-------------------------|----------------------------------|-------------------------------------|----------------------------|-----------------------------------------------|
| `viewOverrideProvider`        | `StateNotifierProvider` | None                             | None                                | `Map<String, ViewOverrideEntry>` | Yes (Manages transient UI overrides with persistence) |
| `executedAdjustmentsProvider` | `StateNotifierProvider` | None                             | None                                | `Set<String>`              | Yes (Tracks executed adjustments in memory for the session) |

Here is the analysis of Riverpod providers declared in update_service.dart:

| Provider Name           | Provider Type   | Depends On (ref.watch/ref.read) | Isar Collection/Repository Touched | Return Type Exposed to UI | Contains Business Logic Beyond Data Fetching |
|-------------------------|-----------------|----------------------------------|-------------------------------------|----------------------------|-----------------------------------------------|
| `updateServiceProvider` | `Provider`      | None                             | None                                | `UpdateService`           | No                                            |
| `appVersionProvider`    | `FutureProvider`| `updateServiceProvider`          | None                                | `AppVersion?`             | Yes (Checks for app updates and fetches version details) |

Here is the analysis of Riverpod providers declared in url_importer.dart:

| Provider Name          | Provider Type | Depends On (ref.watch/ref.read) | Isar Collection/Repository Touched | Return Type Exposed to UI | Contains Business Logic Beyond Data Fetching |
|------------------------|---------------|----------------------------------|-------------------------------------|----------------------------|-----------------------------------------------|
| `urlImporterProvider`  | `Provider`    | None                             | None                                | `UrlRecipeImporter`       | No                                            |

Here is the analysis of Riverpod providers declared in home_screen.dart:

| Provider Name               | Provider Type   | Depends On (ref.watch/ref.read) | Isar Collection/Repository Touched | Return Type Exposed to UI | Contains Business Logic Beyond Data Fetching |
|-----------------------------|-----------------|----------------------------------|-------------------------------------|----------------------------|-----------------------------------------------|
| `recipesByCourseProvider`   | Not declared in this file (likely imported) | Depends on `course.slug` (dynamic input) | Likely `Recipe` collection (based on context) | `AsyncValue<List<Recipe>>` | No (filters recipes by course dynamically) |

Here is the analysis of Riverpod providers declared in ocr_importer.dart:

| Provider Name         | Provider Type | Depends On (ref.watch/ref.read) | Isar Collection/Repository Touched | Return Type Exposed to UI | Contains Business Logic Beyond Data Fetching |
|-----------------------|---------------|----------------------------------|-------------------------------------|----------------------------|-----------------------------------------------|
| `ocrImporterProvider` | `Provider`    | None                             | None                                | `OcrRecipeImporter`       | No                                            |

Here is the analysis of Riverpod providers declared in cellar_repository.dart:

| Provider Name                  | Provider Type       | Depends On (ref.watch/ref.read)       | Returns                                   |
|--------------------------------|---------------------|----------------------------------------|-------------------------------------------|
| `cellarRepositoryProvider`     | `Provider`          | `databaseProvider`                    | `CellarRepository`                        |
| `allCellarEntriesProvider`     | `StreamProvider`    | `cellarRepositoryProvider`            | `Stream<List<CellarEntry>>`               |
| `favoriteCellarEntriesProvider`| `StreamProvider`    | `cellarRepositoryProvider`            | `Stream<List<CellarEntry>>`               |
| `cellarCountProvider`          | `Provider`          | `allCellarEntriesProvider`            | `AsyncValue<int>`                         |
| `cellarCategoriesProvider`     | `FutureProvider`    | `cellarRepositoryProvider`            | `Future<List<String>>`                    |
| `cellarProducersProvider`      | `FutureProvider`    | `cellarRepositoryProvider`            | `Future<List<String>>`                    |

Searched for regex `Provider\(|FutureProvider\(|StreamProvider\(|StateNotifierProvider\(|AsyncNotifierProvider\(|NotifierProvider\(|ChangeNotifierProvider\(|final .*Provider =` (`**/lib/features/cheese/repository/cheese_repository.dart`), 8 results

Here is the analysis of Riverpod providers declared in cheese_repository.dart:

| Provider Name                  | Provider Type       | Depends On (ref.watch/ref.read)       | Returns                                   |
|--------------------------------|---------------------|----------------------------------------|-------------------------------------------|
| `cheeseRepositoryProvider`     | `Provider`          | `databaseProvider`                    | `CheeseRepository`                        |
| `allCheeseEntriesProvider`     | `StreamProvider`    | `cheeseRepositoryProvider`            | `Stream<List<CheeseEntry>>`               |
| `favoriteCheeseEntriesProvider`| `StreamProvider`    | `cheeseRepositoryProvider`            | `Stream<List<CheeseEntry>>`               |
| `cheeseCountProvider`          | `Provider`          | `allCheeseEntriesProvider`            | `AsyncValue<int>`                         |
| `cheeseCountriesProvider`      | `FutureProvider`    | `cheeseRepositoryProvider`            | `Future<List<String>>`                    |
| `cheeseMilkTypesProvider`      | `FutureProvider`    | `cheeseRepositoryProvider`            | `Future<List<String>>`                    |
| `cheeseTexturesProvider`       | `FutureProvider`    | `cheeseRepositoryProvider`            | `Future<List<String>>`                    |
| `cheeseTypesProvider`          | `FutureProvider`    | `cheeseRepositoryProvider`            | `Future<List<String>>`                    |

No Riverpod providers are declared in the file recipe_repository.dart.

No Riverpod providers are declared in the file pizza_repository.dart.

No Riverpod providers are declared in the file sandwich_repository.dart.

Here are the Riverpod providers declared in smoking_repository.dart:

1. **Provider Name:** `smokingRepositoryProvider`
   - **Provider Type:** `Provider<SmokingRepository>`
   - **Depends On:** `ref.watch(databaseProvider)`
   - **Returns:** `SmokingRepository`

2. **Provider Name:** `allSmokingRecipesProvider`
   - **Provider Type:** `StreamProvider<List<SmokingRecipe>>`
   - **Depends On:** `ref.watch(smokingRepositoryProvider)`
   - **Returns:** `repo.watchAll()`

3. **Provider Name:** `favoriteSmokingRecipesProvider`
   - **Provider Type:** `StreamProvider<List<SmokingRecipe>>`
   - **Depends On:** `ref.watch(smokingRepositoryProvider)`
   - **Returns:** `repo.watchFavorites()`

4. **Provider Name:** `smokingCountProvider`
   - **Provider Type:** `Provider<AsyncValue<int>>`
   - **Depends On:** `ref.watch(allSmokingRecipesProvider)`
   - **Returns:** `recipesAsync.whenData((recipes) => recipes.length)`

5. **Provider Name:** `smokingRecipeByUuidProvider`
   - **Provider Type:** `FutureProvider.family<SmokingRecipe?, String>`
   - **Depends On:** `ref.watch(smokingRepositoryProvider)`
   - **Returns:** `repo.getRecipeByUuid(uuid)`

No Riverpod providers are declared in the file modernist_repository.dart.

Here are the Riverpod providers declared in scratch_pad_repository.dart:

1. **Provider Name:** `scratchPadRepositoryProvider`
   - **Provider Type:** `Provider<ScratchPadRepository>`
   - **Depends On:** `ref.watch(databaseProvider)`
   - **Returns:** `ScratchPadRepository`

2. **Provider Name:** `quickNotesProvider`
   - **Provider Type:** `StreamProvider<String>`
   - **Depends On:** `ref.watch(scratchPadRepositoryProvider)`
   - **Returns:** `scratchPadRepository.watchQuickNotes()`

3. **Provider Name:** `recipeDraftsProvider`
   - **Provider Type:** `StreamProvider<List<RecipeDraft>>`
   - **Depends On:** `ref.watch(scratchPadRepositoryProvider)`
   - **Returns:** `scratchPadRepository.watchAllDrafts()`

4. **Provider Name:** `draftDeletionServiceProvider`
   - **Provider Type:** `Provider<DraftDeletionService>`
   - **Depends On:** `ref.watch(scratchPadRepositoryProvider)`
   - **Returns:** `DraftDeletionService(scratchPadRepository)`

Here are the Riverpod providers declared in meal_plan.dart:

1. **Provider Name:** `weeklyPlanProvider`
   - **Provider Type:** `FutureProvider.family<WeeklyPlan, DateTime>`
   - **Depends On:** `ref.watch(mealPlanServiceProvider)`
   - **Returns:** `service.getWeek(weekStart)`

2. **Provider Name:** `selectedWeekProvider`
   - **Provider Type:** `StateProvider<DateTime>`
   - **Depends On:** None
   - **Returns:** Start of the current week (Monday) based on `DateTime.now()`

No Riverpod providers are declared in shopping_list.dart. A comment indicates that providers have been moved to `core/providers.dart`.

Here are the Riverpod providers declared in cooking_stats.dart:

1. **Provider Name:** `cookingStatsProvider`
   - **Provider Type:** `StreamProvider<CookingStats>`
   - **Depends On:** `ref.watch(cookingStatsServiceProvider)`
   - **Returns:** Emits `service.getStats()` initially and re-emits on `service.watchChanges()`

2. **Provider Name:** `recipeCookCountProvider`
   - **Provider Type:** `FutureProvider.family<int, String>`
   - **Depends On:** `ref.watch(cookingStatsServiceProvider)`
   - **Returns:** `service.getCookCount(recipeId)`

3. **Provider Name:** `recipeLastCookProvider`
   - **Provider Type:** `FutureProvider.family<DateTime?, String>`
   - **Depends On:** `ref.watch(cookingStatsServiceProvider)`
   - **Returns:** `service.getLastCookDate(recipeId)`

No Riverpod providers are declared in the file github_recipe_service.dart.

No Riverpod providers are declared in the file lib/core/services/personal_storage_service.dart.
