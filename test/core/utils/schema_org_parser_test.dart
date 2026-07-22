// Unit tests for SchemaOrgParser: pure, additive helpers that broaden what
// url_importer.dart's JSON-LD stage can recognize, without changing any
// existing output shapes, stage order, or display formatting.
//
// Fixtures below are modeled on real schema.org patterns actually seen in
// the wild (Google's own Recipe rich-results example uses the WebPage +
// mainEntity wrapper; HowToSection/HowToStep nesting and PropertyValue
// ingredients are documented schema.org Recipe conventions used by several
// publisher CMSs), not invented ad hoc shapes.
import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/core/utils/schema_org_parser.dart';

void main() {
  group('SchemaOrgParser.unwrapWebPageMainEntity', () {
    test('unwraps an inline Recipe from a WebPage mainEntity', () {
      final data = {
        '@context': 'https://schema.org',
        '@type': 'WebPage',
        'mainEntity': {
          '@type': 'Recipe',
          'name': 'Monster Cupcakes',
          'recipeIngredient': ['250g self-raising flour'],
        },
      };

      final unwrapped = SchemaOrgParser.unwrapWebPageMainEntity(data);

      expect(unwrapped, isNotNull);
      expect(unwrapped!['@type'], 'Recipe');
      expect(unwrapped['name'], 'Monster Cupcakes');
    });

    test('handles @type as an array containing WebPage', () {
      final data = {
        '@type': ['WebPage', 'Article'],
        'mainEntity': {'@type': 'Recipe', 'name': 'Test Recipe'},
      };

      final unwrapped = SchemaOrgParser.unwrapWebPageMainEntity(data);

      expect(unwrapped, isNotNull);
      expect(unwrapped!['name'], 'Test Recipe');
    });

    test('handles mainEntity as a single-element array', () {
      final data = {
        '@type': 'WebPage',
        'mainEntity': [
          {'@type': 'Recipe', 'name': 'Array Wrapped Recipe'},
        ],
      };

      final unwrapped = SchemaOrgParser.unwrapWebPageMainEntity(data);

      expect(unwrapped, isNotNull);
      expect(unwrapped!['name'], 'Array Wrapped Recipe');
    });

    test('returns null for a non-WebPage node (no interference with Recipe)', () {
      final data = {'@type': 'Recipe', 'name': 'Direct Recipe'};

      expect(SchemaOrgParser.unwrapWebPageMainEntity(data), isNull);
    });

    test('returns null when mainEntity is only an @id reference', () {
      final data = {
        '@type': 'WebPage',
        'mainEntity': {'@id': '#recipe'},
      };

      expect(SchemaOrgParser.unwrapWebPageMainEntity(data), isNull);
    });

    test('returns null when WebPage has no mainEntity at all', () {
      final data = {'@type': 'WebPage', 'name': 'Just a page'};

      expect(SchemaOrgParser.unwrapWebPageMainEntity(data), isNull);
    });
  });

  group('SchemaOrgParser.resolveWebPageMainEntityId', () {
    test('resolves an @id-only mainEntity against @graph siblings', () {
      final graph = [
        {
          '@type': 'WebPage',
          'mainEntity': {'@id': '#recipe'},
        },
        {'@type': 'Recipe', '@id': '#recipe', 'name': 'Graph Recipe'},
      ];

      final resolved = SchemaOrgParser.resolveWebPageMainEntityId(graph[0], graph);

      expect(resolved, isNotNull);
      expect(resolved!['name'], 'Graph Recipe');
    });

    test('gracefully skips when no sibling matches the @id', () {
      final graph = [
        {
          '@type': 'WebPage',
          'mainEntity': {'@id': '#missing'},
        },
        {'@type': 'Recipe', '@id': '#recipe', 'name': 'Graph Recipe'},
      ];

      expect(SchemaOrgParser.resolveWebPageMainEntityId(graph[0], graph), isNull);
    });

    test('returns null for non-WebPage items', () {
      final graph = [
        {'@type': 'Recipe', '@id': '#recipe', 'name': 'Graph Recipe'},
      ];

      expect(SchemaOrgParser.resolveWebPageMainEntityId(graph[0], graph), isNull);
    });
  });

  group('SchemaOrgParser.flattenHowToInstructions', () {
    test('flattens nested HowToSection/HowToStep into bracketed headers + steps', () {
      final instructions = [
        {
          '@type': 'HowToSection',
          'name': 'For the frosting',
          'itemListElement': [
            {'@type': 'HowToStep', 'text': 'Beat the butter until pale.'},
            {'@type': 'HowToStep', 'text': 'Add icing sugar gradually.'},
          ],
        },
        {'@type': 'HowToStep', 'text': 'Pipe onto cooled cupcakes.'},
      ];

      final flattened = SchemaOrgParser.flattenHowToInstructions(instructions);

      expect(flattened, [
        '[For the frosting]',
        'Beat the butter until pale.',
        'Add icing sugar gradually.',
        'Pipe onto cooled cupcakes.',
      ]);
    });

    test('prefers text over name for HowToStep, falls back to name', () {
      final steps = [
        {'@type': 'HowToStep', 'name': 'Step title', 'text': 'The actual instruction.'},
        {'@type': 'HowToStep', 'name': 'Name-only step, no text field'},
      ];

      final flattened = SchemaOrgParser.flattenHowToInstructions(steps);

      expect(flattened, [
        'The actual instruction.',
        'Name-only step, no text field',
      ]);
    });

    test('handles a single HowToStep wrapped in a dict instead of a list', () {
      final section = {
        '@type': 'HowToSection',
        'name': 'Quick step',
        'itemListElement': {'@type': 'HowToStep', 'text': 'Just do this.'},
      };

      final flattened = SchemaOrgParser.flattenHowToInstructions(section);

      expect(flattened, ['[Quick step]', 'Just do this.']);
    });

    test('falls back gracefully for plain strings and legacy maps', () {
      expect(SchemaOrgParser.flattenHowToInstructions('Plain string step'),
          ['Plain string step']);
      expect(
        SchemaOrgParser.flattenHowToInstructions({'text': 'Legacy text field'}),
        ['Legacy text field'],
      );
      expect(SchemaOrgParser.flattenHowToInstructions(null), <String>[]);
    });

    test('recursion depth guard stops on circular/malformed schema', () {
      // Build a self-referential structure deeper than maxHowToDepth.
      late Map<String, dynamic> circular;
      circular = {
        '@type': 'HowToSection',
        'name': 'Loop',
        'itemListElement': <dynamic>[],
      };
      circular['itemListElement'] = [circular];

      // Should terminate (not stack-overflow) and return a bounded result.
      final flattened = SchemaOrgParser.flattenHowToInstructions(circular);
      expect(flattened.length, lessThanOrEqualTo(SchemaOrgParser.maxHowToDepth + 1));
    });
  });

  group('SchemaOrgParser.parseDozenYield', () {
    test('converts whole dozen counts to total integer', () {
      expect(SchemaOrgParser.parseDozenYield('2 dozen cookies'), '24');
      expect(SchemaOrgParser.parseDozenYield('1 dozen'), '12');
    });

    test('converts fractional dozen counts and rounds', () {
      expect(SchemaOrgParser.parseDozenYield('1.5 dozen'), '18');
    });

    test('returns null when no dozen pattern is present', () {
      expect(SchemaOrgParser.parseDozenYield('4 servings'), isNull);
      expect(SchemaOrgParser.parseDozenYield('Makes 12'), isNull);
    });
  });

  group('SchemaOrgParser.extractDurationRangeMinutes', () {
    test('averages a hyphen-separated minute range', () {
      expect(SchemaOrgParser.extractDurationRangeMinutes('12-15 minutes'), 14);
    });

    test('averages an en-dash-separated minute range', () {
      expect(SchemaOrgParser.extractDurationRangeMinutes('12–15 minutes'), 14);
    });

    test('averages an em-dash-separated range', () {
      expect(SchemaOrgParser.extractDurationRangeMinutes('12—15 minutes'), 14);
    });

    test('averages a "to"-separated range and is unit-agnostic for hours', () {
      expect(SchemaOrgParser.extractDurationRangeMinutes('1 to 2 hours'), 90);
    });

    test('returns null when no range is present (single value)', () {
      expect(SchemaOrgParser.extractDurationRangeMinutes('20 minutes'), isNull);
      expect(SchemaOrgParser.extractDurationRangeMinutes('6 hours 20 minutes'), isNull);
    });
  });

  group('SchemaOrgParser.reconstructPropertyValueIngredient', () {
    test('reconstructs "value unit name" from a PropertyValue node', () {
      final item = {
        '@type': 'PropertyValue',
        'value': 250,
        'unitText': 'g',
        'name': 'all-purpose flour',
      };

      expect(
        SchemaOrgParser.reconstructPropertyValueIngredient(item),
        '250 g all-purpose flour',
      );
    });

    test('falls back to unitCode when unitText is absent', () {
      final item = {
        '@type': 'PropertyValue',
        'value': '2',
        'unitCode': 'CUP',
        'name': 'sugar',
      };

      expect(
        SchemaOrgParser.reconstructPropertyValueIngredient(item),
        '2 CUP sugar',
      );
    });

    test('returns null for non-PropertyValue maps (existing fallback applies)', () {
      final item = {'text': 'ordinary ingredient line'};

      expect(SchemaOrgParser.reconstructPropertyValueIngredient(item), isNull);
    });

    test('returns null when reconstruction produces nothing usable', () {
      final item = {'@type': 'PropertyValue'};

      expect(SchemaOrgParser.reconstructPropertyValueIngredient(item), isNull);
    });
  });
}
