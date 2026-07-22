// Unit tests for UrlRecipeImporter's raw-directions extraction path.
//
// Covers the additive HowToSection/HowToStep flattening applied to
// `_extractRawDirections` (exercised here via the `@visibleForTesting`
// `extractRawDirectionsForTesting` accessor), which reuses
// `SchemaOrgParser.flattenHowToInstructions` — the same helper already used
// by `_parseInstructions` for the parsed `directions` field — so both import
// routes (parsed `directions` and the review screen's `rawDirections`)
// produce identical `[Section Name]` structure.
import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/core/services/url_importer.dart';

void main() {
  group('UrlRecipeImporter raw directions extraction', () {
    test('flattens nested HowToSection/HowToStep into [Section] headers', () {
      final importer = UrlRecipeImporter();
      final instructions = [
        {
          '@type': 'HowToSection',
          'name': 'For the glaze',
          'itemListElement': [
            {'@type': 'HowToStep', 'text': 'Whisk sugar and lemon juice.'},
            {'@type': 'HowToStep', 'text': 'Simmer until thick.'},
          ],
        },
        {
          '@type': 'HowToSection',
          'name': 'For the cake',
          'itemListElement': [
            {'@type': 'HowToStep', 'text': 'Mix flour and butter.'},
          ],
        },
      ];

      final rawDirections = importer.extractRawDirectionsForTesting(instructions);

      // Same [Section Name] structure that _parseInstructions already
      // produces for the parsed `directions` field.
      expect(rawDirections, [
        '[For the glaze]',
        'Whisk sugar and lemon juice.',
        'Simmer until thick.',
        '[For the cake]',
        'Mix flour and butter.',
      ]);
    });

    test('falls back to existing flat text/name behaviour when no HowTo types are present', () {
      final importer = UrlRecipeImporter();
      final instructions = [
        'Preheat oven to 350F.',
        {'text': 'Bake for 20 minutes.'},
      ];

      final rawDirections = importer.extractRawDirectionsForTesting(instructions);

      expect(rawDirections, [
        'Preheat oven to 350F.',
        'Bake for 20 minutes.',
      ]);
    });

    test('returns empty list for null input, unchanged from prior behaviour', () {
      final importer = UrlRecipeImporter();
      expect(importer.extractRawDirectionsForTesting(null), <String>[]);
    });
  });
}
