import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/core/utils/amount_scaler.dart';
import 'package:memoix/core/utils/amount_utils.dart';

void main() {
  // ── AmountUtils.formatRaw ─────────────────────────────────────────────────
  group('AmountUtils.formatRaw', () {
    test('integer passthrough', () {
      expect(AmountUtils.formatRaw('2'), '2');
    });

    test('strips trailing .0', () {
      expect(AmountUtils.formatRaw('2.0'), '2');
    });

    test('mixed decimal → mixed unicode fraction', () {
      expect(AmountUtils.formatRaw('1.5'), '1½');
    });

    test('standalone decimal → unicode fraction', () {
      expect(AmountUtils.formatRaw('0.5'), '½');
    });

    test('text fraction → unicode fraction', () {
      expect(AmountUtils.formatRaw('1/2'), '½');
    });

    test('mixed text fraction → unicode fraction', () {
      expect(AmountUtils.formatRaw('1 1/2'), '1½');
    });

    test('range string is not modified', () {
      expect(AmountUtils.formatRaw('2-3'), '2-3');
    });

    test('freeform non-numeric passes through', () {
      expect(AmountUtils.formatRaw('to taste'), 'to taste');
    });

    test('quarter decimal', () {
      expect(AmountUtils.formatRaw('1.25'), '1¼');
    });

    test('three-quarter decimal', () {
      expect(AmountUtils.formatRaw('2.75'), '2¾');
    });

    test('eighth decimal', () {
      expect(AmountUtils.formatRaw('0.125'), '⅛');
    });

    test('empty string returns empty', () {
      expect(AmountUtils.formatRaw(''), '');
    });
  });

  // ── AmountUtils.parse ─────────────────────────────────────────────────────
  group('AmountUtils.parse', () {
    test('integer', () {
      expect(AmountUtils.parse('1'), 1.0);
    });

    test('unicode fraction glyph', () {
      expect(AmountUtils.parse('½'), 0.5);
    });

    test('mixed number: concatenated glyph', () {
      expect(AmountUtils.parse('1½'), 1.5);
    });

    test('mixed number: space-separated glyph', () {
      expect(AmountUtils.parse('1 ½'), 1.5);
    });

    test('text fraction', () {
      expect(AmountUtils.parse('1/2'), 0.5);
    });

    test('mixed text fraction "1 1/2"', () {
      expect(AmountUtils.parse('1 1/2'), 1.5);
    });

    test('decimal string', () {
      expect(AmountUtils.parse('2.5'), 2.5);
    });

    test('range string returns 0.0 (use parseMax for ranges)', () {
      expect(AmountUtils.parse('2-3'), 0.0);
    });

    test('freeform non-numeric returns 0.0', () {
      expect(AmountUtils.parse('to taste'), 0.0);
    });

    test('null returns 0.0', () {
      expect(AmountUtils.parse(null), 0.0);
    });

    test('empty string returns 0.0', () {
      expect(AmountUtils.parse(''), 0.0);
    });

    test('one-third glyph', () {
      expect(AmountUtils.parse('⅓'), closeTo(1.0 / 3.0, 1e-10));
    });

    test('mixed number with third', () {
      expect(AmountUtils.parse('1⅓'), closeTo(4.0 / 3.0, 1e-10));
    });
  });

  // ── AmountUtils.parseMax ──────────────────────────────────────────────────
  group('AmountUtils.parseMax', () {
    test('range returns maximum (upper) value', () {
      expect(AmountUtils.parseMax('2-3'), 3.0);
    });

    test('en-dash range', () {
      expect(AmountUtils.parseMax('2–4'), 4.0);
    });

    test('range with fraction glyphs on upper end', () {
      expect(AmountUtils.parseMax('1-1½'), 1.5);
    });

    test('single value passes through normally', () {
      expect(AmountUtils.parseMax('2'), 2.0);
    });

    test('null returns 0.0', () {
      expect(AmountUtils.parseMax(null), 0.0);
    });
  });

  // ── AmountUtils.format ────────────────────────────────────────────────────
  group('AmountUtils.format', () {
    test('whole number', () {
      expect(AmountUtils.format(3.0), '3');
    });

    test('mixed number → glyph', () {
      expect(AmountUtils.format(1.5), '1½');
    });

    test('pure fraction → glyph', () {
      expect(AmountUtils.format(0.5), '½');
    });

    test('one-third', () {
      expect(AmountUtils.format(1.0 / 3.0), '⅓');
    });

    test('two-thirds', () {
      expect(AmountUtils.format(2.0 / 3.0), '⅔');
    });

    test('one-eighth', () {
      expect(AmountUtils.format(0.125), '⅛');
    });

    test('three-quarters mixed', () {
      expect(AmountUtils.format(2.75), '2¾');
    });

    test('floating-point artefact near whole number rounds up', () {
      // 1/3 * 3 in IEEE 754 double precision is not exactly 1.0;
      // the snap-to-unity logic must handle this.
      final almostOne = (1.0 / 3.0) * 3.0;
      expect(AmountUtils.format(almostOne), '1');
    });

    test('value <= 0 returns "0"', () {
      expect(AmountUtils.format(0.0), '0');
    });
  });

  // ── AmountUtils.extractBaselineServes ─────────────────────────────────────
  group('AmountUtils.extractBaselineServes', () {
    test('null returns 1.0', () {
      expect(AmountUtils.extractBaselineServes(null), 1.0);
    });

    test('empty string returns 1.0', () {
      expect(AmountUtils.extractBaselineServes(''), 1.0);
    });

    test('bare integer', () {
      expect(AmountUtils.extractBaselineServes('4'), 4.0);
    });

    test('with leading word "Serves"', () {
      expect(AmountUtils.extractBaselineServes('Serves 4'), 4.0);
    });

    test('with trailing word "people"', () {
      expect(AmountUtils.extractBaselineServes('4 people'), 4.0);
    });

    test('range returns midpoint', () {
      expect(AmountUtils.extractBaselineServes('4-6'), 5.0);
    });

    test('range with en-dash returns midpoint', () {
      expect(AmountUtils.extractBaselineServes('2–4'), 3.0);
    });

    test('unparseable text returns 1.0', () {
      expect(AmountUtils.extractBaselineServes('many'), 1.0);
    });
  });

  // ── AmountScaler.scale ────────────────────────────────────────────────────
  group('AmountScaler.scale — basic numeric', () {
    test('integer × factor', () {
      expect(AmountScaler.scale('2', 1.5), '3');
    });

    test('integer halved', () {
      expect(AmountScaler.scale('4', 0.5), '2');
    });

    test('unicode fraction × whole number', () {
      expect(AmountScaler.scale('½', 2.0), '1');
    });

    test('mixed number doubled', () {
      // "1½" × 2 = 3.0
      expect(AmountScaler.scale('1½', 2.0), '3');
    });

    test('text fraction × factor', () {
      // "1/2" × 3 = 1.5 → "1½"
      expect(AmountScaler.scale('1/2', 3.0), '1½');
    });

    test('one-third × 3 handles float artefact → "1"', () {
      // parse("⅓") * 3 is not exactly 1.0 in IEEE 754;
      // snap-to-unity must cover this.
      expect(AmountScaler.scale('⅓', 3.0), '1');
    });

    test('two-thirds × 3 = 2', () {
      expect(AmountScaler.scale('⅔', 3.0), '2');
    });
  });

  group('AmountScaler.scale — ranges', () {
    test('integer range × 1.5', () {
      // lower: 2 × 1.5 = 3, upper: 3 × 1.5 = 4.5 → "4½"
      expect(AmountScaler.scale('2-3', 1.5), '3-4½');
    });

    test('range with en-dash', () {
      expect(AmountScaler.scale('2–4', 2.0), '4-8');
    });

    test('range doubled produces correct bounds', () {
      expect(AmountScaler.scale('1-2', 2.0), '2-4');
    });
  });

  group('AmountScaler.scale — qualifier prefixes', () {
    test('"about N" preserves prefix', () {
      expect(AmountScaler.scale('about 3', 2.0), 'about 6');
    });

    test('"approx N" preserves prefix', () {
      expect(AmountScaler.scale('approx 2', 3.0), 'approx 6');
    });

    test('"around N" preserves prefix', () {
      expect(AmountScaler.scale('around 4', 0.5), 'around 2');
    });
  });

  group('AmountScaler.scale — parenthetical descriptors', () {
    test('"1 (14 oz) can" × 3 scales number, preserves descriptor', () {
      expect(AmountScaler.scale('1 (14 oz) can', 3.0), '3 (14 oz) can');
    });

    test('"2 (400g) tins" × 2', () {
      expect(AmountScaler.scale('2 (400g) tins', 2.0), '4 (400g) tins');
    });
  });

  group('AmountScaler.scale — freeform passthrough', () {
    test('"to taste" is always returned unchanged', () {
      expect(AmountScaler.scale('to taste', 2.0), 'to taste');
    });

    test('"for frying" is always returned unchanged', () {
      expect(AmountScaler.scale('for frying', 4.0), 'for frying');
    });

    test('"a pinch" is returned unchanged', () {
      expect(AmountScaler.scale('a pinch', 2.0), 'a pinch');
    });

    test('null is returned as null', () {
      expect(AmountScaler.scale(null, 2.0), null);
    });

    test('empty string returned unchanged', () {
      expect(AmountScaler.scale('', 2.0), '');
    });
  });

  group('AmountScaler.scale — factor edge cases', () {
    test('factor of 1.0 normalizes without arithmetic', () {
      // "1/2" should be display-normalized to "½"
      expect(AmountScaler.scale('1/2', 1.0), '½');
    });

    test('factor of 1.0 on integer normalizes', () {
      expect(AmountScaler.scale('2.0', 1.0), '2');
    });

    test('scaling down: 4 × 0.25 = 1', () {
      expect(AmountScaler.scale('4', 0.25), '1');
    });

    test('non-integer result formats as fraction', () {
      // 1 × 0.5 = 0.5 → "½"
      expect(AmountScaler.scale('1', 0.5), '½');
    });
  });

  group('AmountScaler.scale — hyphen ambiguity', () {
    test('non-numeric hyphenated word is not treated as range', () {
      // "all-purpose" should pass through: _isLikelyNumeric("all") = false.
      // In practice this would never be in an amount field, but we ensure
      // freeform passthrough guards it.
      expect(AmountScaler.scale('all-purpose', 2.0), 'all-purpose');
    });

    test('negative-style lone hyphen passes through', () {
      // "-1" splits to ["", "1"]; empty first part → not a range.
      expect(AmountScaler.scale('-1', 2.0), '-1');
    });
  });
}
