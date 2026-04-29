import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
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
  static Future<void> initialize() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'memoix'));
    final executor = LazyDatabase(() async {
      return NativeDatabase.createInBackground(file, setup: (rawDb) {
        rawDb.execute('PRAGMA journal_mode=WAL;');
        rawDb.execute('PRAGMA synchronous=NORMAL;');
        rawDb.execute('PRAGMA mmap_size=268435456;');
      });
    });
    AppDatabase.initialize(executor);
    await _seedDefaultCourses();
  }

  /// Refresh courses on every init so the home grid is always up-to-date
  /// before any stream provider starts watching. Running this here (inside
  /// appInitProvider) rather than in a post-frame callback prevents the
  /// batch deleteAll from ever reaching an active stream listener.
  static Future<void> _seedDefaultCourses() async {
    await refreshCourses();
  }

  /// Refresh courses with latest defaults using Drift Batching.
  static Future<void> refreshCourses() async {
    final db = AppDatabase.instance;
    await db.batch((batch) {
      // 1. Queue the delete
      batch.deleteAll(db.courses);
      
      // 2. Queue all the inserts in one massively efficient block
      final companions = domainModels.Course.defaults.map((c) => CoursesCompanion(
        slug: Value(c.slug),
        name: Value(c.name),
        iconName: Value(c.iconName),
        sortOrder: Value(c.sortOrder),
        colorValue: Value(c.colorValue),
        isVisible: Value(c.isVisible),
      )).toList();
      
      batch.insertAll(db.courses, companions);
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
      await db.delete(db.recipeImages).go();
    });
    await _seedDefaultCourses();
  }
}
