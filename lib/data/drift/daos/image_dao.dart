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
                t.recipeId.equals(recipeId) & t.imageType.equals('header'))
            ..limit(1))
          .getSingleOrNull();

  Future<List<RecipeImage>> getStepImages(int recipeId) =>
      (select(recipeImages)
            ..where((t) =>
                t.recipeId.equals(recipeId) & t.imageType.equals('step'))
            ..orderBy([(t) => OrderingTerm.asc(t.stepIndex)]))
          .get();

  Future<void> deleteImagesForRecipe(int recipeId) =>
      (delete(recipeImages)..where((t) => t.recipeId.equals(recipeId))).go();

  Future<RecipeImage?> getImageByFileName(String fileName) =>
      (select(recipeImages)..where((t) => t.fileName.equals(fileName)))
          .getSingleOrNull();
}
