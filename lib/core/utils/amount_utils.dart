/// Shared utilities for parsing, formatting, and snapping ingredient amount
/// strings.
///
/// This is the **single source of truth** for all amount string manipulation.
/// It replaces the private `_formatAmount()` helpers that were previously
/// duplicated across:
///   - `ingredient_list.dart`
///   - `split_recipe_view.dart`
///   - `smoking_detail_screen.dart`
///
/// And replaces the `_parseQuantity()` logic in `ShoppingListController`.
///
/// None of the functions in this file write to the database.
/// All transformations are pure and side-effect-free.
library;

import 'text_normalizer.dart';
import 'unit_normalizer.dart';

class AmountUtils {
  // ── Fraction reference data ─────────────────────────────────────────────

  /// Unicode fraction glyphs mapped to their IEEE 754 double equivalents.
  ///
  /// Ordered from simplest denominator (2) to most complex (6) so that
  /// [format] prefers simpler fractions during snapping.
  static const Map<String, double> unicodeFractionValues = {
    '½': 0.5,
    '¼': 0.25,
    '¾': 0.75,
    '⅓': 1.0 / 3.0,
    '⅔': 2.0 / 3.0,
    '⅛': 0.125,
    '⅜': 0.375,
    '⅝': 0.625,
    '⅞': 0.875,
    '⅕': 0.2,
    '⅖': 0.4,
    '⅗': 0.6,
    '⅘': 0.8,
    '⅙': 1.0 / 6.0,
    '⅚': 5.0 / 6.0,
  };

  /// The set of all unicode fraction glyph characters, as a string.
  ///
  /// Used to build character-class regexes without repeating the list.
  static const String unicodeFractionGlyphs = '½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗⅘⅙⅚';

  /// When a scaled fractional part is within this tolerance of a "nice"
  /// fraction, snap to that glyph rather than displaying as a decimal.
  ///
  /// Value: 1/48 ≈ 0.02083.
  /// Rationale: the minimum gap between any two adjacent fractions in
  /// [unicodeFractionValues] is ⅛ vs ⅙ = 1/24 ≈ 0.04167.
  /// Using 1/48 (half the minimum gap) guarantees no two fractions can
  /// both be within tolerance of the same value.
  static const double _snapTolerance = 1.0 / 48.0;

  // ── Decimal suffix → glyph map (used in formatRaw) ─────────────────────

  /// Maps decimal-suffix strings to unicode fraction glyphs.
  ///
  /// Used by [formatRaw] to convert stored amounts like "1.5" → "1½".
  ///
  /// Note: longer keys must come before shorter ambiguous prefixes.
  /// ".333" before ".33" ensures "1.333" is converted to "1⅓" not "1⅓3".
  static const Map<String, String> _decimalSuffixToGlyph = {
    '.5':   '½',
    '.25':  '¼',
    '.75':  '¾',
    '.333': '⅓',
    '.33':  '⅓',
    '.667': '⅔',
    '.67':  '⅔',
    '.125': '⅛',
    '.375': '⅜',
    '.625': '⅝',
    '.875': '⅞',
  };

  // ── Public API ──────────────────────────────────────────────────────────

  /// Format a raw stored amount string for display — no scaling.
  ///
  /// This is a drop-in replacement for the private `_formatAmount()` helpers
  /// that were previously duplicated across the widget layer.
  ///
  /// Performs:
  ///   1. Strips trailing `.0` from whole-number decimals ("2.0" → "2").
  ///   2. Converts mixed decimals to unicode glyphs ("1.5" → "1½").
  ///   3. Converts text fractions to unicode glyphs ("1/2" → "½").
  ///
  /// Non-numeric strings ("to taste", "for frying") pass through unchanged.
  static String formatRaw(String amount) {
    var result = amount.trim();
    if (result.isEmpty) return result;

    // 1. Strip trailing ".0" from whole-number decimals (e.g. "2.0" → "2").
    //    The lookahead ensures we don't strip mid-string (e.g. "2.05").
    result = result.replaceAllMapped(
      RegExp(r'(\d+)\.0(?=\s|$|-|–)'),
      (m) => m.group(1)!,
    );
    if (result.endsWith('.0')) {
      result = result.substring(0, result.length - 2);
    }

    // 2. Convert "N.decimal" patterns to "N" + unicode glyph
    //    e.g. "1.5" → "1½", "2.25" → "2¼".
    //    Also handles standalone decimals: ".5" → "½".
    for (final entry in _decimalSuffixToGlyph.entries) {
      // Mixed number: "1.5 cup" → "1½ cup".
      result = result.replaceAllMapped(
        RegExp(r'(\d+)' + RegExp.escape(entry.key) + r'(?=\s|$|-|–)'),
        (m) => '${m.group(1)}${entry.value}',
      );
      // Standalone decimal: ".5" or ".5 cup".
      if (result == entry.key || result.startsWith('${entry.key} ')) {
        result = result.replaceFirst(entry.key, entry.value);
      }
    }

    // 3. Convert remaining text fractions ("1/2" → "½") and any surviving
    //    standalone decimals ("0.5" → "½") via the shared TextNormalizer.
    result = TextNormalizer.normalizeFractions(result);

    return result;
  }

  /// Parse a **single** amount string into a [double].
  ///
  /// Handles: integers, decimals, unicode fraction glyphs, mixed numbers
  /// ("1½", "1 ½", "1 1/2"), and text fractions ("1/2").
  ///
  /// **Does NOT handle ranges.** Calling `parse("2-3")` returns `0.0`.
  /// Use [parseMax] when the input may contain a range.
  ///
  /// Returns `0.0` if the string contains no parseable numeric content.
  static double parse(String? amount) {
    if (amount == null || amount.trim().isEmpty) return 0.0;
    return _parseNormalized(
      TextNormalizer.normalizeFractions(amount.trim()),
    );
  }

  /// Parse an amount, resolving ranges to their **maximum** value.
  ///
  /// "2-3" → `3.0` (used by shopping list for conservative purchase totals).
  /// All other formats are handled identically to [parse].
  static double parseMax(String? amount) {
    if (amount == null || amount.trim().isEmpty) return 0.0;
    final cleaned = TextNormalizer.normalizeFractions(amount.trim());
    if (cleaned.contains('-') || cleaned.contains('–')) {
      final parts = cleaned.split(RegExp(r'[-–]'));
      if (parts.length > 1) {
        // Take the last (maximum) value from the range.
        return _parseNormalized(parts.last.trim());
      }
    }
    return _parseNormalized(cleaned);
  }

  /// Format a [double] value as a human-readable amount string.
  ///
  /// Snaps the fractional part to the nearest unicode glyph when it is
  /// within [_snapTolerance] of an entry in [unicodeFractionValues].
  ///
  /// Examples:
  ///   - `format(3.0)`         → `"3"`
  ///   - `format(1.5)`         → `"1½"`
  ///   - `format(0.5)`         → `"½"`
  ///   - `format(1.0 / 3.0)`  → `"⅓"`
  ///   - `format(4.5)`         → `"4½"`
  ///
  /// For values that do not snap to a nice fraction, formats with at most
  /// 2 decimal places, stripping trailing zeros.
  static String format(double value) {
    if (value <= 0) return '0';

    final whole = value.floor();
    final frac = value - whole.toDouble();

    // Snap near-zero fractional parts to zero.
    if (frac < _snapTolerance) {
      return whole == 0 ? '0' : whole.toString();
    }

    // Snap near-unity fractional parts upward (handles float precision
    // artefacts like 0.9999... produced by ⅓ × 3 or ⅔ × 1.5).
    if (frac > 1.0 - _snapTolerance) {
      return (whole + 1).toString();
    }

    // Try to snap fractional part to a nice glyph.
    for (final entry in unicodeFractionValues.entries) {
      if ((frac - entry.value).abs() < _snapTolerance) {
        return whole > 0 ? '$whole${entry.key}' : entry.key;
      }
    }

    // No snap candidate: fall back to at-most-2-decimal representation.
    return _formatFallback(value);
  }

  /// Extract a numeric serving count from a [servesText] string.
  ///
  /// Builds on [UnitNormalizer.normalizeServes] to strip trailing words like
  /// "people" and leading words like "Serves".
  ///
  /// For range strings (e.g. "4-6"), returns the arithmetic midpoint (5.0)
  /// so a UI stepper has a sensible starting point without special-casing
  /// whether the user's chosen target is inside or outside the range.
  ///
  /// Returns `1.0` when [servesText] is null, empty, or unparseable.
  static double extractBaselineServes(String? servesText) {
    if (servesText == null || servesText.trim().isEmpty) return 1.0;

    // normalizeServes strips non-numeric words and normalises whitespace
    // around range dashes, e.g. "Serves 4 people" → "4", "4-6" → "4-6".
    final normalized = UnitNormalizer.normalizeServes(servesText);
    if (normalized.isEmpty) return 1.0;

    // Range: return midpoint.
    final rangeMatch =
        RegExp(r'^(\d+)\s*[-–]\s*(\d+)$').firstMatch(normalized);
    if (rangeMatch != null) {
      final lo = double.tryParse(rangeMatch.group(1)!) ?? 1.0;
      final hi = double.tryParse(rangeMatch.group(2)!) ?? 1.0;
      return (lo + hi) / 2.0;
    }

    return double.tryParse(normalized) ?? 1.0;
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  /// Core parser on an already fraction-normalised string (e.g. after
  /// [TextNormalizer.normalizeFractions] has been applied).
  ///
  /// Sums all digit sequences and unicode fraction glyphs it finds, which
  /// handles mixed numbers like "1½" (1.0 + 0.5 = 1.5) and "1 ½" (same).
  ///
  /// Returns `0.0` without summing if the string appears to be a range
  /// (digit or glyph — dash — digit or glyph). Callers that need range
  /// handling should use [parseMax] instead.
  static double _parseNormalized(String normalized) {
    // Range guard: do not sum tokens across a range separator.
    // The check looks for [digit or glyph] [-–] [digit or glyph].
    if (RegExp(
      r'[\d' + unicodeFractionGlyphs + r']\s*[-–]\s*[\d' + unicodeFractionGlyphs + r']',
    ).hasMatch(normalized)) {
      return 0.0;
    }

    double total = 0.0;
    final rx = RegExp(
      r'(\d+(?:\.\d+)?)|([' + unicodeFractionGlyphs + r'])',
    );
    for (final m in rx.allMatches(normalized)) {
      final numStr = m.group(1);
      final fracStr = m.group(2);
      if (numStr != null) total += double.tryParse(numStr) ?? 0.0;
      if (fracStr != null) total += unicodeFractionValues[fracStr] ?? 0.0;
    }
    return total;
  }

  /// Format a double as a decimal string with at most 2 decimal places,
  /// stripping trailing zeros and a trailing decimal point.
  static String _formatFallback(double value) {
    final s = value.toStringAsFixed(2);
    var result = s.replaceAll(RegExp(r'0+$'), '');
    if (result.endsWith('.')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
