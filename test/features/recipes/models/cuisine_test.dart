import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/features/recipes/models/cuisine.dart';

void main() {
  group('Cuisine.codeFor', () {
    test('resolves every Cuisine.all code and name to its code', () {
      for (final cuisine in Cuisine.all) {
        expect(
          Cuisine.codeFor(cuisine.code),
          cuisine.code,
          reason: 'code ${cuisine.code}',
        );
        expect(
          Cuisine.codeFor(cuisine.name),
          cuisine.code,
          reason: 'name ${cuisine.name} (${cuisine.code})',
        );
      }
    });

    test('maps country, demonym and regional terms for Germany to DE', () {
      for (final raw in ['Germany', 'German', 'Bavarian']) {
        expect(Cuisine.codeFor(raw), 'DE', reason: raw);
      }
    });

    test('maps American regional cuisines to US', () {
      for (final raw in ['Cajun', 'Tex-Mex', 'Southern']) {
        expect(Cuisine.codeFor(raw), 'US', reason: raw);
      }
    });

    test('maps the nations of Britain to GB', () {
      for (final raw in [
        'English',
        'England',
        'Scottish',
        'Scotland',
        'Welsh',
        'Wales',
      ]) {
        expect(Cuisine.codeFor(raw), 'GB', reason: raw);
      }
    });

    test('maps Iranian to IR', () {
      expect(Cuisine.codeFor('Iranian'), 'IR');
    });

    test('returns null for non-country and empty input', () {
      for (final raw in <String?>[
        'Asian',
        'Mediterranean',
        'French-German',
        '',
        null,
      ]) {
        expect(Cuisine.codeFor(raw), isNull, reason: '$raw');
      }
    });
  });
}
