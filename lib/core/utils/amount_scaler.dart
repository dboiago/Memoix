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

import 'amount_utils.dart';

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

  // ── Public API ──────────────────────────────────────────────────────────

  /// Scale [rawAmount] by [factor] and return a human-readable string.
  ///
  /// [rawAmount] should be the unmodified `Ingredient.amount` as stored in
  /// Isar (e.g. `"1½"`, `"2-3"`, `"about 3"`, `"to taste"`,
  /// `"1 (14 oz) can"`).
  ///
  /// **Pass-through cases (returned unchanged):**
  ///   - `null` or empty
  ///   - Clearly non-numeric freeform text (`"to taste"`, `"for frying"`)
  ///   - Annotated amounts whose leading portion does not parse
  ///
  /// **Handled cases:**
  ///   - Integers: `"2"` × 1.5 → `"3"`
  ///   - Decimals: `"1.5"` × 2 → `"3"`
  ///   - Unicode fractions: `"½"` × 2 → `"1"`
  ///   - Mixed numbers: `"1½"` × 2 → `"3"`
  ///   - Text fractions: `"1/2"` × 2 → `"1"`
  ///   - Ranges: `"2-3"` × 1.5 → `"3-4½"`
  ///   - Qualifier prefixes: `"about 3"` × 2 → `"about 6"`
  ///   - Parenthetical descriptors: `"1 (14 oz) can"` × 3 → `"3 (14 oz) can"`
  ///
  /// When [factor] is 1.0 (within floating-point precision), the string is
  /// returned normalized via [AmountUtils.formatRaw] without any arithmetic.
  static String? scale(String? rawAmount, double factor) {
    if (rawAmount == null) return null;
    final trimmed = rawAmount.trim();
    if (trimmed.isEmpty) return rawAmount;
    if (factor <= 0) return AmountUtils.formatRaw(trimmed);

    // Trivial case: factor ≈ 1.0 — normalize only, no calculation.
    if ((factor - 1.0).abs() < 1e-9) return AmountUtils.formatRaw(trimmed);

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
          final scaled = AmountUtils.format(parsed * factor);
          final result = '$scaled $rest'.trim();
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
      return _scaleRange(working, factor, qualifier);
    }

    // ── Step 4: freeform non-numeric ("to taste", "for frying") ──────────
    if (!_isLikelyNumeric(working)) return rawAmount;

    // ── Step 5: plain numeric value ───────────────────────────────────────
    final parsed = AmountUtils.parse(working);
    if (parsed == 0.0) return rawAmount;

    final scaled = AmountUtils.format(parsed * factor);
    return qualifier != null ? '$qualifier$scaled' : scaled;
  }

  // ── Private helpers ─────────────────────────────────────────────────────

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
  static String? _scaleRange(String s, double factor, String? qualifier) {
    final parts = s.split(RegExp(r'[-–]'));
    final lo = AmountUtils.format(AmountUtils.parse(parts[0].trim()) * factor);
    final hi = AmountUtils.format(AmountUtils.parse(parts[1].trim()) * factor);
    final result = '$lo-$hi';
    return qualifier != null ? '$qualifier$result' : result;
  }
}
