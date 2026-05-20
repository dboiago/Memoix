import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import 'external_format_parser.dart';
import 'mealie_parser.dart';
import 'tandoor_parser.dart';

/// Dispatches generic `.zip` files to [MealieParser] or [TandoorParser] by
/// inspecting the archive structure — no full JSON parse required.
///
/// **Detection algorithm:**
///
/// 1. **Mealie** — presence of a `recipes/` top-level folder containing `.json`
///    files at depth 2 (`recipes/{slug}.json`) or depth 3
///    (`recipes/{slug}/{slug}.json`), where the first reachable JSON object
///    contains the key `recipeIngredient`.
///
/// 2. **Tandoor** — presence of files matching `recipes/{name}/recipe.json`
///    exactly, where the first reachable JSON object contains the key `steps`.
///
/// If the path structure is ambiguous (both patterns appear, or neither), a
/// single-field sniff on the first valid JSON entry under `recipes/` resolves
/// the tie: `recipeIngredient` key → Mealie; `steps` key → Tandoor.
///
/// If detection fails entirely, the summary carries a single
/// [ExternalParseFailure] with reason `'Unrecognised ZIP format'`.
class ZipDispatchParser implements ExternalFormatParser {
  static final _mealie = MealieParser();
  static final _tandoor = TandoorParser();

  @override
  Future<ExternalImportSummary> parse(Uint8List bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      debugPrint('ZipDispatchParser: failed to decode zip — $e');
      return ExternalImportSummary(
        recipes: [],
        skippedCount: 0,
        failures: [
          ExternalParseFailure(
            reason: 'Corrupt archive: ${_shortMessage(e)}',
          ),
        ],
      );
    }

    final target = _detect(archive);

    switch (target) {
      case _Target.mealie:
        debugPrint('ZipDispatchParser: dispatching to MealieParser');
        return _mealie.parse(bytes);
      case _Target.tandoor:
        debugPrint('ZipDispatchParser: dispatching to TandoorParser');
        return _tandoor.parse(bytes);
      case _Target.unknown:
        debugPrint('ZipDispatchParser: unrecognised ZIP format');
        return ExternalImportSummary(
          recipes: [],
          skippedCount: 0,
          failures: [
            const ExternalParseFailure(
              reason: 'Unrecognised ZIP format — expected a Mealie or Tandoor export',
            ),
          ],
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Detection
  // ---------------------------------------------------------------------------

  _Target _detect(Archive archive) {
    bool hasTandoorStructure = false;
    bool hasMealieStructure = false;

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      final parts = name.split('/');

      if (parts.isEmpty || parts[0].toLowerCase() != 'recipes') continue;

      // Tandoor: {Recipes}/{name}/recipe.json — 3 segments, last = recipe.json (case-insensitive folder)
      if (parts.length == 3 && parts[2] == 'recipe.json') {
        hasTandoorStructure = true;
      }

      // Mealie flat: recipes/{slug}.json — exactly 2 segments ending .json
      // Mealie subfolder: recipes/{slug}/recipe.json — 3 segments, last = recipe.json
      // (both covered here; subfolder Mealie also matches recipe.json so the
      // sniff step resolves the tie via recipeIngredient vs steps key)
      if (parts.length == 2 && name.endsWith('.json')) {
        hasMealieStructure = true;
      }
      if (parts.length == 3 && name.endsWith('.json') && parts[2] != 'recipe.json') {
        hasMealieStructure = true;
      }
    }

    // Unambiguous structural match
    if (hasTandoorStructure && !hasMealieStructure) return _Target.tandoor;
    if (hasMealieStructure && !hasTandoorStructure) return _Target.mealie;

    // Ambiguous or neither — sniff first reachable JSON under recipes/
    return _sniffFirstJson(archive);
  }

  /// Reads the first parseable JSON file under `recipes/` and checks which
  /// top-level key is present: `recipeIngredient` → Mealie; `steps` → Tandoor.
  _Target _sniffFirstJson(Archive archive) {
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      final lower = name.toLowerCase();
      if (!lower.startsWith('recipes/') || !lower.endsWith('.json')) continue;

      try {
        final jsonStr = utf8.decode(entry.content as List<int>);
        final json = jsonDecode(jsonStr);
        if (json is! Map<String, dynamic>) continue;

        if (json.containsKey('recipeIngredient')) return _Target.mealie;
        if (json.containsKey('steps')) return _Target.tandoor;
      } catch (_) {
        continue; // try the next entry
      }
    }

    return _Target.unknown;
  }

  String _shortMessage(Object e) {
    final msg = e.toString();
    return msg.length > 120 ? '${msg.substring(0, 117)}…' : msg;
  }
}

enum _Target { mealie, tandoor, unknown }
