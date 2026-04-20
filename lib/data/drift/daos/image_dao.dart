import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

part 'image_dao.g.dart';

@DriftAccessor(tables: [RecipeImages])
class ImageDao extends DatabaseAccessor<AppDatabase> with _$ImageDaoMixin {
  ImageDao(super.db);

  Future<int> saveImage(RecipeImagesCompanion companion) =>
      into(recipeImages).insertOnConflictUpdate(companion);

  Future<List<RecipeImage>> getImagesForRecipe(int recipeId) =>
      (select(recipeImages)..where((t) => t.recipeId.equals(recipeId))).get();

  Future<RecipeImage?> getHeaderImage(int recipeId) =>
      (select(recipeImages)
            ..where((t) =>
                t.recipeId.equals(recipeId) & t.imageType.equals('header'),)
            ..limit(1))
          .getSingleOrNull();

  Future<List<RecipeImage>> getStepImages(int recipeId) =>
      (select(recipeImages)
            ..where((t) =>
                t.recipeId.equals(recipeId) & t.imageType.equals('step'),)
            ..orderBy([(t) => OrderingTerm.asc(t.stepIndex)]))
          .get();

  Future<void> deleteImagesForRecipe(int recipeId) =>
      (delete(recipeImages)..where((t) => t.recipeId.equals(recipeId))).go();

  /// Returns the image with the given [fileName], or null if none exists.
  ///
  /// Uses `limit(1)` deliberately: if duplicate rows exist (e.g. the unique
  /// index was absent during a v1→v2 migration), `getSingleOrNull` would throw
  /// `StateError: Too many elements`. Returning the first row is always safe
  /// because all duplicates hold the same bytes for the same filename.
  Future<RecipeImage?> getImageByFileName(String fileName) =>
      (select(recipeImages)
            ..where((t) => t.fileName.equals(fileName))
            ..limit(1))
          .getSingleOrNull();

  /// Checks whether a blob row exists for [fileName] without fetching
  /// the [imageData] column. Use this instead of [getImageByFileName] whenever
  /// only existence needs to be verified, to avoid loading multi-MB BLOBs into
  /// the Dart heap unnecessarily.
  Future<bool> checkImageExists(String fileName) async {
    final query = selectOnly(recipeImages)
      ..addColumns([recipeImages.fileName])
      ..where(recipeImages.fileName.equals(fileName))
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row != null;
  }
}
