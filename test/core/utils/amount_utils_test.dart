import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/core/utils/amount_scaler.dart';
import 'package:memoix/core/utils/amount_utils.dart';
import 'package:memoix/core/utils/ingredient_categorizer.dart';

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
    test('factor of 1.0 returns rawAmount unchanged (short-circuit)', () {
      // No processing at all — the stored string is returned exactly as-is.
      expect(AmountScaler.scale('1/2', 1.0), '1/2');
    });

    test('factor of 1.0 on written-out decimal returns unchanged', () {
      // Before the fix this was normalised to '2'; now the raw value is preserved.
      expect(AmountScaler.scale('2.0', 1.0), '2.0');
    });

    test('scaling down: 4 × 0.25 = 1', () {
      expect(AmountScaler.scale('4', 0.25), '1');
    });

    test('non-integer result formats as fraction', () {
      // 1 × 0.5 = 0.5 → "½"
      expect(AmountScaler.scale('1', 0.5), '½');
    });
  });

  // ── Factor=1.0 passthrough regression guard ───────────────────────────────
  //
  // Before the short-circuit fix the full pipeline ran at factor=1.0,
  // reformatting stored strings and triggering unit escalation on unscaled
  // recipes.  Every format that occurs in real recipe data must survive
  // AmountScaler.scale(input, 1.0) == input exactly.

  group('AmountScaler.scale — factor=1.0 passthrough (regression guard)', () {
    test('"1/2 tsp" returns unchanged', () {
      expect(AmountScaler.scale('1/2 tsp', 1.0), '1/2 tsp');
    });

    test('"½ C" returns unchanged', () {
      expect(AmountScaler.scale('½ C', 1.0), '½ C');
    });

    test('"1½ Tbsp" returns unchanged', () {
      expect(AmountScaler.scale('1½ Tbsp', 1.0), '1½ Tbsp');
    });

    test('"2-3" returns unchanged', () {
      expect(AmountScaler.scale('2-3', 1.0), '2-3');
    });

    test('"to taste" returns unchanged', () {
      expect(AmountScaler.scale('to taste', 1.0), 'to taste');
    });

    test('"1 (14 oz) can" returns unchanged', () {
      expect(AmountScaler.scale('1 (14 oz) can', 1.0), '1 (14 oz) can');
    });

    test('null returns null', () {
      expect(AmountScaler.scale(null, 1.0), null);
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

  // ── AmountScaler upgrade: power law, snap-to-grid, escalation ─────────────
  //
  // ScalingCategory mapping used in these tests:
  //   salt keywords   → ScalingCategory.salt      (exponent 0.75)
  //   spice category  → ScalingCategory.spice     (exponent 0.68)
  //   heat keywords   → ScalingCategory.heat      (exponent 0.62)
  //   leavening kwds  → ScalingCategory.leavening (exponent 0.80)
  //   aromatic kwds   → ScalingCategory.aromatic  (exponent 0.82)
  //   null / unmapped → ScalingCategory.linear    (exponent 1.0)
  //
  // Key pre-calculated values (scaledAmount = raw × factor^exp):
  //   "1 tsp" salt   ×4 (salt/0.75):  1 × 4^0.75 = 2.828 → spoon-grid 2¾ tsp → 2.75/3≈0.917 not clean
  //   "½ C"          ×1.444 (linear): 0.5 × 1.444 = 0.722 → full-grid ¾ C
  //   "½ tsp" spice  ×1.444 (spice/0.68): 0.5 × 1.444^0.68 = 0.5×1.274 = 0.637 → spoon-grid ½ tsp (d=0.137 vs ¾ d=0.113) → ¾
  //     wait: recalc: 1.444^0.68 = e^(0.68×ln1.444) = e^(0.68×0.3674) = e^0.2498 = 1.2837
  //     → 0.5 × 1.2837 = 0.6418; spoon grid: ½(d=0.1418) vs ¾(d=0.1082) → snaps to ¾ tsp
  //   "2 eggs"       ×1.444 (countable): 2 × 1.444 = 2.888 → round → 3
  //   "½ tsp"        ×0.25  (linear):   0.5 × 0.25 = 0.125 → floor → ⅛ tsp
  //   "3 tsp"        ×2     (linear):   3 × 2 = 6 tsp ÷ 3 = 2 (int) → escalate → 2 Tbsp

  group('AmountScaler.scale — power-law dampening (ScalingCategory)', () {
    test('"1 tsp" salt ×4 (salt/0.75): 1×4^0.75=2.828 → snaps 2¾ tsp → no clean escalation', () {
      // 4^0.75 = 2^1.5 = 2.8284; spoon grid: whole=2, frac=0.828;
      // spoon grid: ¾=0.75(d=0.078) beats ½(d=0.328) → snaps 2¾ tsp
      // 2.75/3 = 0.9167 → not a nice fraction → no escalation
      expect(
        AmountScaler.scale('1', 4.0, unit: 'tsp', scalingCategory: ScalingCategory.salt),
        '2¾ tsp',
      );
    });

    test('"½ tsp" cinnamon ×1.444 (spice/0.68): → snaps ¾ tsp', () {
      // 1.444^0.68 = e^(0.68×0.3674) = e^0.2498 = 1.2837
      // 0.5 × 1.2837 = 0.6418; spoon grid: ¾(d=0.1082) beats ½(d=0.1418) → ¾ tsp
      expect(
        AmountScaler.scale('1/2', 1.444, unit: 'tsp', scalingCategory: ScalingCategory.spice),
        '¾ tsp',
      );
    });

    test('null scalingCategory → linear scaling (exponent 1.0)', () {
      // 1 × 4 = 4 tsp → 4/3 not clean; stays 4 tsp
      expect(AmountScaler.scale('1', 4.0, unit: 'tsp'), '4 tsp');
    });

    test('linear ScalingCategory → exponent 1.0', () {
      expect(
        AmountScaler.scale('1', 4.0, unit: 'tsp', scalingCategory: ScalingCategory.linear),
        '4 tsp',
      );
    });

    test('aromatic dampening (0.82): "4" cloves ×4 → 4×4^0.82=4×3.261=13.044 → countable round 13', () {
      // 4^0.82 = e^(0.82×ln4) = e^(0.82×1.3863) = e^1.1368 = 3.1157
      // 4 × 3.1157 = 12.463 → round → 12
      expect(
        AmountScaler.scale('4', 4.0, unit: 'cloves', scalingCategory: ScalingCategory.aromatic),
        '12',
      );
    });
  });

  group('AmountScaler.scale — snap-to-grid', () {
    test('"½ C" ×1.444: linear → 0.722 → full grid → ¾ C', () {
      // 0.5 × 1.444 = 0.722; full grid: ¾(d=0.028) beats ⅔(d=0.055)
      expect(AmountScaler.scale('1/2', 1.444, unit: 'C'), '¾ C');
    });

    test('minimum floor: "½ tsp" ×0.25 → 0.125 → ⅛ tsp', () {
      expect(AmountScaler.scale('1/2', 0.25, unit: 'tsp'), '⅛ tsp');
    });

    test('sub-floor amount stays at ⅛', () {
      // 0.5 × 0.1 = 0.05, below ⅛ → floor to ⅛
      expect(AmountScaler.scale('1/2', 0.1, unit: 'tsp'), '⅛ tsp');
    });

    test('full grid allows thirds for cups', () {
      // "1/3 C" × 2 (linear): 0.333 × 2 = 0.667 → full grid snaps to ⅔
      expect(AmountScaler.scale('1/3', 2.0, unit: 'C'), '⅔ C');
    });

    test('spoon grid excludes thirds: near-⅓ tsp snaps to ¼, not ⅓', () {
      // "1/3 tsp" × 1.1: 0.333 × 1.1 = 0.367; spoon grid {1/8,¼,½,¾}:
      // ¼(d=0.117) beats all others; ⅓ and ⅔ absent from spoon grid
      expect(AmountScaler.scale('1/3', 1.1, unit: 'tsp'), '¼ tsp');
    });

    test('countable: "2 eggs" ×1.444 rounds to nearest whole', () {
      // 2 × 1.444 = 2.888 → round → 3
      expect(AmountScaler.scale('2', 1.444), '3');
    });

    test('countable: ½ is allowed for non-whole mid-range', () {
      // 1 × 0.6 = 0.6 → countable, < 0.75 → ½
      expect(AmountScaler.scale('1', 0.6), '½');
    });
  });

  // ── Unit escalation — fires only on clean whole-number results ─────────────────
  //
  // Fractional results (e.g. 8 Tbsp ÷ 16 = 0.5) do NOT escalate. Only
  // integer conversions (6 tsp ÷ 3 = 2) trigger a unit change. The
  // volume ladder stops at cup — pt, qt, gal are not in the ladder.
  //
  // Factor=1.0 short-circuits before escalation runs (regression guard),
  // so these tests use factor ≠ 1.0.
  group('AmountScaler.scale — unit escalation (integer-only, stops at cup)', () {
    test('"1 tsp" ×3: 3 tsp ÷ 3 = 1 (int) → "1 Tbsp"', () {
      expect(AmountScaler.scale('1', 3.0, unit: 'tsp'), '1 Tbsp');
    });

    test('"3 tsp" ×2: 6 tsp ÷ 3 = 2 (int) → "2 Tbsp"', () {
      expect(AmountScaler.scale('3', 2.0, unit: 'tsp'), '2 Tbsp');
    });

    test('"5 tsp" ×2: 10 tsp ÷ 3 = 3.33 (not int) → stays "10 tsp"', () {
      expect(AmountScaler.scale('5', 2.0, unit: 'tsp'), '10 tsp');
    });

    test('"1 Tbsp" ×16: 16 Tbsp ÷ 16 = 1 (int) → "1 C"', () {
      expect(AmountScaler.scale('1', 16.0, unit: 'Tbsp'), '1 C');
    });

    test('"4 Tbsp" ×2: 8 Tbsp ÷ 16 = 0.5 (not int) → stays "8 Tbsp"', () {
      expect(AmountScaler.scale('4', 2.0, unit: 'Tbsp'), '8 Tbsp');
    });

    test('"1 C" ×4: 4 C — no pt/qt/gal in ladder → stays "4 C"', () {
      expect(AmountScaler.scale('1', 4.0, unit: 'C'), '4 C');
    });

    test('metric: "500 ml" ×2: 1000 ml ÷ 1000 = 1 (int) → "1 L"', () {
      expect(AmountScaler.scale('500', 2.0, unit: 'ml'), '1 L');
    });
  });

  group('AmountScaler.scale — leavening dampening', () {
    test('"1 tsp" baking powder ×4 (leavening/0.80): 1×4^0.80=3.031 → 3⅛ tsp', () {
      // 4^0.80 = 3.0314; whole=3, frac=0.0314 (>1/48 so not snapped to whole);
      // spoon grid nearest: ⅛(d=0.094) → 3⅛ tsp; 3.125/3=1.042 not clean.
      expect(
        AmountScaler.scale('1', 4.0, unit: 'tsp', scalingCategory: ScalingCategory.leavening),
        '3⅛ tsp',
      );
    });
  });

  // ── Escalation boundary tests ─────────────────────────────────────────────
  //
  // These cases verify the interaction of snap-to-grid + integer-only
  // escalation.  None of the snapped values below divide cleanly (integer)
  // into the next-larger unit, so they all stay in their current unit.
  // Cases that DO escalate are already covered in the escalation group above.

  group('AmountScaler.scale — escalation boundaries', () {
    test('"1 C" ×1.444: 1.444 C → snaps "1½ C" — 1.5÷2=0.75 not int, no pt step → "1½ C"', () {
      // 1 × 1.444 = 1.444; full grid: ½(d=0.056) → 1½ C
      // C has no ladder step (pt/qt/gal removed) → stays cups regardless
      expect(AmountScaler.scale('1', 1.444, unit: 'C'), '1½ C');
    });

    test('"½ tsp" ×1.444 (spice/0.68): dampened 0.6418 tsp → snaps ¾ tsp — 0.75÷3=0.25 not int → "¾ tsp"', () {
      // 1.444^0.68 = 1.2837; 0.5 × 1.2837 = 0.6418; spoon grid: ¾(d=0.108)
      // 0.75 ÷ 3 = 0.25 → not integer → no escalation
      expect(
        AmountScaler.scale('1/2', 1.444, unit: 'tsp', scalingCategory: ScalingCategory.spice),
        '¾ tsp',
      );
    });

    test('"1 tsp" salt ×1.444 (salt/0.75): 1.3173 → snaps "1¼ tsp" — 1.25÷3=0.417 not int → "1¼ tsp"', () {
      // 1.444^0.75 = e^(0.75×0.3674) = e^0.2756 = 1.3173
      // spoon grid: ¼(d=0.067) beats ½(d=0.183) → 1¼ tsp
      // 1.25 ÷ 3 = 0.4167 → not integer → no escalation
      expect(
        AmountScaler.scale('1', 1.444, unit: 'tsp', scalingCategory: ScalingCategory.salt),
        '1¼ tsp',
      );
    });

    test('"3 tsp" ×1.0: factor short-circuits before escalation → "3 tsp"', () {
      expect(AmountScaler.scale('3', 1.0, unit: 'tsp'), '3 tsp');
    });

    test('"3 tsp" ×2.0: 6 tsp ÷ 3 = 2 (int) → "2 Tbsp"', () {
      expect(AmountScaler.scale('3', 2.0, unit: 'tsp'), '2 Tbsp');
    });

    test('"1 C" ×4.0: 4 C — no ladder step beyond cup → "4 C"', () {
      expect(AmountScaler.scale('1', 4.0, unit: 'C'), '4 C');
    });

    test('"½ tsp" ×1.444 (spice): stays tsp, no escalation', () {
      // Duplicate of the spice test above, expressed as the spec table requires
      expect(
        AmountScaler.scale('1/2', 1.444, unit: 'tsp', scalingCategory: ScalingCategory.spice),
        '¾ tsp',
      );
    });
  });

  group('AmountScaler.scale — freeform passthrough (confirmed correct)', () {
    test('"to taste" passes through unchanged', () {
      expect(AmountScaler.scale('to taste', 4.0), 'to taste');
    });

    test('"for frying" passes through unchanged', () {
      expect(AmountScaler.scale('for frying', 2.0), 'for frying');
    });

    test('"a pinch" passes through unchanged', () {
      expect(AmountScaler.scale('a pinch', 2.0), 'a pinch');
    });

    test('"as needed" passes through unchanged', () {
      expect(AmountScaler.scale('as needed', 3.0), 'as needed');
    });

    test('"overnight" passes through unchanged', () {
      expect(AmountScaler.scale('overnight', 2.0), 'overnight');
    });

    test('"several hours" passes through unchanged', () {
      expect(AmountScaler.scale('several hours', 2.0), 'several hours');
    });

    test('null passes through as null', () {
      expect(AmountScaler.scale(null, 2.0), null);
    });

    test('empty string passes through unchanged', () {
      expect(AmountScaler.scale('', 2.0), '');
    });
  });

  group('AmountScaler.scale — qualifier prefix', () {
    test('"about 3" ×2 neutral → "about 6"', () {
      expect(AmountScaler.scale('about 3', 2.0), 'about 6');
    });

    test('"about 3" qualifier preserved with dampening (heat/0.62)', () {
      // 3 × 4^0.62 = 3 × e^(0.62×1.3863) = 3 × e^0.8595 = 3 × 2.362 = 7.086
      // countable: round(7.086) = 7
      expect(
        AmountScaler.scale('about 3', 4.0, scalingCategory: ScalingCategory.heat),
        'about 7',
      );
    });
  });

  // ── ScalingClassifier.classifyForScaling ──────────────────────────────────
  group('ScalingClassifier.classifyForScaling — keyword priority', () {
    test('salt keyword wins over spice category', () {
      expect(
        ScalingClassifier.classifyForScaling('kosher salt', IngredientCategory.spice),
        ScalingCategory.salt,
      );
    });

    test('soy sauce → salt (keyword override of condiment category)', () {
      expect(
        ScalingClassifier.classifyForScaling('soy sauce', IngredientCategory.condiment),
        ScalingCategory.salt,
      );
    });

    test('fish sauce → salt', () {
      expect(
        ScalingClassifier.classifyForScaling('fish sauce', IngredientCategory.condiment),
        ScalingCategory.salt,
      );
    });

    test('jalapeño → heat', () {
      expect(
        ScalingClassifier.classifyForScaling('jalapeño, diced', null),
        ScalingCategory.heat,
      );
    });

    test('cayenne → heat (despite spice category)', () {
      expect(
        ScalingClassifier.classifyForScaling('cayenne pepper', IngredientCategory.spice),
        ScalingCategory.heat,
      );
    });

    test('sriracha → heat', () {
      expect(
        ScalingClassifier.classifyForScaling('sriracha sauce', IngredientCategory.condiment),
        ScalingCategory.heat,
      );
    });

    test('apple cider vinegar → acid (keyword)', () {
      expect(
        ScalingClassifier.classifyForScaling('apple cider vinegar', IngredientCategory.vinegar),
        ScalingCategory.acid,
      );
    });

    test('lemon juice → acid (keyword)', () {
      expect(
        ScalingClassifier.classifyForScaling('lemon juice', IngredientCategory.juice),
        ScalingCategory.acid,
      );
    });

    test('baking powder → leavening (keyword)', () {
      expect(
        ScalingClassifier.classifyForScaling('baking powder', IngredientCategory.leavening),
        ScalingCategory.leavening,
      );
    });

    test('baking soda → leavening (keyword)', () {
      expect(
        ScalingClassifier.classifyForScaling('baking soda', null),
        ScalingCategory.leavening,
      );
    });

    test('garlic → aromatic (keyword wins over produce)', () {
      expect(
        ScalingClassifier.classifyForScaling('garlic cloves, minced', IngredientCategory.produce),
        ScalingCategory.aromatic,
      );
    });

    test('shallot → aromatic', () {
      expect(
        ScalingClassifier.classifyForScaling('shallot', IngredientCategory.produce),
        ScalingCategory.aromatic,
      );
    });
  });

  group('ScalingClassifier.classifyForScaling — category fallback', () {
    test('spice category (non-keyword) → ScalingCategory.spice', () {
      expect(
        ScalingClassifier.classifyForScaling('cinnamon', IngredientCategory.spice),
        ScalingCategory.spice,
      );
    });

    test('vinegar category (non-keyword) → ScalingCategory.acid', () {
      expect(
        ScalingClassifier.classifyForScaling('sherry vinegar', IngredientCategory.vinegar),
        ScalingCategory.acid,
      );
    });

    test('condiment category (non-keyword) → ScalingCategory.spice (conservative)', () {
      expect(
        ScalingClassifier.classifyForScaling('dijon mustard', IngredientCategory.condiment),
        ScalingCategory.spice,
      );
    });

    test('produce category (non-aromatic) → ScalingCategory.linear', () {
      expect(
        ScalingClassifier.classifyForScaling('carrot', IngredientCategory.produce),
        ScalingCategory.linear,
      );
    });

    test('null category, no keyword → ScalingCategory.linear', () {
      expect(
        ScalingClassifier.classifyForScaling('chicken breast', null),
        ScalingCategory.linear,
      );
    });

    test('dairy category → ScalingCategory.linear', () {
      expect(
        ScalingClassifier.classifyForScaling('heavy cream', IngredientCategory.dairy),
        ScalingCategory.linear,
      );
    });
  });

  // ── Catering-scale sanity checks (factor = 50, serves 4 → 200) ───────────
  //
  // Pre-calculated values:
  //
  // 1. "2 tsp" salt (salt/0.75):
  //    50^0.75 = e^(0.75×ln50) = e^(0.75×3.912) = e^2.934 = 18.827
  //    2 × 18.827 = 37.654 tsp
  //    spoon grid: whole=37, frac=0.654 → ¾(d=0.096) beats ½(d=0.154) → 37¾ tsp
  //    37.75/3 = 12.583 → not clean → stays "37¾ tsp"
  //
  // 2. "1 tsp" chili flakes (heat/0.62):
  //    50^0.62 = e^(0.62×3.912) = e^2.425 = 11.301
  //    1 × 11.301 = 11.301 tsp
  //    spoon grid: whole=11, frac=0.301 → ¼(d=0.051) beats ½(d=0.199) → 11¼ tsp
  //    11.25/3 = 3.75 → not integer → no escalation → stays "11¼ tsp"
  //    → "11¼ tsp"
  //
  // 3. "1 tsp" cumin (spice/0.68):
  //    50^0.68 = e^(0.68×3.912) = e^2.660 = 14.297
  //    1 × 14.297 = 14.297 tsp
  //    spoon grid: whole=14, frac=0.297 → ¼(d=0.047) beats ½(d=0.203) → 14¼ tsp
  //    14.25/3 = 4.75 → not integer → no escalation → stays "14¼ tsp"
  //    → "14¼ tsp"
  //
  // 4. "2 cloves" garlic (aromatic/0.82):
  //    50^0.82 = e^(0.82×3.912) = e^3.208 = 24.741
  //    2 × 24.741 = 49.482 → countable → round = 49
  //    → "49 cloves"
  //
  // 5. "1 tsp" baking powder (leavening/0.80):
  //    50^0.80 = e^(0.80×3.912) = e^3.130 = 22.909
  //    1 × 22.909 = 22.909 tsp
  //    spoon grid: whole=22, frac=0.909 → 1−1/48=0.979; 0.909<0.979 so not near-unity
  //    ¾(d=0.159) beats ½(d=0.409) → 22¾ tsp
  //    22.75/3 = 7.583 → not clean → stays "22¾ tsp"
  //
  // 6. "2 cups" flour (linear/1.0):
  //    2 × 50 = 100 C
  //    Ladder stops at cup (no pt/qt/gal) → stays "100 C"
  //    → "100 C"

  group('AmountScaler.scale — catering-scale sanity checks (×50)', () {
    test('"2 tsp" salt ×50 (salt/0.75) → "37¾ tsp"', () {
      expect(
        AmountScaler.scale('2', 50.0, unit: 'tsp', scalingCategory: ScalingCategory.salt),
        '37¾ tsp',
      );
    });

    test('"1 tsp" chili flakes ×50 (heat/0.62) → "11¼ tsp" (escalation requires integer)', () {
      // 11.25 tsp: 11.25 ÷ 3 = 3.75 → not integer → no escalation
      expect(
        AmountScaler.scale('1', 50.0, unit: 'tsp', scalingCategory: ScalingCategory.heat),
        '11¼ tsp',
      );
    });

    test('"1 tsp" cumin ×50 (spice/0.68) → "14¼ tsp" (escalation requires integer)', () {
      // 14.25 tsp: 14.25 ÷ 3 = 4.75 → not integer → no escalation
      expect(
        AmountScaler.scale('1', 50.0, unit: 'tsp', scalingCategory: ScalingCategory.spice),
        '14¼ tsp',
      );
    });

    test('"2 cloves" garlic ×50 (aromatic/0.82) → "49 cloves"', () {
      expect(
        AmountScaler.scale('2', 50.0, unit: 'cloves', scalingCategory: ScalingCategory.aromatic),
        '49 cloves',
      );
    });

    test('"1 tsp" baking powder ×50 (leavening/0.80) → "22¾ tsp"', () {
      expect(
        AmountScaler.scale('1', 50.0, unit: 'tsp', scalingCategory: ScalingCategory.leavening),
        '22¾ tsp',
      );
    });

    test('"2 cups" flour ×50 (linear) → "100 C" (ladder stops at cup)', () {
      // 100 C: pt/qt/gal not in ladder → stays cups
      expect(
        AmountScaler.scale('2', 50.0, unit: 'C', scalingCategory: ScalingCategory.linear),
        '100 C',
      );
    });
  });
}
