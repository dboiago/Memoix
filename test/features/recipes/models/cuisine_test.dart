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

    test('keeps English, England and Iranian as cuisine synonyms', () {
      expect(Cuisine.codeFor('English'), 'GB');
      expect(Cuisine.codeFor('England'), 'GB');
      expect(Cuisine.codeFor('Iranian'), 'IR');
    });

    test('maps Hawaiian input to US and no longer resolves HI', () {
      expect(Cuisine.codeFor('Hawaiian'), 'US');
      expect(Cuisine.codeFor('Hawaii'), 'US');
      expect(Cuisine.codeFor('HI'), isNull);
    });

    test('resolves country names and alternate forms to their cuisine code', () {
      const expected = {
        'Algeria': 'DZ',
        'Cameroon': 'CM',
        'Senegal': 'SN',
        'Tanzania': 'TZ',
        'Uganda': 'UG',
        'Costa Rica': 'CR',
        'El Salvador': 'SV',
        'Guatemala': 'GT',
        'Honduras': 'HN',
        'Nicaragua': 'NI',
        'Panama': 'PA',
        'Bolivia': 'BO',
        'Ecuador': 'EC',
        'Paraguay': 'PY',
        'Uruguay': 'UY',
        'Bangladesh': 'BD',
        'Myanmar': 'MM',
        'Burma': 'MM',
        'Cambodia': 'KH',
        'Laos': 'LA',
        'Mongolia': 'MN',
        'Bahamas': 'BS',
        'Guyana': 'GY',
        'Albania': 'AL',
        'Belarus': 'BY',
        'Bosnia': 'BA',
        'Bosnia and Herzegovina': 'BA',
        'Bulgaria': 'BG',
        'Cyprus': 'CY',
        'Estonia': 'EE',
        'Latvia': 'LV',
        'Lithuania': 'LT',
        'Iceland': 'IS',
        'Malta': 'MT',
        'Moldova': 'MD',
        'Montenegro': 'ME',
        'Slovakia': 'SK',
        'Slovenia': 'SI',
        'Bahrain': 'BH',
        'UAE': 'AE',
        'Emirates': 'AE',
        'United Arab Emirates': 'AE',
        'Kuwait': 'KW',
        'Oman': 'OM',
        'Qatar': 'QA',
        'Papua New Guinea': 'PG',
        'Tonga': 'TO',
        'Argentinian': 'AR',
        'Czechia': 'CZ',
        'Holland': 'NL',
      };
      expected.forEach((raw, code) {
        expect(Cuisine.codeFor(raw), code, reason: raw);
      });
    });

    test('matches whole terms only, so added aliases do not match inside other words', () {
      expect(Cuisine.codeFor('Romanian'), 'RO');
      expect(Cuisine.codeFor('Romania'), 'RO');
      expect(Cuisine.codeFor('Roman'), 'IT');
      expect(Cuisine.codeFor('Georgian'), 'GE');
      for (final raw in ['Mali', 'Guinea', 'Niger', 'Georgia']) {
        expect(Cuisine.codeFor(raw), isNull, reason: raw);
      }
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

  group('Cuisine.codeFor regions', () {
    test('maps Basque to Spanish and Manchurian to Indian', () {
      expect(Cuisine.codeFor('Basque'), 'ES');
      expect(Cuisine.codeFor('Manchurian'), 'IN');
    });

    test('leaves multi-country regions without a cuisine', () {
      expect(Cuisine.codeFor('Levantine'), isNull);
      expect(Cuisine.codeFor('Creole'), isNull);
    });
  });

  group('Cuisine.regionFor', () {
    test('returns the capitalised term for sub-regions and multi-country styles in any case', () {
      const expected = {
        'Sichuan': 'Sichuan',
        'Szechuan': 'Szechuan',
        'Cajun': 'Cajun',
        'Bavarian': 'Bavarian',
        'Latin': 'Latin',
        'Basque': 'Basque',
        'Manchurian': 'Manchurian',
        'Levantine': 'Levantine',
        'Creole': 'Creole',
      };
      expected.forEach((word, result) {
        for (final variant in [word.toLowerCase(), word.toUpperCase(), word]) {
          expect(Cuisine.regionFor(variant), result, reason: variant);
        }
      });
    });

    test('returns null for cuisines, synonyms, empty and null input', () {
      for (final raw in <String?>[
        'Chinese',
        'Austrian',
        'English',
        'Iranian',
        'England',
        '',
        null,
      ]) {
        expect(Cuisine.regionFor(raw), isNull, reason: '$raw');
      }
    });
  });

  group('Cuisine.displayFor', () {
    test('uses the cuisine name when there is no region', () {
      expect(Cuisine.displayFor('DE', null)?.label, 'German');
    });

    test('matches displayWithRegion when cuisine is set', () {
      final result = Cuisine.displayFor('CN', 'Sichuan');
      expect(result?.label, Cuisine.displayWithRegion('CN', 'Sichuan'));
      expect(result?.colourKey, 'CN');
    });

    test('shows a known region on its own when cuisine is empty', () {
      final sichuan = Cuisine.displayFor(null, 'Sichuan');
      expect(sichuan?.label, 'Sichuan');
      expect(Cuisine.codeFor(sichuan?.colourKey), 'CN');
      expect(Cuisine.displayFor(null, 'Mediterranean')?.label, 'Mediterranean');
      expect(Cuisine.displayFor(null, 'Latin')?.label, 'Latin');
      expect(Cuisine.displayFor(null, 'Hawaiian')?.label, 'Hawaiian');
    });

    test('returns null for unknown or empty input', () {
      expect(Cuisine.displayFor(null, 'Zorblax'), isNull);
      expect(Cuisine.displayFor('', ''), isNull);
      expect(Cuisine.displayFor('  ', '  '), isNull);
      expect(Cuisine.displayFor(null, null), isNull);
    });
  });
}
