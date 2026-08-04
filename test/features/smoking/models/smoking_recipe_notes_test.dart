import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/features/smoking/models/smoking_recipe.dart';

void main() {
  group('Smoking ingredient notes', () {
    test('toRecipe maps ingredient notes into preparation', () {
      final recipe = SmokingRecipe(
        id: 1,
        uuid: 'smoke-1',
        name: 'Smoked Wings',
        course: 'smoking',
        type: SmokingType.recipe.name,
        item: 'Wings',
        category: 'Poultry',
        temperature: '250F',
        time: '2h',
        wood: 'Hickory',
        seasoningsJson: '[]',
        ingredientsJson: jsonEncode([
          {
            'name': 'Chicken Wings',
            'amount': '2',
            'unit': 'lb',
            'notes': 'Pat dry overnight',
          },
        ]),
        serves: '4',
        directions: jsonEncode(['Smoke until done']),
        notes: 'Main notes',
        headerImage: null,
        stepImages: '[]',
        stepImageMap: '[]',
        imageUrl: null,
        isFavourite: false,
        cookCount: 0,
        source: SmokingSource.personal.name,
        pairedRecipeIds: '[]',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        isShared: true,
      );

      final asRecipe = recipe.toRecipe();

      expect(asRecipe.ingredients, hasLength(1));
      expect(asRecipe.ingredients.first.name, 'Chicken Wings');
      expect(asRecipe.ingredients.first.preparation, 'Pat dry overnight');
    });

    test('seasoningsList exposes notes from seasoningsJson', () {
      final recipe = SmokingRecipe(
        id: 2,
        uuid: 'smoke-2',
        name: 'Rub Test',
        course: 'smoking',
        type: SmokingType.pitNote.name,
        item: null,
        category: null,
        temperature: '',
        time: '',
        wood: '',
        seasoningsJson: jsonEncode([
          {
            'name': 'Kosher Salt',
            'amount': '1',
            'unit': 'Tbsp',
            'notes': 'Use coarse grind',
          },
        ]),
        ingredientsJson: '[]',
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
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        isShared: true,
      );

      final seasonings = recipe.seasoningsList;

      expect(seasonings, hasLength(1));
      expect(seasonings.first.name, 'Kosher Salt');
      expect(seasonings.first.notes, 'Use coarse grind');
    });
  });
}
