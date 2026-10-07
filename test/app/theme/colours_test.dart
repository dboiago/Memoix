import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/app/theme/colours.dart';
import 'package:memoix/features/recipes/models/cuisine.dart';
import 'package:memoix/features/recipes/models/spirit.dart';

void main() {
  group('MemoixColors.forSpiritDot', () {
    test('no Spirit.all code or name falls through to grey', () {
      for (final spirit in Spirit.all) {
        expect(
          MemoixColors.forSpiritDot(spirit.code),
          isNot(Colors.grey),
          reason: 'code ${spirit.code}',
        );
        expect(
          MemoixColors.forSpiritDot(spirit.name),
          isNot(Colors.grey),
          reason: 'name ${spirit.name}',
        );
      }
    });

    test('sub-spirits collapse into their parent colours', () {
      expect(MemoixColors.forSpiritDot('Digestif'), MemoixColors.spiritLiqueur);
      expect(MemoixColors.forSpiritDot('FERNET'), MemoixColors.spiritLiqueur);
      expect(MemoixColors.forSpiritDot('Limoncello'), MemoixColors.spiritLiqueur);
      expect(MemoixColors.forSpiritDot('Soju'), MemoixColors.spiritSparkling);
      expect(MemoixColors.forSpiritDot('Sake'), MemoixColors.spiritSparkling);
      expect(MemoixColors.forSpiritDot('Rosé Wine'), MemoixColors.spiritWine);
      expect(MemoixColors.forSpiritDot('Soda/Tonic'), MemoixColors.spiritMocktail);
    });

    test('an unknown spirit still returns grey', () {
      expect(MemoixColors.forSpiritDot('zorblax'), Colors.grey);
    });
  });

  group('MemoixColors.forContinentDot country codes', () {
    test('every Cuisine.all code resolves to a continent colour', () {
      for (final cuisine in Cuisine.all) {
        expect(
          MemoixColors.forContinentDot(cuisine.code),
          isNot(Colors.grey),
          reason: 'code ${cuisine.code}',
        );
      }
    });

    test('codes follow the Cuisine continent', () {
      expect(MemoixColors.forContinentDot('JP'), MemoixColors.continentAsian);
      expect(MemoixColors.forContinentDot('de'), MemoixColors.continentEuropean);
      expect(MemoixColors.forContinentDot('US'), MemoixColors.continentAmericas);
      expect(MemoixColors.forContinentDot('CR'), MemoixColors.continentAmericas);
      expect(MemoixColors.forContinentDot('BR'), MemoixColors.continentAmericas);
      expect(MemoixColors.forContinentDot('JM'), MemoixColors.continentCaribbean);
      expect(MemoixColors.forContinentDot('NG'), MemoixColors.continentAfrican);
      expect(MemoixColors.forContinentDot('TR'), MemoixColors.continentMiddleEast);
      expect(MemoixColors.forContinentDot('AU'), MemoixColors.continentOceanian);
    });
  });

  group('MemoixColors.forContinentDot multi-country terms', () {
    const parents = {
      'latin': 'latin american',
      'levantine': 'middle eastern',
      'southeast asian': 'asian',
      'east asian': 'asian',
      'south asian': 'asian',
    };

    parents.forEach((term, parent) {
      test('$term matches $parent and not the fallback', () {
        expect(MemoixColors.forContinentDot(term), MemoixColors.forContinentDot(parent));
        expect(
          MemoixColors.forContinentDot(term),
          isNot(MemoixColors.forContinentDot('zorblax')),
        );
      });
    });
  });
}
