import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/drift/daos/cooking_log_dao.dart';
import '../../data/drift/daos/utility_dao.dart';
import '../../data/drift/daos/cellar_dao.dart';
import '../../data/drift/daos/image_dao.dart';
import '../../data/drift/daos/shopping_dao.dart';
import '../../data/drift/daos/meal_plan_dao.dart';
import '../../data/drift/daos/catalogue_dao.dart';
import '../../data/drift/daos/smoking_dao.dart';
import '../../data/drift/daos/recipe_dao.dart';

part 'app_database.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RECIPES
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_recipes_uuid', columns: {#uuid}, unique: true)
@TableIndex(name: 'idx_recipes_name', columns: {#name})
@TableIndex(name: 'idx_recipes_course', columns: {#course})
@TableIndex(name: 'idx_recipes_cuisine', columns: {#cuisine})
class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  TextColumn get course => text()();
  TextColumn get cuisine => text().nullable()();
  TextColumn get subcategory => text().nullable()();
  TextColumn get continent => text().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get serves => text().nullable()();
  TextColumn get time => text().nullable()();
  // List<String> stored as JSON array
  TextColumn get pairsWith => text().withDefault(const Constant('[]'))();
  // List<String> stored as JSON array
  TextColumn get pairedRecipeIds => text().withDefault(const Constant('[]'))();
  TextColumn get comments => text().nullable()();
  // List<String> stored as JSON array
  TextColumn get directions => text().withDefault(const Constant('[]'))();
  TextColumn get sourceUrl => text().nullable()();
  // List<String> stored as JSON array
  TextColumn get imageUrls => text().withDefault(const Constant('[]'))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get headerImage => text().nullable()();
  // List<String> stored as JSON array
  TextColumn get stepImages => text().withDefault(const Constant('[]'))();
  // List<String> stored as JSON array
  TextColumn get stepImageMap => text().withDefault(const Constant('[]'))();
  // RecipeSource enum stored as name string
  TextColumn get source => text().withDefault(const Constant('personal'))();
  IntColumn get colorValue => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get rating => integer().withDefault(const Constant(0))();
  IntColumn get cookCount => integer().withDefault(const Constant(0))();
  IntColumn get editCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get firstEditAt => dateTime().nullable()();
  DateTimeColumn get lastEditAt => dateTime().nullable()();
  DateTimeColumn get lastCookedAt => dateTime().nullable()();
  // List<String> stored as JSON array
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  // NutritionInfo? — JSON COLUMN (never individually queried)
  TextColumn get nutrition => text().nullable()();
  TextColumn get modernistType => text().nullable()();
  TextColumn get smokingType => text().nullable()();
  TextColumn get glass => text().nullable()();
  // List<String> stored as JSON array
  TextColumn get garnish => text().withDefault(const Constant('[]'))();
  TextColumn get pickleMethod => text().nullable()();
  // 'standard' | 'modernist' | 'smoking'
  TextColumn get recipeType => text().withDefault(const Constant('standard'))();
  // Modernist-only nullable fields
  TextColumn get technique => text().nullable()();
  TextColumn get difficulty => text().nullable()();
  TextColumn get scienceNotes => text().nullable()();
  // List<String> stored as JSON array — modernist equipment
  TextColumn get equipmentJson => text().nullable()();
}

// ─────────────────────────────────────────────────────────────────────────────
// INGREDIENTS  (was @embedded Ingredient — promoted to SEPARATE TABLE)
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_ingredients_uuid', columns: {#uuid}, unique: true)
@TableIndex(name: 'idx_ingredients_recipe_id', columns: {#recipeId})
class Ingredients extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  IntColumn get recipeId => integer().references(Recipes, #id)();
  TextColumn get name => text()();
  TextColumn get amount => text().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get alternative => text().nullable()();
  BoolColumn get isOptional => boolean().withDefault(const Constant(false))();
  TextColumn get section => text().nullable()();
  TextColumn get bakerPercent => text().nullable()();
}

// ─────────────────────────────────────────────────────────────────────────────
// PIZZAS
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_pizzas_uuid', columns: {#uuid}, unique: true)
@TableIndex(name: 'idx_pizzas_name', columns: {#name})
class Pizzas extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  // PizzaBase enum stored as name string
  TextColumn get base => text().withDefault(const Constant('marinara'))();
  // List<String> stored as JSON array
  TextColumn get cheeses => text().withDefault(const Constant('[]'))();
  // List<String> stored as JSON array
  TextColumn get proteins => text().withDefault(const Constant('[]'))();
  // List<String> stored as JSON array
  TextColumn get vegetables => text().withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  // PizzaSource enum stored as name string
  TextColumn get source => text().withDefault(const Constant('personal'))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get cookCount => integer().withDefault(const Constant(0))();
  IntColumn get rating => integer().withDefault(const Constant(0))();
  // List<String> stored as JSON array
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
}

// ─────────────────────────────────────────────────────────────────────────────
// CELLAR ENTRIES
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_cellar_entries_uuid', columns: {#uuid}, unique: true)
@TableIndex(name: 'idx_cellar_entries_name', columns: {#name})
class CellarEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  TextColumn get producer => text().nullable()();
  TextColumn get category => text().nullable()();
  BoolColumn get buy => boolean().withDefault(const Constant(false))();
  TextColumn get tastingNotes => text().nullable()();
  TextColumn get abv => text().nullable()();
  TextColumn get ageVintage => text().nullable()();
  IntColumn get priceRange => integer().nullable()();
  TextColumn get imageUrl => text().nullable()();
  // CellarSource enum stored as name string
  TextColumn get source => text().withDefault(const Constant('personal'))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
}

// ─────────────────────────────────────────────────────────────────────────────
// CHEESE ENTRIES
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_cheese_entries_uuid', columns: {#uuid}, unique: true)
@TableIndex(name: 'idx_cheese_entries_name', columns: {#name})
class CheeseEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  TextColumn get country => text().nullable()();
  TextColumn get milk => text().nullable()();
  TextColumn get texture => text().nullable()();
  TextColumn get type => text().nullable()();
  BoolColumn get buy => boolean().withDefault(const Constant(false))();
  TextColumn get flavour => text().nullable()();
  IntColumn get priceRange => integer().nullable()();
  TextColumn get imageUrl => text().nullable()();
  // CheeseSource enum stored as name string
  TextColumn get source => text().withDefault(const Constant('personal'))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
}

// ─────────────────────────────────────────────────────────────────────────────
// MEAL PLANS
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_meal_plans_uuid', columns: {#uuid}, unique: true)
@TableIndex(name: 'idx_meal_plans_date', columns: {#date}, unique: true)
class MealPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get date => text()();
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANNED MEALS  (was @embedded PlannedMeal — promoted to SEPARATE TABLE)
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_planned_meals_meal_plan_id', columns: {#mealPlanId})
@TableIndex(name: 'idx_planned_meals_instance_id', columns: {#instanceId})
class PlannedMeals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mealPlanId => integer().references(MealPlans, #id)();
  TextColumn get instanceId => text()();
  TextColumn get recipeId => text().nullable()();
  TextColumn get recipeName => text().nullable()();
  TextColumn get course => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get servings => integer().nullable()();
  TextColumn get cuisine => text().nullable()();
  TextColumn get recipeCategory => text().nullable()();
}

// ─────────────────────────────────────────────────────────────────────────────
// SCRATCH PADS
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_scratch_pads_uuid', columns: {#uuid}, unique: true)
class ScratchPads extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get quickNotes => text().withDefault(const Constant(''))();
  DateTimeColumn get updatedAt => dateTime()();
}

// ─────────────────────────────────────────────────────────────────────────────
// RECIPE DRAFTS
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_recipe_drafts_uuid', columns: {#uuid}, unique: true)
class RecipeDrafts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get serves => text().nullable()();
  TextColumn get time => text().nullable()();
  TextColumn get course => text().withDefault(const Constant('mains'))();
  // List<DraftIngredient> — JSON COLUMN (never individually queried)
  TextColumn get structuredIngredients => text().withDefault(const Constant('[]'))();
  // List<String> stored as JSON array
  TextColumn get structuredDirections => text().withDefault(const Constant('[]'))();
  TextColumn get legacyIngredients => text().nullable()();
  TextColumn get legacyDirections => text().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  // List<String> stored as JSON array
  TextColumn get stepImages => text().withDefault(const Constant('[]'))();
  // List<String> stored as JSON array
  TextColumn get stepImageMap => text().withDefault(const Constant('[]'))();
  // List<String> stored as JSON array
  TextColumn get pairedRecipeIds => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ─────────────────────────────────────────────────────────────────────────────
// SANDWICHES
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_sandwiches_uuid', columns: {#uuid}, unique: true)
@TableIndex(name: 'idx_sandwiches_name', columns: {#name})
class Sandwiches extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  TextColumn get bread => text().withDefault(const Constant(''))();
  // List<String> stored as JSON array
  TextColumn get proteins => text().withDefault(const Constant('[]'))();
  // List<String> stored as JSON array
  TextColumn get vegetables => text().withDefault(const Constant('[]'))();
  // List<String> stored as JSON array
  TextColumn get cheeses => text().withDefault(const Constant('[]'))();
  // List<String> stored as JSON array
  TextColumn get condiments => text().withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  // SandwichSource enum stored as name string
  TextColumn get source => text().withDefault(const Constant('personal'))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get cookCount => integer().withDefault(const Constant(0))();
  IntColumn get rating => integer().withDefault(const Constant(0))();
  // List<String> stored as JSON array
  TextColumn get tags => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
}

/// Type alias: Drift generates 'Sandwiche' from the Sandwiches table name.
/// All app code uses 'Sandwich' — this alias keeps them compatible.
typedef Sandwich = Sandwiche;

// ─────────────────────────────────────────────────────────────────────────────
// SHOPPING LISTS
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_shopping_lists_uuid', columns: {#uuid}, unique: true)
class ShoppingLists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  // List<String> stored as JSON array
  TextColumn get recipeIds => text().withDefault(const Constant('[]'))();
}

// ─────────────────────────────────────────────────────────────────────────────
// SHOPPING ITEMS  (was @embedded ShoppingItem — promoted to SEPARATE TABLE)
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_shopping_items_list_id', columns: {#shoppingListId})
@TableIndex(name: 'idx_shopping_items_uuid', columns: {#uuid})
class ShoppingItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get shoppingListId => integer().references(ShoppingLists, #id)();
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  TextColumn get amount => text().nullable()();
  TextColumn get unit => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get recipeSource => text().nullable()();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();
  TextColumn get manualNotes => text().nullable()();
}

// ─────────────────────────────────────────────────────────────────────────────
// SMOKING RECIPES
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_smoking_recipes_uuid', columns: {#uuid}, unique: true)
@TableIndex(name: 'idx_smoking_recipes_name', columns: {#name})
@TableIndex(name: 'idx_smoking_recipes_course', columns: {#course})
@TableIndex(name: 'idx_smoking_recipes_item', columns: {#item})
@TableIndex(name: 'idx_smoking_recipes_category', columns: {#category})
@TableIndex(name: 'idx_smoking_recipes_wood', columns: {#wood})
class SmokingRecipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text()();
  TextColumn get name => text()();
  TextColumn get course => text().withDefault(const Constant('smoking'))();
  // SmokingType enum stored as name string
  TextColumn get type => text().withDefault(const Constant('pitNote'))();
  TextColumn get item => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get temperature => text().withDefault(const Constant(''))();
  TextColumn get time => text().withDefault(const Constant(''))();
  TextColumn get wood => text().withDefault(const Constant(''))();
  // List<SmokingSeasoning> — JSON COLUMN (never individually queried)
  TextColumn get seasoningsJson => text().withDefault(const Constant('[]'))();
  // List<SmokingSeasoning> — JSON COLUMN (never individually queried)
  TextColumn get ingredientsJson => text().withDefault(const Constant('[]'))();
  TextColumn get serves => text().nullable()();
  // List<String> stored as JSON array
  TextColumn get directions => text().withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
  TextColumn get headerImage => text().nullable()();
  // List<String> stored as JSON array
  TextColumn get stepImages => text().withDefault(const Constant('[]'))();
  // List<String> stored as JSON array
  TextColumn get stepImageMap => text().withDefault(const Constant('[]'))();
  TextColumn get imageUrl => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get cookCount => integer().withDefault(const Constant(0))();
  // SmokingSource enum stored as name string
  TextColumn get source => text().withDefault(const Constant('personal'))();
  // List<String> stored as JSON array
  TextColumn get pairedRecipeIds => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// ─────────────────────────────────────────────────────────────────────────────
// COOKING LOGS
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_cooking_logs_uuid', columns: {#uuid}, unique: true)
@TableIndex(name: 'idx_cooking_logs_recipe_id', columns: {#recipeId})
@TableIndex(name: 'idx_cooking_logs_cooked_at', columns: {#cookedAt})
class CookingLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().withDefault(const Constant(''))();
  TextColumn get recipeId => text()();
  TextColumn get recipeName => text()();
  TextColumn get recipeCourse => text().nullable()();
  TextColumn get recipeCuisine => text().nullable()();
  DateTimeColumn get cookedAt => dateTime()();
  TextColumn get notes => text().nullable()();
  IntColumn get servingsMade => integer().nullable()();
}

// ─────────────────────────────────────────────────────────────────────────────
// COURSES
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_courses_slug', columns: {#slug}, unique: true)
class Courses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get slug => text()();
  TextColumn get name => text()();
  TextColumn get iconName => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get colorValue => integer().withDefault(const Constant(0xFFFFB74D))();
  BoolColumn get isVisible => boolean().withDefault(const Constant(true))();
}

// ─────────────────────────────────────────────────────────────────────────────
// RECIPE IMAGES (binary blob storage for sync)
// ─────────────────────────────────────────────────────────────────────────────

@TableIndex(name: 'idx_recipe_images_recipe_id', columns: {#recipeId})
@TableIndex(name: 'idx_recipe_images_file_name', columns: {#fileName}, unique: true)
class RecipeImages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get recipeId => integer().references(Recipes, #id)();
  TextColumn get fileName => text()(); // original filename, used as stable sync identifier
  TextColumn get imageType => text()(); // 'header' | 'step' | 'gallery'
  IntColumn get stepIndex => integer().nullable()(); // only set when imageType == 'step'
  BlobColumn get imageData => blob()();
  TextColumn get mimeType => text().withDefault(const Constant('image/jpeg'))();
  DateTimeColumn get createdAt => dateTime()();
}

// ─────────────────────────────────────────────────────────────────────────────
// DATABASE
// ─────────────────────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Recipes,
  Ingredients,
  Pizzas,
  CellarEntries,
  CheeseEntries,
  MealPlans,
  PlannedMeals,
  ScratchPads,
  RecipeDrafts,
  Sandwiches,
  ShoppingLists,
  ShoppingItems,
  SmokingRecipes,
  CookingLogs,
  Courses,
  RecipeImages,
], daos: [
  CookingLogDao,
  UtilityDao,
  CellarDao,
  ShoppingDao,
  MealPlanDao,
  CatalogueDao,
  SmokingDao,
  RecipeDao,
  ImageDao,
],)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  static AppDatabase? _instance;

  static AppDatabase get instance {
    if (_instance == null) {
      throw StateError(
          'AppDatabase not initialized. Call AppDatabase.initialize() first.',);
    }
    return _instance!;
  }

  static void initialize(QueryExecutor executor) {
    _instance ??= AppDatabase(executor);
  }

  /// Reset the singleton to allow reinitialization after a DB file replacement.
  static void resetInstance() {
    _instance = null;
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(recipeImages);
      }
      if (from < 3) {
        const _uuid = Uuid();

        // Guard each ALTER TABLE: only add the column if it does not already exist.
        // This prevents "duplicate column name: uuid" when the migration partially ran
        // on a previous launch and is being retried.
        final ingredientCols =
            await customSelect('PRAGMA table_info(ingredients)').get();
        if (!ingredientCols.any((r) => r.read<String>('name') == 'uuid')) {
          await m.addColumn(ingredients, ingredients.uuid);
        }

        final mealPlanCols =
            await customSelect('PRAGMA table_info(meal_plans)').get();
        if (!mealPlanCols.any((r) => r.read<String>('name') == 'uuid')) {
          await m.addColumn(mealPlans, mealPlans.uuid);
        }

        final scratchPadCols =
            await customSelect('PRAGMA table_info(scratch_pads)').get();
        if (!scratchPadCols.any((r) => r.read<String>('name') == 'uuid')) {
          await m.addColumn(scratchPads, scratchPads.uuid);
        }

        final cookingLogCols =
            await customSelect('PRAGMA table_info(cooking_logs)').get();
        if (!cookingLogCols.any((r) => r.read<String>('name') == 'uuid')) {
          await m.addColumn(cookingLogs, cookingLogs.uuid);
        }

        // Only update rows that still carry the empty-string default.
        // Re-running after a partial migration will never overwrite already-assigned UUIDs.
        final ingredientRows =
            await (select(ingredients)..where((t) => t.uuid.equals(''))).get();
        for (final row in ingredientRows) {
          await (update(ingredients)..where((t) => t.id.equals(row.id)))
              .write(IngredientsCompanion(uuid: Value(_uuid.v4())));
        }

        final mealPlanRows =
            await (select(mealPlans)..where((t) => t.uuid.equals(''))).get();
        for (final row in mealPlanRows) {
          await (update(mealPlans)..where((t) => t.id.equals(row.id)))
              .write(MealPlansCompanion(uuid: Value(_uuid.v4())));
        }

        final scratchPadRows =
            await (select(scratchPads)..where((t) => t.uuid.equals(''))).get();
        for (final row in scratchPadRows) {
          await (update(scratchPads)..where((t) => t.id.equals(row.id)))
              .write(ScratchPadsCompanion(uuid: Value(_uuid.v4())));
        }

        final cookingLogRows =
            await (select(cookingLogs)..where((t) => t.uuid.equals(''))).get();
        for (final row in cookingLogRows) {
          await (update(cookingLogs)..where((t) => t.id.equals(row.id)))
              .write(CookingLogsCompanion(uuid: Value(_uuid.v4())));
        }
      }
      if (from < 4) {
        // Ensure the unique index on recipe_images.file_name exists.
        // `m.createTable(recipeImages)` in the v1→v2 migration may not have
        // created @TableIndex indexes on some Drift versions/configurations,
        // allowing duplicate file_name rows to accumulate. Those duplicates
        // cause `getSingleOrNull()` to throw `StateError: Too many elements`.
        //
        // Step 1 — deduplicate: keep only the row with the highest id for each
        // file_name (most recently written, therefore most likely to be correct).
        await customStatement('''
          DELETE FROM recipe_images
          WHERE id NOT IN (
            SELECT MAX(id) FROM recipe_images GROUP BY file_name
          )
        ''');

        // Step 2 — create the unique index so future inserts can never produce
        // duplicates again. IF NOT EXISTS makes this idempotent if the index
        // was already created correctly by the v2 migration.
        await customStatement('''
          CREATE UNIQUE INDEX IF NOT EXISTS idx_recipe_images_file_name
          ON recipe_images (file_name)
        ''');

        // Step 3 — create the non-unique lookup index for the same reason.
        await customStatement('''
          CREATE INDEX IF NOT EXISTS idx_recipe_images_recipe_id
          ON recipe_images (recipe_id)
        ''');
      }
    },
  );

  @override
  CookingLogDao get cookingLogDao => CookingLogDao(this);
  @override
  UtilityDao get utilityDao => UtilityDao(this);
  @override
  CellarDao get cellarDao => CellarDao(this);
  @override
  ShoppingDao get shoppingDao => ShoppingDao(this);
  @override
  MealPlanDao get mealPlanDao => MealPlanDao(this);
  @override
  CatalogueDao get catalogueDao => CatalogueDao(this);
  @override
  SmokingDao get smokingDao => SmokingDao(this);
  @override
  RecipeDao get recipeDao => RecipeDao(this);
  @override
  ImageDao get imageDao => ImageDao(this);
}
