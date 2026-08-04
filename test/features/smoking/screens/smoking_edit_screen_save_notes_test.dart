import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/features/smoking/models/smoking_recipe.dart';
import 'package:memoix/features/smoking/repository/smoking_repository.dart';
import 'package:memoix/features/smoking/screens/smoking_edit_screen.dart';

class _CaptureSmokingRepository implements SmokingRepository {
  final List<SmokingRecipe> saved = <SmokingRecipe>[];

  @override
  Future<void> saveRecipe(SmokingRecipe recipe, {bool preserveTimestamp = false}) async {
    saved.add(recipe);
  }

  @override
  Future<SmokingRecipe?> getRecipeByUuid(String uuid) async => null;

  @override
  Future<List<SmokingRecipe>> getAllRecipes() async => <SmokingRecipe>[];

  @override
  Future<List<SmokingRecipe>> getRecipesByWood(String wood) async => <SmokingRecipe>[];

  @override
  Future<List<SmokingRecipe>> getRecipesByType(String type) async => <SmokingRecipe>[];

  @override
  Future<void> deleteRecipe(SmokingRecipe recipe, {bool fromMerge = false}) async {}

  @override
  Future<void> deleteRecipeByUuid(String uuid, {bool fromMerge = false}) async {}

  @override
  Future<void> toggleShared(SmokingRecipe recipe) async {}

  @override
  Future<void> toggleFavourite(SmokingRecipe recipe) async {}

  @override
  Future<void> incrementCookCount(SmokingRecipe recipe) async {}

  @override
  Stream<List<SmokingRecipe>> watchAll() => Stream.value(<SmokingRecipe>[]);

  @override
  Stream<List<SmokingRecipe>> watchByType(String type) => Stream.value(<SmokingRecipe>[]);

  @override
  Future<int> getCount() async => 0;

  @override
  Future<int> getCountByType(String type) async => 0;

  @override
  Future<Set<String>> getAvailableWoods() async => <String>{};

  @override
  Stream<List<SmokingRecipe>> watchFavourites() => Stream.value(<SmokingRecipe>[]);
}

SmokingRecipe _importedRecipe({
  required String type,
  required String seasoningsJson,
  required String ingredientsJson,
  String? item,
  String temperature = '',
  String time = '',
}) {
  final now = DateTime(2026, 1, 1);
  return SmokingRecipe(
    id: 0,
    uuid: 'seed-$type',
    name: 'Seed Recipe',
    course: 'smoking',
    type: type,
    item: item,
    category: null,
    temperature: temperature,
    time: time,
    wood: 'Hickory',
    seasoningsJson: seasoningsJson,
    ingredientsJson: ingredientsJson,
    serves: null,
    directions: '[]',
    notes: null,
    headerImage: null,
    stepImages: '[]',
    stepImageMap: '[]',
    imageUrl: null,
    isFavourite: false,
    cookCount: 0,
    source: SmokingSource.personal.name,
    pairedRecipeIds: '[]',
    createdAt: now,
    updatedAt: now,
    isShared: true,
  );
}

void main() {
  testWidgets(
    'save path serializes typed ingredient notes into ingredientsJson (recipe type)',
    (tester) async {
      final repo = _CaptureSmokingRepository();
      final imported = _importedRecipe(
        type: SmokingType.recipe.name,
        seasoningsJson: '[]',
        ingredientsJson: jsonEncode([
          {'name': 'Pork Shoulder', 'amount': '1', 'unit': 'pc', 'notes': ''},
        ]),
        time: '10h',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            smokingRepositoryProvider.overrideWith((ref) => repo),
          ],
          child: MaterialApp(home: SmokingEditScreen(importedRecipe: imported)),
        ),
      );
      await tester.pumpAndSettle();

      final notesField = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == 'Notes',
      ).first;
      await tester.enterText(notesField, 'typed note from user');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.saved.length, 1);
      final saved = repo.saved.single;
      final ingredients = (jsonDecode(saved.ingredientsJson) as List)
          .cast<Map<String, dynamic>>();
      expect(ingredients, isNotEmpty);
      expect(ingredients.first['notes'], 'typed note from user');
    },
  );

  testWidgets(
    'save path preserves seasoningsJson notes for pit note payloads',
    (tester) async {
      final repo = _CaptureSmokingRepository();
      final imported = _importedRecipe(
        type: SmokingType.pitNote.name,
        item: 'Brisket',
        temperature: '250F',
        time: '8h',
        seasoningsJson: jsonEncode([
          {
            'name': 'Kosher Salt',
            'amount': '1',
            'unit': 'Tbsp',
            'notes': 'coarse grind',
          },
        ]),
        ingredientsJson: '[]',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            smokingRepositoryProvider.overrideWith((ref) => repo),
          ],
          child: MaterialApp(home: SmokingEditScreen(importedRecipe: imported)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.saved.length, 1);
      final saved = repo.saved.single;
      final seasonings = (jsonDecode(saved.seasoningsJson) as List)
          .cast<Map<String, dynamic>>();
      expect(seasonings, isNotEmpty);
      expect(seasonings.first['notes'], 'coarse grind');
    },
  );
}
