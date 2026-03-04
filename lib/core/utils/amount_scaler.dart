/// Pure render-time scaling for ingredient amount strings.
///
/// [AmountScaler.scale] is the sole entry point for all scaling logic.
/// It transforms a stored amount string by a numeric factor and returns
/// a new display string — the original stored value is never touched.
///
/// **Architecture note:**
/// Scaling is applied only in the widget layer, at display time.
/// No database fields are written. No model classes are modified.
library;

import 'dart:math' as math;

import 'amount_utils.dart';
import 'ingredient_categorizer.dart';

// ── Scaling-specific category enum ─────────────────────────────────────────

/// Culinary scaling category — finer-grained than [IngredientCategory] for
/// the purpose of power-law dampening.
///
/// This enum is **internal to the scaling layer only**. It does not replace
/// or modify [IngredientCategory] or [IngredientService].
enum ScalingCategory {
  salt,      // exponent 0.75 — very sub-linear at catering scale
  spice,     // exponent 0.68
  heat,      // exponent 0.62 — chili / hot sauce / capsicum compounds
  acid,      // exponent 0.72 — vinegar, citrus juice
  aromatic,  // exponent 0.82 — garlic, onion, shallot, ginger
  leavening, // exponent 0.80
  linear,    // exponent 1.0 — default for all other categories
}

// ── Scaling classifier ──────────────────────────────────────────────────────

/// Maps an ingredient name + [IngredientCategory] to a [ScalingCategory].
///
/// Keyword matching takes full priority over category fallback so that
/// cross-category ingredients (e.g. soy sauce classified as `condiment` but
/// behaves like `salt`) receive the correct dampening.
///
/// To extend the keyword lists, add entries to the relevant list below.
/// Order within each method has no effect — all lists are checked exhaustively.
class ScalingClassifier {
  // ── Salt keywords ─────────────────────────────────────────────────────
  static const List<String> _saltKeywords = [
    'salt', 'miso', 'soy sauce', 'fish sauce', 'worcestershire',
    'tamari', 'anchovies', 'anchovy', 'capers', 'caper',
    'msg',
  ];

  // ── Heat keywords ─────────────────────────────────────────────────────
  static const List<String> _heatKeywords = [
    'chili', 'chile', 'cayenne', 'pepper flakes', 'red pepper flake',
    'sriracha', 'tabasco', 'harissa', 'jalapeño', 'jalapeno',
    'habanero', 'serrano', 'scotch bonnet', 'ghost pepper',
    'gochugaru', 'gochujang', 'sambal', 'chipotle', 'ancho',
    'thai chili', 'bird eye', "bird's eye",
  ];

  // ── Acid keywords ─────────────────────────────────────────────────────
  static const List<String> _acidKeywords = [
    'vinegar', 'lemon juice', 'lime juice', 'citrus juice',
    'tamarind', 'verjuice',
  ];

  // ── Leavening keywords ────────────────────────────────────────────────
  static const List<String> _leaveningKeywords = [
    'baking powder', 'baking soda', 'yeast', 'cream of tartar',
    'bicarbonate', 'sodium bicarbonate',
  ];

  // ── Aromatic keywords ─────────────────────────────────────────────────
  static const List<String> _aromaticKeywords = [
    'garlic', 'onion', 'shallot', 'ginger', 'leek', 'scallion',
    'green onion', 'spring onion', 'chive',
  ];

  /// Classify [ingredientName] for scaling purposes.
  ///
  /// Keyword matching (case-insensitive substring) takes priority over
  /// [category] fallback. First match wins across all keyword lists.
  static ScalingCategory classifyForScaling(
    String ingredientName,
    IngredientCategory? category,
  ) {
    final lower = ingredientName.toLowerCase();

    // ── Keyword pass first ──────────────────────────────────────────────
    if (_matchesAny(lower, _saltKeywords))     return ScalingCategory.salt;
    if (_matchesAny(lower, _heatKeywords))     return ScalingCategory.heat;
    if (_matchesAny(lower, _acidKeywords))     return ScalingCategory.acid;
    if (_matchesAny(lower, _leaveningKeywords)) return ScalingCategory.leavening;
    if (_matchesAny(lower, _aromaticKeywords)) return ScalingCategory.aromatic;

    // ── Category fallback ───────────────────────────────────────────────
    switch (category) {
      case IngredientCategory.spice:
        return ScalingCategory.spice;
      case IngredientCategory.vinegar:
        return ScalingCategory.acid;
      case IngredientCategory.condiment:
        // Conservative — condiments vary; default to spice-level dampening.
        return ScalingCategory.spice;
      default:
        return ScalingCategory.linear;
    }
  }

  static bool _matchesAny(String lower, List<String> keywords) {
    for (final kw in keywords) {
      if (lower.contains(kw)) return true;
    }
    return false;
  }
}

/// Stateless utility that scales an ingredient amount string by a factor.
///
/// The caller is responsible for:
///   - Computing `factor = targetServes / baselineServes`.
///   - Never passing the `bakerPercent` field here — that field is a ratio
///     and is invariant under linear scaling.
///   - Passing the raw stored `Ingredient.amount` value, not a pre-formatted string.
class AmountScaler {
  // ── Configuration ───────────────────────────────────────────────────────

  /// Qualifier prefixes that may precede a numeric amount.
  ///
  /// These are detected and preserved verbatim around the scaled number.
  static const List<String> _qualifierPrefixes = ['about', 'approx', 'around'];

  // ── Power-law dampening exponents ────────────────────────────────────────
  //
  // scaledAmount = originalAmount × factor^exponent
  //
  // Exponent < 1.0 produces dampening (flavour-sensitive categories scale
  // sub-linearly so recipes don't become inedibly salty/spicy when doubled).
  //
  // [ScalingCategory.linear] receives exponent 1.0 and has no entry.
  // This map is the **single source of truth** — no exponent values elsewhere.

  /// Dampening exponents keyed by [ScalingCategory].
  ///
  /// Values are calibrated for catering-scale factors (4 → 200 servings)
  /// as well as home-cooking scale (1 → 4 servings).
  static const Map<ScalingCategory, double> scalingExponents = {
    ScalingCategory.salt:      0.75,
    ScalingCategory.spice:     0.68,
    ScalingCategory.heat:      0.62,
    ScalingCategory.acid:      0.72,
    ScalingCategory.aromatic:  0.82,
    ScalingCategory.leavening: 0.80,
    // ScalingCategory.linear → 1.0, no entry needed
  };

  // ── Unit escalation ladder ────────────────────────────────────────────────
  //
  // Each entry is [fromUnit, toUnit, divisor] meaning:
  //   if scaled value (in fromUnit) is exactly divisible by divisor,
  //   the result is expressed as (value / divisor) toUnit.
  //
  // Only one level is checked at a time; the loop re-checks after each step.
  // Units use the normalized abbreviations from UnitNormalizer.
  // Imperial and metric ladders are fully separate — no cross-system escalation.

  static const List<_UnitStep> _escalationLadder = [
    // Imperial volume
    _UnitStep(from: 'tsp',  to: 'Tbsp', divisor: 3),   // 3 tsp  → 1 Tbsp
    _UnitStep(from: 'Tbsp', to: 'C',    divisor: 16),   // 16 Tbsp → 1 C  (via 4 Tbsp = ¼ C)
    _UnitStep(from: 'C',    to: 'pt',   divisor: 2),    // 2 C    → 1 pt
    _UnitStep(from: 'pt',   to: 'qt',   divisor: 2),    // 2 pt   → 1 qt
    _UnitStep(from: 'qt',   to: 'gal',  divisor: 4),    // 4 qt   → 1 gal
    // Imperial weight
    _UnitStep(from: 'oz',   to: 'lb',   divisor: 16),   // 16 oz → 1 lb
    // Metric weight
    _UnitStep(from: 'mg',   to: 'g',    divisor: 1000), // 1000 mg → 1 g
    _UnitStep(from: 'g',    to: 'kg',   divisor: 1000), // 1000 g  → 1 kg
    // Metric volume
    _UnitStep(from: 'ml',   to: 'L',    divisor: 1000), // 1000 ml → 1 L
  ];

  // ── Snap-to-grid configuration ────────────────────────────────────────────
  //
  // Two grids are used:
  //   • Full grid — for cups and all units where thirds are meaningful.
  //   • Restricted grid — for tsp/Tbsp where ⅓ and ⅔ are not standard
  //     measuring spoon sizes. Nearest practical spoon value is used.
  //
  // Both grids are ordered by denominator complexity so that simpler fractions
  // win ties (½ preferred over ⅖ if equidistant).
  //
  // For countable ingredients (no unit / unit is a piece descriptor), only
  // whole numbers and ½ are allowed (e.g. "½ onion" is valid; "⅓ onion" is not).

  /// Fractions allowed for all measuring units (cups, etc.) — includes thirds.
  static const List<double> _fullGrid = [
    0.125, 0.25, 1/3, 0.5, 2/3, 0.75,
  ];

  /// Fractions allowed for tsp / Tbsp — no thirds (no ⅓-tsp measuring spoon).
  static const List<double> _spoonGrid = [
    0.125, 0.25, 0.5, 0.75,
  ];

  /// Units that use [_spoonGrid] (no-thirds) instead of [_fullGrid].
  static const Set<String> _spoonUnits = {'tsp', 'Tbsp'};

  /// Unit tokens that indicate a countable ingredient (piece / whole-item).
  ///
  /// When ingredient.unit is one of these (or null/empty), only whole numbers
  /// and ½ are allowed — no other fractions.
  static const Set<String> _countableUnits = {
    '', 'pc', 'pcs', 'piece', 'pieces', 'whole', 'slice', 'slices',
    'clove', 'cloves', 'sprig', 'sprigs', 'stalk', 'stalks',
    'head', 'heads', 'bunch', 'bunches',
  };

  // ── Public API ──────────────────────────────────────────────────────────

  /// Scale [rawAmount] by [factor] and return a human-readable string.
  ///
  /// [rawAmount] is the unmodified `Ingredient.amount` as stored in Isar.
  ///
  /// [unit] is the ingredient's unit (e.g. `"tsp"`, `"C"`, `null`).
  /// Used to determine the appropriate snap grid and whether escalation
  /// can improve the result.
  ///
  /// [category] is the ingredient's [IngredientCategory] (from
  /// `IngredientService().classify(ingredient.name)`). When present and
  /// listed in [scalingExponents], power-law dampening is applied before
  /// snap-to-grid. When null or absent from the map, linear scaling is used.
  ///
  /// **Pass-through cases (returned unchanged):**
  ///   - `null` or empty
  ///   - Clearly non-numeric freeform text (`"to taste"`, `"for frying"`)
  ///   - Annotated amounts whose leading portion does not parse
  ///
  /// **Pipeline for numeric amounts:**
  ///   1. Power-law dampening (if scalingCategory is in [scalingExponents])
  ///   2. Snap to nearest cookware grid value (floor 1/8 of one unit)
  ///   3. Clean unit escalation (e.g. 3 tsp → 1 Tbsp)
  ///   4. Format with unicode fraction glyphs
  static String? scale(
    String? rawAmount,
    double factor, {
    String? unit,
    ScalingCategory? scalingCategory,
  }) {
    if (rawAmount == null) return null;
    final trimmed = rawAmount.trim();
    if (trimmed.isEmpty) return rawAmount;
    // ── Short-circuit: an unscaled recipe must never be transformed ──────────
    // At factor 1.0 the stored string is returned exactly as-is — no
    // formatting, no snap-to-grid, no unit escalation.  This is the primary
    // guard against the regression where the pipeline ran on every render and
    // corrupted amounts (e.g. "3 tsp" → "1 Tbsp" on an unscaled recipe).
    if (factor == 1.0) return rawAmount;
    if (factor <= 0) return AmountUtils.formatRaw(trimmed);

    // Resolve the effective exponent for this scaling category.
    final exponent =
        (scalingCategory != null ? scalingExponents[scalingCategory] : null) ?? 1.0;

    // ── Step 1: detect and strip qualifier prefix ─────────────────────────
    //    e.g. "about 3" → qualifier = "about ", working = "3"
    String? qualifier;
    String working = trimmed;
    final lowerWorking = working.toLowerCase();
    for (final q in _qualifierPrefixes) {
      if (lowerWorking.startsWith('$q ')) {
        // Preserve original capitalisation of the qualifier word.
        qualifier = '${working.substring(0, q.length)} ';
        working = working.substring(q.length).trim();
        break;
      }
    }

    // ── Step 2: annotated amount "N (descriptor) suffix" ─────────────────
    //    Only the leading numeric portion is scaled; the parenthetical is
    //    preserved verbatim. Example: "1 (14 oz) can" × 3 → "3 (14 oz) can".
    if (working.contains('(')) {
      final parenIndex = working.indexOf('(');
      final numPart = working.substring(0, parenIndex).trim();
      final rest = working.substring(parenIndex); // includes '('

      if (numPart.isNotEmpty && _isLikelyNumeric(numPart)) {
        final parsed = AmountUtils.parse(numPart);
        if (parsed > 0) {
          final scaledValue = _applyDampening(parsed, factor, exponent);
          final effectiveUnit = unit?.trim() ?? '';
          final snapped = _snapToGrid(scaledValue, effectiveUnit);
          final formatted = _formatAndEscalate(snapped, effectiveUnit);
          final result = '$formatted $rest'.trim();
          return qualifier != null ? '$qualifier$result' : result;
        }
      }
      // Leading portion is not numeric → freeform passthrough.
      return rawAmount;
    }

    // ── Step 3: range "2-3" or "2–3" ─────────────────────────────────────
    //    Only treated as a range when BOTH sides parse as positive numbers,
    //    preventing false splits on strings like "all-purpose".
    if (_isRange(working)) {
      return _scaleRange(working, factor, qualifier, exponent, unit);
    }

    // ── Step 4: freeform non-numeric ("to taste", "for frying") ──────────
    if (!_isLikelyNumeric(working)) return rawAmount;

    // ── Step 5: plain numeric value ───────────────────────────────────────
    final parsed = AmountUtils.parse(working);
    if (parsed == 0.0) return rawAmount;

    final effectiveUnit = unit?.trim() ?? '';
    final scaledValue = _applyDampening(parsed, factor, exponent);
    final snapped = _snapToGrid(scaledValue, effectiveUnit);
    final formatted = _formatAndEscalate(snapped, effectiveUnit);
    return qualifier != null ? '$qualifier$formatted' : formatted;
  }

  // ── Private: math helpers ────────────────────────────────────────────────

  /// Apply power-law dampening: `value × factor^exponent`.
  static double _applyDampening(double value, double factor, double exponent) {
    if (exponent == 1.0) return value * factor;
    return value * math.pow(factor, exponent).toDouble();
  }

  /// Snap [value] to the nearest culinary grid value for the given [unit].
  ///
  /// - Countable units (no unit / piece descriptors): whole numbers + ½ only.
  /// - tsp / Tbsp: {⅛, ¼, ½, ¾} as fractional part (no thirds).
  /// - All other measured units: full grid including ⅓ and ⅔.
  ///
  /// Floor: minimum output is 1/8 (one unit of _spoonGrid minimum).
  /// For amounts ≥ 1 with a measured unit, fractional parts snap independently.
  static double _snapToGrid(double value, String unit) {
    if (value <= 0) return 0.125; // floor
    final normUnit = unit.trim();

    // Countable: round to nearest whole, with ½ allowed.
    if (_countableUnits.contains(normUnit.toLowerCase())) {
      if (value < 0.75) return 0.5;  // below ¾ → ½
      return value.roundToDouble();   // nearest whole
    }

    // Choose fraction grid for this unit.
    final List<double> fracGrid = _spoonUnits.contains(normUnit)
        ? _spoonGrid
        : _fullGrid;

    final whole = value.floor();
    final frac = value - whole;

    // Snap near-integer frac upward.
    const unity = 1.0 - 1.0 / 48.0;
    if (frac >= unity) return (whole + 1).toDouble();

    // Pure whole number (frac ≈ 0) → return as-is, checking floor.
    if (frac < 1.0 / 48.0) {
      final w = whole == 0 ? 0.125 : whole.toDouble(); // floor applies
      return w;
    }

    // Find nearest fraction from grid.
    double bestFrac = fracGrid[0];
    double bestDist = (frac - fracGrid[0]).abs();
    for (int i = 1; i < fracGrid.length; i++) {
      final d = (frac - fracGrid[i]).abs();
      if (d < bestDist) {
        bestDist = d;
        bestFrac = fracGrid[i];
      }
    }

    // Also compare to rounding to the next whole.
    final distToNext = (frac - 1.0).abs();
    if (distToNext < bestDist) {
      return (whole + 1).toDouble();
    }

    double snapped = whole + bestFrac;

    // Apply minimum floor of ⅛.
    if (snapped < 0.125) snapped = 0.125;
    return snapped;
  }

  // ── Private: format + escalation ─────────────────────────────────────────

  /// Format a snapped double value with unit escalation.
  ///
  /// Escalation is applied only when the conversion is clean (exact integer
  /// result after division), one level at a time.
  ///
  /// Returns a formatted string **without** the unit — the caller appends it
  /// unless escalation changed the unit, in which case the new unit is embedded.
  static String _formatAndEscalate(double snappedValue, String unit) {
    double value = snappedValue;
    String currentUnit = unit.trim();

    // Escalate one step at a time while a clean conversion exists.
    bool escalated = true;
    while (escalated) {
      escalated = false;
      for (final step in _escalationLadder) {
        if (step.from != currentUnit) continue;
        // Check whether value / divisor is a clean integer or a "nice" fraction.
        final ratio = value / step.divisor;
        if (_isCleanRatio(ratio)) {
          value = ratio;
          currentUnit = step.to;
          escalated = true;
          break; // re-check from top of ladder with new unit
        }
      }
    }

    final formatted = AmountUtils.format(value);
    if (currentUnit.isEmpty) return formatted;
    return '$formatted $currentUnit';
  }

  /// Returns true when [ratio] is an integer or a "nice" fraction
  /// (one that exists in [AmountUtils.unicodeFractionValues]).
  static bool _isCleanRatio(double ratio) {
    if (ratio <= 0) return false;
    final whole = ratio.floor();
    final frac = ratio - whole;
    // Integer case.
    if (frac < 1.0 / 48.0) return true;
    // Snap-to-unity case.
    if (frac > 1.0 - 1.0 / 48.0) return true;
    // Must be an exact nice fraction.
    for (final v in AmountUtils.unicodeFractionValues.values) {
      if ((frac - v).abs() < 1.0 / 48.0) return true;
    }
    return false;
  }

  // ── Private: string helpers ───────────────────────────────────────────────

  /// Returns `true` if [s] begins with a digit or unicode fraction glyph.
  ///
  /// Also returns `true` if [s] begins with a recognized qualifier prefix
  /// followed by a numeric character (handled recursively).
  static bool _isLikelyNumeric(String s) {
    if (s.isEmpty) return false;
    if (RegExp(
      r'^[\d' + AmountUtils.unicodeFractionGlyphs + r']',
    ).hasMatch(s)) {
      return true;
    }
    // Check for qualifier prefix whose remainder is numeric.
    final lower = s.toLowerCase();
    for (final q in _qualifierPrefixes) {
      if (lower.startsWith('$q ')) {
        return _isLikelyNumeric(s.substring(q.length).trim());
      }
    }
    return false;
  }

  /// Returns `true` only when [s] is a two-part range where both halves
  /// parse as positive numbers.
  ///
  /// "2-3"           → true   (both sides numeric)
  /// "all-purpose"   → false  ("all" is not numeric)
  /// "-1"            → false  (first part empty)
  /// "1½-2"          → true   (glyph side is numeric)
  static bool _isRange(String s) {
    final parts = s.split(RegExp(r'[-–]'));
    if (parts.length != 2) return false;
    final a = parts[0].trim();
    final b = parts[1].trim();
    if (a.isEmpty || b.isEmpty) return false;
    return _isLikelyNumeric(a) &&
        _isLikelyNumeric(b) &&
        AmountUtils.parse(a) > 0 &&
        AmountUtils.parse(b) > 0;
  }

  /// Scale both ends of a range string independently and rejoin with a hyphen.
  static String? _scaleRange(
    String s,
    double factor,
    String? qualifier,
    double exponent,
    String? unit,
  ) {
    final parts = s.split(RegExp(r'[-–]'));
    final effectiveUnit = unit?.trim() ?? '';

    final loRaw = AmountUtils.parse(parts[0].trim());
    final hiRaw = AmountUtils.parse(parts[1].trim());

    final loScaled = _snapToGrid(_applyDampening(loRaw, factor, exponent), effectiveUnit);
    final hiScaled = _snapToGrid(_applyDampening(hiRaw, factor, exponent), effectiveUnit);

    final lo = AmountUtils.format(loScaled);
    final hi = AmountUtils.format(hiScaled);
    final result = '$lo-$hi';
    return qualifier != null ? '$qualifier$result' : result;
  }
}

/// Immutable descriptor for one rung of the unit escalation ladder.
class _UnitStep {
  final String from;
  final String to;
  final int divisor;
  const _UnitStep({required this.from, required this.to, required this.divisor});
}
