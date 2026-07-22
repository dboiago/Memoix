/// Pure, stateless helpers for normalizing a handful of schema.org JSON-LD
/// shapes that `url_importer.dart` doesn't yet recognize.
///
/// These are intentionally additive: every function returns `null` (or an
/// empty list) when its target shape isn't present, so callers can fall back
/// to their existing logic unchanged. None of these functions perform HTML
/// entity decoding — callers already own that responsibility (via
/// `_decodeHtml`/`_parseString` in `url_importer.dart`) and should continue
/// to apply it to whatever these helpers return, exactly as they do for
/// other extracted values.
class SchemaOrgParser {
  SchemaOrgParser._();

  /// Maximum recursion depth guard for malformed/circular HowTo schema trees.
  static const int maxHowToDepth = 10;

  // ── Task 1: WebPage.mainEntity unwrapping ────────────────────────────────

  /// If [data] is a schema.org `WebPage` node (or array-typed equivalent)
  /// whose `mainEntity` is an inline object, returns that object so callers
  /// can re-parse it as the actual recipe payload.
  ///
  /// Returns `null` when:
  ///  - [data] is not a `WebPage` node,
  ///  - `mainEntity` is missing,
  ///  - `mainEntity` is only an `@id` reference with no inline data (use
  ///    [resolveWebPageMainEntityId] when a sibling `@graph` array is
  ///    available to resolve it against).
  static Map<String, dynamic>? unwrapWebPageMainEntity(dynamic data) {
    if (data is! Map) return null;
    if (!_isType(data['@type'], 'WebPage')) return null;

    var mainEntity = data['mainEntity'];
    if (mainEntity is List && mainEntity.isNotEmpty) {
      mainEntity = mainEntity.first;
    }
    if (mainEntity is! Map) return null;

    // @id-only reference with no other keys: nothing inline to unwrap here.
    if (mainEntity.containsKey('@id') && mainEntity.length == 1) return null;

    return Map<String, dynamic>.from(mainEntity);
  }

  /// If [item] is a `WebPage` node whose `mainEntity` is a trivial `@id`-only
  /// reference, attempts to resolve it against sibling nodes in [graph] (the
  /// full `@graph` array). Returns the resolved sibling `Map`, or `null` if
  /// [item] isn't a matching `WebPage`, or no sibling with a matching `@id`
  /// exists — a graceful skip rather than a guess.
  static Map<String, dynamic>? resolveWebPageMainEntityId(
    dynamic item,
    List<dynamic> graph,
  ) {
    if (item is! Map) return null;
    if (!_isType(item['@type'], 'WebPage')) return null;

    var mainEntity = item['mainEntity'];
    if (mainEntity is List && mainEntity.isNotEmpty) {
      mainEntity = mainEntity.first;
    }
    if (mainEntity is! Map) return null;
    if (!(mainEntity.containsKey('@id') && mainEntity.length == 1)) {
      return null;
    }

    final refId = mainEntity['@id'];
    if (refId == null) return null;

    for (final sibling in graph) {
      if (sibling is Map && sibling['@id'] == refId) {
        return Map<String, dynamic>.from(sibling);
      }
    }
    return null;
  }

  // ── Task 2: HowToSection / HowToStep recursive flattening ────────────────

  /// Recursively flattens schema.org `HowToStep` / `HowToSection` trees (or
  /// plain strings/legacy `{text|name}` maps) into a flat list of
  /// instruction strings.
  ///
  /// Section headers are emitted using the `[Section Name]` bracket
  /// convention already used by `IngredientParser` (and by one existing
  /// direction-parsing fallback in `url_importer.dart`) to represent section
  /// headers inline within a flat string list, keeping ingredients and
  /// instructions visually/structurally consistent.
  ///
  /// Guards against malformed/circular schema via [depth] vs
  /// [maxHowToDepth].
  static List<String> flattenHowToInstructions(dynamic node, {int depth = 0}) {
    if (depth > maxHowToDepth) return const [];
    if (node == null) return const [];

    if (node is String) {
      final text = node.trim();
      return text.isEmpty ? const [] : [text];
    }

    if (node is List) {
      final result = <String>[];
      for (final item in node) {
        result.addAll(flattenHowToInstructions(item, depth: depth + 1));
      }
      return result;
    }

    if (node is Map) {
      final type = node['@type'];
      final isSection = _isType(type, 'HowToSection');
      final isStep = _isType(type, 'HowToStep');

      if (isSection) {
        final result = <String>[];
        final name = node['name'] ?? node['Name'];
        if (name is String && name.trim().isNotEmpty) {
          result.add('[${name.trim()}]');
        }
        result.addAll(
          flattenHowToInstructions(node['itemListElement'], depth: depth + 1),
        );
        return result;
      }

      if (isStep) {
        // Prefer `text`, fall back to `name`.
        final text = node['text'] ?? node['name'];
        if (text is String && text.trim().isNotEmpty) {
          return [text.trim()];
        }
        // Defensive: some feeds nest further steps under a HowToStep.
        if (node['itemListElement'] != null) {
          return flattenHowToInstructions(
            node['itemListElement'],
            depth: depth + 1,
          );
        }
        return const [];
      }

      // Untyped map: mirror the existing generic text/name fallback so
      // non-HowTo maps behave exactly as they did before this helper existed.
      final text = node['text'] ?? node['name'];
      if (text is String && text.trim().isNotEmpty) {
        return [text.trim()];
      }
      return const [];
    }

    final text = node.toString().trim();
    return text.isEmpty ? const [] : [text];
  }

  // ── Task 3: "dozen" yield conversion ──────────────────────────────────────

  /// Detects a "dozen" yield expression (e.g. `"2 dozen"`,
  /// `"1.5 dozen cookies"`) and returns the total integer count as a numeral
  /// string (e.g. `"24"`, `"18"`), or `null` if no dozen pattern is present.
  ///
  /// Intended to be checked before standard digit extraction so a bare
  /// leading-number match (e.g. just `"2"` from `"2 dozen"`) never wins over
  /// the more informative dozen conversion. The result is a strict integer
  /// count — no fractional dozens are returned.
  static String? parseDozenYield(String raw) {
    final match =
        RegExp(r'(\d+(?:\.\d+)?)\s*dozen', caseSensitive: false).firstMatch(raw);
    if (match == null) return null;

    final count = double.tryParse(match.group(1) ?? '');
    if (count == null) return null;

    final total = (count * 12).round();
    return total > 0 ? total.toString() : null;
  }

  // ── Task 4: duration range averaging ──────────────────────────────────────

  /// Detects a numeric duration range using a hyphen, en dash, em dash, or
  /// the word "to" as separator — e.g. `"12-15 minutes"`, `"12–15 minutes"`,
  /// `"12 to 15 minutes"`, `"1-2 hours"` — and returns the rounded average
  /// expressed in total minutes.
  ///
  /// Unit-agnostic: supports hours, minutes, and days as the trailing unit.
  /// Returns `null` when no range is present so callers fall back to their
  /// existing single-value extraction unchanged.
  static int? extractDurationRangeMinutes(String text) {
    final match = RegExp(
      r'(\d+(?:\.\d+)?)\s*(?:[-–—]|\bto\b)\s*(\d+(?:\.\d+)?)\s*(hours?|hrs?|hr|h|minutes?|mins?|min|m|days?|d)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    final first = double.tryParse(match.group(1) ?? '');
    final second = double.tryParse(match.group(2) ?? '');
    if (first == null || second == null) return null;

    final unit = (match.group(3) ?? '').toLowerCase();
    final average = (first + second) / 2;

    double multiplier;
    if (RegExp(r'^(hours?|hrs?|hr|h)$').hasMatch(unit)) {
      multiplier = 60;
    } else if (RegExp(r'^(days?|d)$').hasMatch(unit)) {
      multiplier = 1440;
    } else {
      multiplier = 1; // minutes
    }

    final totalMinutes = (average * multiplier).round();
    return totalMinutes > 0 ? totalMinutes : null;
  }

  // ── Task 5: PropertyValue ingredient reconstruction ───────────────────────

  /// Reconstructs a schema.org `PropertyValue`-shaped ingredient node
  /// (`{"@type": "PropertyValue", "value": ..., "unitText"|"unitCode": ...,
  /// "name": ...}`) into a single `"value unit name"` string, before it would
  /// otherwise degrade to a name-only (or empty) fallback.
  ///
  /// Returns `null` when [item] is not a `PropertyValue` node, or
  /// reconstruction produces nothing usable.
  static String? reconstructPropertyValueIngredient(Map item) {
    if (!_isType(item['@type'], 'PropertyValue')) return null;

    final rawValue = item['value'];
    final unit = _firstNonEmptyString([item['unitText'], item['unitCode']]);
    final name = _firstNonEmptyString([item['name']]);

    final parts = <String>[
      if (rawValue != null && rawValue.toString().trim().isNotEmpty)
        rawValue.toString().trim(),
      if (unit != null) unit,
      if (name != null) name,
    ];

    final reconstructed = parts.join(' ').trim();
    return reconstructed.isEmpty ? null : reconstructed;
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  /// Matches schema.org's `@type` convention where the value may be a bare
  /// string or a list of strings.
  static bool _isType(dynamic type, String expected) {
    if (type == expected) return true;
    if (type is List) return type.contains(expected);
    return false;
  }

  static String? _firstNonEmptyString(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c.trim();
    }
    return null;
  }
}
