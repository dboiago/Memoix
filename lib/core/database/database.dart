import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/recipes/models/course.dart' as domainModels;
import 'app_database.dart';

/// Compatibility bridge for callers that still reference MemoixDatabase.
/// The Isar-based implementation has been replaced by [AppDatabase] (Drift).
/// Migrate callers directly to [AppDatabase] when possible.
class MemoixDatabase {
  MemoixDatabase._();

  /// The underlying Drift database instance.
  static AppDatabase get instance => AppDatabase.instance;

  /// Initialize the Drift database and seed default courses.
  ///
  /// Opens the database in a dedicated background isolate via
  /// [NativeDatabase.createInBackground] so that all SQLite I/O (queries,
  /// write notifications, WAL checkpointing) runs off the main thread.
  /// The database file path mirrors what [drift_flutter]'s driftDatabase()
  /// resolves to on each platform, so existing data is preserved on upgrade.
  static Future<void> initialize() async {
    final Directory dbDir;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      dbDir = await getApplicationSupportDirectory();
    } else {
      // Android, iOS — documents directory is the app-private location.
      dbDir = await getApplicationDocumentsDirectory();
    }
    final dbFile =
        File('${dbDir.path}${Platform.pathSeparator}memoix.db');
    AppDatabase.initialize(NativeDatabase.createInBackground(dbFile));
    await _seedDefaultCourses();
  }

  /// Seed default courses only when the courses table is empty.
  static Future<void> _seedDefaultCourses() async {
    final existing = await AppDatabase.instance.recipeDao.getAllCourses();
    if (existing.isEmpty) {
      await refreshCourses();
    }
  }

  /// Refresh courses with latest defaults.
  static Future<void> refreshCourses() async {
    final db = AppDatabase.instance;
    await db.transaction(() async {
      await db.delete(db.courses).go();
      for (final c in domainModels.Course.defaults) {
        await db.recipeDao.saveCourse(CoursesCompanion(
          slug: Value(c.slug),
          name: Value(c.name),
          iconName: Value(c.iconName),
          sortOrder: Value(c.sortOrder),
          colorValue: Value(c.colorValue),
          isVisible: Value(c.isVisible),
        ));
      }
    });
  }

  /// Delete all data from every table and re-seed default courses.
  static Future<void> clearAll() async {
    final db = AppDatabase.instance;
    await db.transaction(() async {
      await db.delete(db.recipes).go();
      await db.delete(db.ingredients).go();
      await db.delete(db.courses).go();
      await db.delete(db.pizzas).go();
      await db.delete(db.sandwiches).go();
      await db.delete(db.smokingRecipes).go();
      await db.delete(db.shoppingLists).go();
      await db.delete(db.shoppingItems).go();
      await db.delete(db.mealPlans).go();
      await db.delete(db.plannedMeals).go();
      await db.delete(db.cookingLogs).go();
      await db.delete(db.scratchPads).go();
      await db.delete(db.recipeDrafts).go();
      await db.delete(db.cheeseEntries).go();
      await db.delete(db.cellarEntries).go();
    });
    await _seedDefaultCourses();
  }
}
