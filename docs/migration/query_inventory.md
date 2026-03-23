Here is the audit of Isar operations in the file(s):

database.dart

Method/Function Name	Operation Type	Isar Call	Filter/Sort/Limit Logic	Transaction Operations
initialize	WRITE	Isar.open	None	None
_seedDefaultCourses	READ	db.courses.count	None	None
_seedDefaultCourses	TRANSACTION	db.writeTxn	None	db.courses.putAll(Course.defaults)
refreshCourses	TRANSACTION	db.writeTxn	None	db.courses.clear, db.courses.putAll(Course.defaults)
close	WRITE	db.close	None	None
clearAll	TRANSACTION	db.writeTxn	None	db.clear, _seedDefaultCourses
Notes:
READ operations are used to count the number of courses in _seedDefaultCourses.
WRITE operations include opening the database (Isar.open) and closing it (db.close).
TRANSACTION operations are used for seeding default courses, refreshing courses, and clearing all data. These transactions involve multiple operations such as putAll, clear, and invoking _seedDefaultCourses


cellar_repository.dart:

Method/Function Name	Operation Type	Isar Call	Filter/Sort/Limit Logic	Transaction Operations
getAllEntries	READ	db.cellarEntrys.where().findAll	None	None
getEntriesByCategory	READ	db.cellarEntrys.filter().categoryEqualTo	categoryEqualTo(category, caseSensitive: false)	None
getBuyAgainEntries	READ	db.cellarEntrys.filter().buyEqualTo	buyEqualTo(true)	None
getFavorites	READ	db.cellarEntrys.filter().isFavoriteEqualTo	isFavoriteEqualTo(true)	None
searchEntries	READ	db.cellarEntrys.filter().nameContains.or().producerContains.or().categoryContains	nameContains(query, caseSensitive: false), producerContains, categoryContains	None
getEntryById	READ	db.cellarEntrys.get	None	None
getEntryByUuid	READ	db.cellarEntrys.filter().uuidEqualTo	uuidEqualTo(uuid)	None
saveEntry	TRANSACTION	db.writeTxn	None	db.cellarEntrys.put(entry)
deleteEntry	TRANSACTION	db.writeTxn	None	db.cellarEntrys.delete(id)
deleteEntryByUuid	TRANSACTION	db.writeTxn	None	getEntryByUuid(uuid), deleteEntry(entry.id)
toggleFavorite	TRANSACTION	db.writeTxn	None	db.cellarEntrys.put(entry)
toggleBuy	TRANSACTION	db.writeTxn	None	db.cellarEntrys.put(entry)
watchAllEntries	WATCH	db.cellarEntrys.where().watch	fireImmediately: true	None
watchFavorites	WATCH	db.cellarEntrys.filter().isFavoriteEqualTo.watch	isFavoriteEqualTo(true), fireImmediately: true	None
getEntryCount	READ	db.cellarEntrys.count	None	None
Notes:
READ operations are used for fetching entries, filtering by category, UUID, or other attributes, and counting entries.
WRITE operations include saving (put) and deleting (delete) entries, all wrapped in transactions.
WATCH operations are used to stream updates for all entries or filtered entries (e.g., favorites).
TRANSACTION operations involve multiple actions, such as saving, deleting, or toggling attributes like isFavorite or buy.


cheese_repository.dart:

Method/Function Name	Operation Type	Isar Call	Filter/Sort/Limit Logic	Transaction Operations
getAllEntries	READ	db.cheeseEntrys.where().findAll	None	None
getEntriesByCountry	READ	db.cheeseEntrys.filter().countryEqualTo	countryEqualTo(country, caseSensitive: false)	None
getEntriesByMilk	READ	db.cheeseEntrys.filter().milkEqualTo	milkEqualTo(milk, caseSensitive: false)	None
getBuyAgainEntries	READ	db.cheeseEntrys.filter().buyEqualTo	buyEqualTo(true)	None
getFavorites	READ	db.cheeseEntrys.filter().isFavoriteEqualTo	isFavoriteEqualTo(true)	None
searchEntries	READ	db.cheeseEntrys.filter().nameContains.or().typeContains.or().countryContains.or().milkContains	nameContains(query, caseSensitive: false), typeContains, countryContains, milkContains	None
getEntryById	READ	db.cheeseEntrys.get	None	None
getEntryByUuid	READ	db.cheeseEntrys.filter().uuidEqualTo	uuidEqualTo(uuid)	None
saveEntry	TRANSACTION	db.writeTxn	None	db.cheeseEntrys.put(entry)
deleteEntry	TRANSACTION	db.writeTxn	None	db.cheeseEntrys.delete(id)
deleteEntryByUuid	TRANSACTION	db.writeTxn	None	getEntryByUuid(uuid), deleteEntry(entry.id)
toggleFavorite	TRANSACTION	db.writeTxn	None	db.cheeseEntrys.put(entry)
toggleBuy	TRANSACTION	db.writeTxn	None	db.cheeseEntrys.put(entry)
watchAllEntries	WATCH	db.cheeseEntrys.where().watch	fireImmediately: true	None
watchFavorites	WATCH	db.cheeseEntrys.filter().isFavoriteEqualTo.watch	isFavoriteEqualTo(true), fireImmediately: true	None
getEntryCount	READ	db.cheeseEntrys.count	None	None
Notes:
READ operations are used for fetching entries, filtering by attributes like country, milk type, or UUID, and counting entries.
WRITE operations include saving (put) and deleting (delete) entries, all wrapped in transactions.
WATCH operations are used to stream updates for all entries or filtered entries (e.g., favorites).
TRANSACTION operations involve multiple actions, such as saving, deleting, or toggling attributes like isFavorite or buy.


meal_plan.dart`:

| Method/Function Name         | Operation Type | Isar Call                  | Filter/Sort/Limit Logic                                                                 | Transaction Operations                                                                 |
|------------------------------|----------------|----------------------------|----------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| `_ensureInstanceIds`         | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.mealPlans.put(plan)`                                                              |
| `getOrCreate`                | READ           | `db.mealPlans.where().dateEqualTo.findFirst` | `dateEqualTo(dateStr)`                                                                 | None                                                                                  |
| `getOrCreate`                | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.mealPlans.put(plan!)`                                                             |
| `addMeal`                    | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.mealPlans.put(plan)`                                                              |
| `removeMeal`                 | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.mealPlans.put(plan)`                                                              |
| `moveMeal`                   | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.mealPlans.put(fromPlan)`, `db.mealPlans.put(toPlan)`                               |
| `getWeek`                    | READ           | `db.mealPlans.where().dateEqualTo.findFirst` | `dateEqualTo(dateStr)`                                                                 | None                                                                                  |
| `watchDateRange`             | WATCH          | `db.mealPlans.where().filter().dateGreaterThan.and().dateLessThan.watch` | `dateGreaterThan(startStr)`, `dateLessThan(endStr)`, `fireImmediately: true`           | None                                                                                  |
| `clearDay`                   | READ           | `db.mealPlans.where().dateEqualTo.findFirst` | `dateEqualTo(dateStr)`                                                                 | None                                                                                  |
| `clearDay`                   | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.mealPlans.put(plan)`                                                              |
| `copyDay`                    | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.mealPlans.put(toPlan)`                                                            |

### Notes:
- **READ** operations are used for fetching meal plans by date or within a date range.
- **WRITE** operations include saving (`put`) meal plans, all wrapped in transactions.
- **WATCH** operations are used to stream updates for meal plans within a date range.
- **TRANSACTION** operations involve multiple actions, such as saving or updating meal plans.


`modernist_repository.dart`:

| Method/Function Name         | Operation Type | Isar Call                  | Filter/Sort/Limit Logic                                                                 | Transaction Operations                                                                 |
|------------------------------|----------------|----------------------------|----------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| `watchAll`                   | WATCH          | `db.modernistRecipes.where().sortByName().watch` | `sortByName()`, `fireImmediately: true`                                                | None                                                                                  |
| `watchByType`                | WATCH          | `db.modernistRecipes.where().filter().typeEqualTo.sortByName().watch` | `typeEqualTo(type)`, `sortByName()`, `fireImmediately: true`                            | None                                                                                  |
| `watchByTechnique`           | WATCH          | `db.modernistRecipes.where().filter().techniqueEqualTo.sortByName().watch` | `techniqueEqualTo(technique, caseSensitive: false)`, `sortByName()`, `fireImmediately: true` | None                                                                                  |
| `getAll`                     | READ           | `db.modernistRecipes.where().sortByName().findAll` | `sortByName()`                                                                         | None                                                                                  |
| `getById`                    | READ           | `db.modernistRecipes.get`  | None                                                                                   | None                                                                                  |
| `getByUuid`                  | READ           | `db.modernistRecipes.where().uuidEqualTo.findFirst` | `uuidEqualTo(uuid)`                                                                    | None                                                                                  |
| `getCount`                   | READ           | `db.modernistRecipes.count` | None                                                                                   | None                                                                                  |
| `save`                       | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.modernistRecipes.put(recipe)`                                                     |
| `create`                     | TRANSACTION    | `save(recipe)`             | None                                                                                   | `db.modernistRecipes.put(recipe)` (via `save`)                                        |
| `delete`                     | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.modernistRecipes.delete(id)`                                                      |
| `deleteByUuid`               | TRANSACTION    | `delete(recipe.id)`        | None                                                                                   | `db.modernistRecipes.delete(id)` (via `delete`)                                       |
| `toggleFavorite`             | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.modernistRecipes.get(id)`, `db.modernistRecipes.put(recipe)`                       |
| `incrementCookCount`         | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.modernistRecipes.get(id)`, `db.modernistRecipes.put(recipe)`                       |
| `watchFavorites`             | WATCH          | `db.modernistRecipes.where().filter().isFavoriteEqualTo.sortByName().watch` | `isFavoriteEqualTo(true)`, `sortByName()`, `fireImmediately: true`                     |

### Notes:
- **READ** operations are used for fetching recipes by ID, UUID, or all recipes, and counting recipes.
- **WRITE** operations include saving (`put`) and deleting (`delete`) recipes, all wrapped in transactions.
- **WATCH** operations are used to stream updates for all recipes, filtered recipes (e.g., by type, technique, or favorites), and sorted recipes.
- **TRANSACTION** operations involve multiple actions, such as saving, deleting, toggling favorite status, or incrementing cook count.


`scratch_pad_repository.dart`:

| Method/Function Name         | Operation Type | Isar Call                  | Filter/Sort/Limit Logic                                                                 | Transaction Operations                                                                 |
|------------------------------|----------------|----------------------------|----------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| `getQuickNotes`              | READ           | `db.scratchPads.where().findFirst` | None                                                                                   | None                                                                                  |
| `watchQuickNotes`            | WATCH          | `db.scratchPads.where().watch` | `fireImmediately: true`                                                                | None                                                                                  |
| `saveQuickNotes`             | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.scratchPads.where().findFirst`, `db.scratchPads.put(pad)`                          |
| `getAllDrafts`               | READ           | `db.recipeDrafts.where().sortByCreatedAtDesc().findAll` | `sortByCreatedAtDesc()`                                                                | None                                                                                  |
| `watchAllDrafts`             | WATCH          | `db.recipeDrafts.where().sortByCreatedAtDesc().watch` | `sortByCreatedAtDesc()`, `fireImmediately: true`                                       | None                                                                                  |
| `getDraftByUuid`             | READ           | `db.recipeDrafts.where().uuidEqualTo.findFirst` | `uuidEqualTo(uuid)`                                                                    | None                                                                                  |
| `createDraft`                | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.recipeDrafts.put(draft)`                                                          |
| `updateDraft`                | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.recipeDrafts.put(draft)`                                                          |
| `deleteDraft`                | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.recipeDrafts.where().uuidEqualTo.deleteAll`                                        |
| `deleteDraftById`            | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.recipeDrafts.delete(id)`                                                          |

### Notes:
- **READ** operations are used for fetching quick notes, recipe drafts, and drafts by UUID.
- **WRITE** operations include saving (`put`) and deleting (`delete`) drafts or quick notes, all wrapped in transactions.
- **WATCH** operations are used to stream updates for quick notes and recipe drafts.
- **TRANSACTION** operations involve multiple actions, such as saving, updating, or deleting drafts or quick notes.


`pizza_repository.dart`:

| Method/Function Name         | Operation Type | Isar Call                  | Filter/Sort/Limit Logic                                                                 | Transaction Operations                                                                 |
|------------------------------|----------------|----------------------------|----------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| `getAllPizzas`               | READ           | `db.pizzas.where().findAll` | None                                                                                   | None                                                                                  |
| `getPizzasByBase`            | READ           | `db.pizzas.filter().baseEqualTo.findAll` | `baseEqualTo(base)`                                                                    | None                                                                                  |
| `getPizzasBySource`          | READ           | `db.pizzas.filter().sourceEqualTo.findAll` | `sourceEqualTo(source)`                                                                | None                                                                                  |
| `getPersonalPizzas`          | READ           | `db.pizzas.filter().sourceEqualTo.findAll` | `sourceEqualTo(PizzaSource.personal)`                                                  | None                                                                                  |
| `getMemoixPizzas`            | READ           | `db.pizzas.filter().sourceEqualTo.findAll` | `sourceEqualTo(PizzaSource.memoix)`                                                    | None                                                                                  |
| `getFavorites`               | READ           | `db.pizzas.filter().isFavoriteEqualTo.findAll` | `isFavoriteEqualTo(true)`                                                              | None                                                                                  |
| `searchPizzas`               | READ           | `db.pizzas.filter().nameContains.or().cheesesElementContains.or().proteinsElementContains.or().vegetablesElementContains.or().tagsElementContains.findAll` | `nameContains(query, caseSensitive: false)`, `cheesesElementContains`, `proteinsElementContains`, `vegetablesElementContains`, `tagsElementContains` | None                                                                                  |
| `getPizzaById`               | READ           | `db.pizzas.get`            | None                                                                                   | None                                                                                  |
| `getPizzaByUuid`             | READ           | `db.pizzas.filter().uuidEqualTo.findFirst` | `uuidEqualTo(uuid)`                                                                    | None                                                                                  |
| `savePizza`                  | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.pizzas.put(pizza)`                                                                |
| `deletePizza`                | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.pizzas.delete(id)`                                                                |
| `deletePizzaByUuid`          | TRANSACTION    | `deletePizza(pizza.id)`    | None                                                                                   | `db.pizzas.delete(id)` (via `deletePizza`)                                            |
| `toggleFavorite`             | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.pizzas.put(pizza)`                                                                |
| `incrementCookCount`         | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.pizzas.put(pizza)`                                                                |
| `updateRating`               | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.pizzas.put(pizza)`                                                                |
| `watchAllPizzas`             | WATCH          | `db.pizzas.where().watch`  | `fireImmediately: true`                                                                | None                                                                                  |
| `watchPizzasByBase`          | WATCH          | `db.pizzas.filter().baseEqualTo.watch` | `baseEqualTo(base)`, `fireImmediately: true`                                           | None                                                                                  |
| `watchFavorites`             | WATCH          | `db.pizzas.filter().isFavoriteEqualTo.watch` | `isFavoriteEqualTo(true)`, `fireImmediately: true`                                     | None                                                                                  |
| `getPizzaCount`              | READ           | `db.pizzas.count`          | None                                                                                   | None                                                                                  |
| `getPizzaCountByBase`        | READ           | `db.pizzas.filter().baseEqualTo.count` | `baseEqualTo(base)`                                                                    | None                                                                                  |
| `importPizzas`               | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.pizzas.filter().uuidEqualTo.findFirst`, `db.pizzas.put(pizza)`                    |

### Notes:
- **READ** operations are used for fetching pizzas by various filters (e.g., base, source, favorites) and counting pizzas.
- **WRITE** operations include saving (`put`) and deleting (`delete`) pizzas, all wrapped in transactions.
- **WATCH** operations are used to stream updates for all pizzas, filtered pizzas (e.g., by base or favorites), and sorted pizzas.
- **TRANSACTION** operations involve multiple actions, such as saving, deleting, toggling favorite status, updating ratings, or importing pizzas.


`recipe_repository.dart`:

| Method/Function Name         | Operation Type | Isar Call                  | Filter/Sort/Limit Logic                                                                 | Transaction Operations                                                                 |
|------------------------------|----------------|----------------------------|----------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| `getAllRecipes`              | READ           | `db.recipes.where().findAll` | None                                                                                   | None                                                                                  |
| `getRecipesByCourse`         | READ           | `db.recipes.filter().courseEqualTo.findAll` | `courseEqualTo(course, caseSensitive: false)`                                          | None                                                                                  |
| `getRecipesByCuisine`        | READ           | `db.recipes.filter().cuisineEqualTo.findAll` | `cuisineEqualTo(cuisine, caseSensitive: false)`                                        | None                                                                                  |
| `getRecipesBySource`         | READ           | `db.recipes.filter().sourceEqualTo.findAll` | `sourceEqualTo(source)`                                                                | None                                                                                  |
| `getPersonalRecipes`         | READ           | `db.recipes.filter().sourceEqualTo.findAll` | `sourceEqualTo(RecipeSource.personal)`                                                 | None                                                                                  |
| `getMemoixRecipes`           | READ           | `db.recipes.filter().sourceEqualTo.findAll` | `sourceEqualTo(RecipeSource.memoix)`                                                   | None                                                                                  |
| `getImportedRecipes`         | READ           | `db.recipes.filter().sourceEqualTo.findAll` | `sourceEqualTo(RecipeSource.imported)`                                                 | None                                                                                  |
| `getFavorites`               | READ           | `db.recipes.filter().isFavoriteEqualTo.findAll` | `isFavoriteEqualTo(true)`                                                              | None                                                                                  |
| `searchRecipes`              | READ           | `db.recipes.filter().optional().group().limit(50).findAll` | `nameContains(query, caseSensitive: false)`, `tagsElementContains`, `cuisineContains`, `ingredientsElement.nameContains` | None                                                                                  |
| `getRecipeById`              | READ           | `db.recipes.get`            | None                                                                                   | None                                                                                  |
| `getRecipeByUuid`            | READ           | `db.recipes.filter().uuidEqualTo.findFirst` | `uuidEqualTo(uuid)`                                                                    | None                                                                                  |
| `saveRecipe`                 | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.recipes.put(recipe)`                                                              |
| `saveRecipes`                | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.recipes.putAll(recipes)`                                                          |
| `deleteRecipe`               | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.recipes.delete(id)`                                                               |
| `getRecipesPairedWith`       | READ           | `db.recipes.where().findAll` | None                                                                                   | None                                                                                  |
| `getRecipesByUuids`          | READ           | `getRecipeByUuid(uuid)`    | None                                                                                   | None                                                                                  |
| `toggleFavorite`             | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.recipes.get(id)`, `db.recipes.put(recipe)`                                        |
| `watchAllRecipes`            | WATCH          | `db.recipes.where().watch` | `fireImmediately: true`                                                                | None                                                                                  |
| `watchFavorites`             | WATCH          | `db.recipes.filter().isFavoriteEqualTo.watch` | `isFavoriteEqualTo(true)`, `fireImmediately: true`                                     | None                                                                                  |
| `watchRecipesByCourse`       | WATCH          | `db.recipes.filter().courseEqualTo.watch` | `courseEqualTo(course, caseSensitive: false)`, `fireImmediately: true`                 | None                                                                                  |
| `getAllCourses`              | READ           | `db.courses.where().sortBySortOrder().findAll` | `sortBySortOrder()`                                                                    | None                                                                                  |
| `getVisibleCourses`          | READ           | `db.courses.filter().isVisibleEqualTo.sortBySortOrder().findAll` | `isVisibleEqualTo(true)`, `sortBySortOrder()`                                          | None                                                                                  |
| `saveCourse`                 | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.courses.put(course)`                                                              |
| `watchCourses`               | WATCH          | `db.courses.where().sortBySortOrder().watch` | `sortBySortOrder()`, `fireImmediately: true`                                           | None                                                                                  |
| `syncMemoixRecipes`          | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.recipes.filter().sourceEqualTo.findAll`, `db.recipes.delete(prev.id)`, `db.recipes.putAll(recipes)` |

### Notes:
- **READ** operations are used for fetching recipes, courses, and paired recipes by various filters.
- **WRITE** operations include saving (`put`, `putAll`) and deleting (`delete`) recipes or courses, all wrapped in transactions.
- **WATCH** operations are used to stream updates for recipes and courses, filtered or sorted as needed.
- **TRANSACTION** operations involve multiple actions, such as saving, deleting, toggling favorite status, or syncing recipes.


`sandwich_repository.dart`:

| Method/Function Name         | Operation Type | Isar Call                  | Filter/Sort/Limit Logic                                                                 | Transaction Operations                                                                 |
|------------------------------|----------------|----------------------------|----------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| `getAllSandwiches`           | READ           | `db.sandwichs.where().findAll` | None                                                                                   | None                                                                                  |
| `getSandwichesBySource`      | READ           | `db.sandwichs.filter().sourceEqualTo.findAll` | `sourceEqualTo(source)`                                                                | None                                                                                  |
| `getPersonalSandwiches`      | READ           | `db.sandwichs.filter().sourceEqualTo.findAll` | `sourceEqualTo(SandwichSource.personal)`                                               | None                                                                                  |
| `getMemoixSandwiches`        | READ           | `db.sandwichs.filter().sourceEqualTo.findAll` | `sourceEqualTo(SandwichSource.memoix)`                                                 | None                                                                                  |
| `getFavorites`               | READ           | `db.sandwichs.filter().isFavoriteEqualTo.findAll` | `isFavoriteEqualTo(true)`                                                              | None                                                                                  |
| `searchSandwiches`           | READ           | `db.sandwichs.filter().nameContains.or().breadContains.or().proteinsElementContains.or().vegetablesElementContains.or().cheesesElementContains.or().condimentsElementContains.or().tagsElementContains.findAll` | `nameContains(query, caseSensitive: false)`, `breadContains`, `proteinsElementContains`, `vegetablesElementContains`, `cheesesElementContains`, `condimentsElementContains`, `tagsElementContains` | None                                                                                  |
| `getSandwichById`            | READ           | `db.sandwichs.get`         | None                                                                                   | None                                                                                  |
| `getSandwichByUuid`          | READ           | `db.sandwichs.filter().uuidEqualTo.findFirst` | `uuidEqualTo(uuid)`                                                                    | None                                                                                  |
| `saveSandwich`               | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.sandwichs.put(sandwich)`                                                          |
| `deleteSandwich`             | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.sandwichs.delete(id)`                                                             |
| `deleteSandwichByUuid`       | TRANSACTION    | `deleteSandwich(sandwich.id)` | None                                                                                   | `db.sandwichs.delete(id)` (via `deleteSandwich`)                                      |
| `toggleFavorite`             | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.sandwichs.put(sandwich)`                                                          |
| `incrementCookCount`         | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.sandwichs.put(sandwich)`                                                          |
| `updateRating`               | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.sandwichs.put(sandwich)`                                                          |
| `watchAllSandwiches`         | WATCH          | `db.sandwichs.where().watch` | `fireImmediately: true`                                                                | None                                                                                  |
| `watchFavorites`             | WATCH          | `db.sandwichs.filter().isFavoriteEqualTo.watch` | `isFavoriteEqualTo(true)`, `fireImmediately: true`                                     | None                                                                                  |
| `getSandwichCount`           | READ           | `db.sandwichs.count`       | None                                                                                   | None                                                                                  |
| `importSandwiches`           | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.sandwichs.filter().uuidEqualTo.findFirst`, `db.sandwichs.put(sandwich)`           |

### Notes:
- **READ** operations are used for fetching sandwiches by various filters (e.g., source, favorites) and counting sandwiches.
- **WRITE** operations include saving (`put`) and deleting (`delete`) sandwiches, all wrapped in transactions.
- **WATCH** operations are used to stream updates for all sandwiches or filtered sandwiches (e.g., favorites).
- **TRANSACTION** operations involve multiple actions, such as saving, deleting, toggling favorite status, updating ratings, or importing sandwiches.


`smoking_repository.dart`:

| Method/Function Name         | Operation Type | Isar Call                  | Filter/Sort/Limit Logic                                                                 | Transaction Operations                                                                 |
|------------------------------|----------------|----------------------------|----------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| `getAllRecipes`              | READ           | `db.smokingRecipes.where().sortByName().findAll` | `sortByName()`                                                                         | None                                                                                  |
| `getRecipesByWood`           | READ           | `db.smokingRecipes.where().filter().woodEqualTo.sortByName().findAll` | `woodEqualTo(wood, caseSensitive: false)`, `sortByName()`                              | None                                                                                  |
| `getRecipeByUuid`            | READ           | `db.smokingRecipes.where().uuidEqualTo.findFirst` | `uuidEqualTo(uuid)`                                                                    | None                                                                                  |
| `saveRecipe`                 | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.smokingRecipes.put(recipe)`                                                       |
| `deleteRecipe`               | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.smokingRecipes.delete(recipe.id)`                                                 |
| `toggleFavorite`             | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.smokingRecipes.put(recipe)`                                                       |
| `incrementCookCount`         | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.smokingRecipes.put(recipe)`                                                       |
| `watchAll`                   | WATCH          | `db.smokingRecipes.where().sortByName().watch` | `sortByName()`, `fireImmediately: true`                                                | None                                                                                  |
| `getCount`                   | READ           | `db.smokingRecipes.count`  | None                                                                                   | None                                                                                  |
| `watchFavorites`             | WATCH          | `db.smokingRecipes.where().filter().isFavoriteEqualTo.sortByName().watch` | `isFavoriteEqualTo(true)`, `sortByName()`, `fireImmediately: true`                     |

### Notes:
- **READ** operations are used for fetching smoking recipes by various filters (e.g., wood type, UUID) and counting recipes.
- **WRITE** operations include saving (`put`) and deleting (`delete`) recipes, all wrapped in transactions.
- **WATCH** operations are used to stream updates for all recipes or filtered recipes (e.g., favorites).
- **TRANSACTION** operations involve multiple actions, such as saving, deleting, toggling favorite status, or incrementing cook count.


`cooking_stats.dart`:

| Method/Function Name         | Operation Type | Isar Call                  | Filter/Sort/Limit Logic                                                                 | Transaction Operations                                                                 |
|------------------------------|----------------|----------------------------|----------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| `logCook`                    | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.cookingLogs.put(log)`                                                             |
| `getCookCount`               | READ           | `db.cookingLogs.where().recipeIdEqualTo.count` | `recipeIdEqualTo(recipeId)`                                                            | None                                                                                  |
| `getLastCookDate`            | READ           | `db.cookingLogs.where().recipeIdEqualTo.sortByCookedAtDesc.limit(1).findAll` | `recipeIdEqualTo(recipeId)`, `sortByCookedAtDesc()`, `limit(1)`                        | None                                                                                  |
| `getStats`                   | READ           | `db.cookingLogs.where().findAll` | None                                                                                   | None                                                                                  |
| `getStats`                   | READ           | `db.cookingLogs.where().sortByCookedAtDesc.limit(10).findAll` | `sortByCookedAtDesc()`, `limit(10)`                                                    | None                                                                                  |
| `watchChanges`               | WATCH          | `db.cookingLogs.watchLazy` | None                                                                                   | None                                                                                  |
| `deleteLog`                  | TRANSACTION    | `db.writeTxn`              | None                                                                                   | `db.cookingLogs.delete(logId)`                                                        |

### Notes:
- **READ** operations are used for fetching cooking logs by various filters (e.g., recipe ID, sorted by date) and counting logs.
- **WRITE** operations include saving (`put`) and deleting (`delete`) cooking logs, all wrapped in transactions.
- **WATCH** operations are used to stream updates for cooking logs.
- **TRANSACTION** operations involve multiple actions, such as saving or deleting cooking logs.


personal_storage_service.dart:

| Method/Function Name | Operation Type | Isar Call | Filter/Sort/Limit Logic | Transaction Operations |
|-----------------------|----------------|-----------|--------------------------|-------------------------|
| `_mergeRecipes`       | TRANSACTION    | `db.writeTxn` | `db.recipes.filter().uuidEqualTo(remote.uuid).findFirst()` | `db.recipes.put(remote)` |
| `_mergePizzas`        | TRANSACTION    | `db.writeTxn` | `db.pizzas.filter().uuidEqualTo(remote.uuid).findFirst()` | `db.pizzas.put(remote)` |
| `_mergeSandwiches`    | TRANSACTION    | `db.writeTxn` | `db.sandwichs.filter().uuidEqualTo(remote.uuid).findFirst()` | `db.sandwichs.put(remote)` |
| `_mergeCheeses`       | TRANSACTION    | `db.writeTxn` | `db.cheeseEntrys.filter().uuidEqualTo(remote.uuid).findFirst()` | `db.cheeseEntrys.put(remote)` |
| `_mergeCellar`        | TRANSACTION    | `db.writeTxn` | `db.cellarEntrys.filter().uuidEqualTo(remote.uuid).findFirst()` | `db.cellarEntrys.put(remote)` |
| `_mergeSmoking`       | TRANSACTION    | `db.writeTxn` | `db.smokingRecipes.filter().uuidEqualTo(remote.uuid).findFirst()` | `db.smokingRecipes.put(remote)` |
| `_mergeModernist`     | TRANSACTION    | `db.writeTxn` | `db.modernistRecipes.filter().uuidEqualTo(remote.uuid).findFirst()` | `db.modernistRecipes.put(remote)` |

Each transaction involves filtering for existing entries by `uuid` and performing a `put` operation to add or update records.


 `CalibrationEvaluator`

| Method/Function Name | Operation Type | Isar Call | Filter/Sort/Limit Logic | Transaction Operations |
|-----------------------|----------------|-----------|--------------------------|-------------------------|
| `_Spec.condition`     | READ           | `db.recipes.filter().isFavoriteEqualTo(true).count()` | `isFavoriteEqualTo(true)` | None |
| `_Spec.condition`     | READ           | `db.recipes.filter().sourceEqualTo(RecipeSource.personal).count()` | `sourceEqualTo(RecipeSource.personal)` | None |
| `_Spec.condition`     | READ           | `db.recipes.filter().sourceEqualTo(RecipeSource.personal).findAll()` | `sourceEqualTo(RecipeSource.personal)` | None |
| `_Spec.condition`     | READ           | `db.mealPlans.where().findAll()` | None | None |

These operations involve filtering and counting records in the recipes and `mealPlans` collections. No transactions or write operations are present.



