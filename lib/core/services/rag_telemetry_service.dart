import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/knowledge_payload.dart';
import '../../features/recipes/models/recipe.dart';
import '../../features/settings/screens/settings_screen.dart';

/// Decoupled service for the Culinary Intelligence RAG pipeline.
///
/// This service is intentionally forward-looking: it has no backend dependency.
/// When [queueForExport] is called it validates the privacy gates, constructs a
/// [KnowledgePayload], and outputs the formatted JSON to the debug console.
///
/// When a backend is eventually configured, replace the [debugPrint] call with
/// an HTTP POST to the appropriate endpoint. No other logic needs to change.
///
/// **Privacy guarantees enforced here:**
/// 1. The master 'Contribute to Culinary Intelligence' switch must be ON.
/// 2. The individual [Recipe.isShared] flag must be true.
/// If either condition fails, the method returns immediately with no side effects.
class RagTelemetryService {
  final Ref _ref;

  RagTelemetryService(this._ref);

  /// Validates privacy gates, constructs a [KnowledgePayload], and outputs the
  /// serialised JSON to the debug console.
  ///
  /// [recipe] — the fully hydrated recipe to export.
  /// [rawSource] — the original text that produced this recipe (OCR, URL, typed input, etc.).
  /// Optional: pass null or omit for recipes created or edited manually.
  Future<void> queueForExport(Recipe recipe, [String? rawSource]) async {
    // Gate 1: master switch must be explicitly enabled by the user.
    final masterSwitchOn = _ref.read(contributeToIntelligenceProvider);
    if (!masterSwitchOn) {
      debugPrint(
        'RagTelemetryService: skipped \u2014 master Culinary Intelligence switch is OFF.',
      );
      return;
    }

    // Gate 2: individual recipe must have isShared set to true.
    if (!recipe.isShared) {
      debugPrint(
        'RagTelemetryService: skipped \u2014 recipe "${recipe.name}" (${recipe.uuid}) '
        'has isShared = false.',
      );
      return;
    }

    // Collect metadata. Version comes from the platform asynchronously.
    final packageInfo = await PackageInfo.fromPlatform();

    final metadata = <String, String>{
      'appVersion': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
    };

    final payload = KnowledgePayload(
      recipe: recipe,
      rawSource: rawSource,
      metadata: metadata,
    );

    // No backend yet \u2014 output the structured payload to the console for validation.
    debugPrint(
      '\n\u250c\u2500 RagTelemetryService: KnowledgePayload \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n'
      '${payload.toPrettyJson()}'
      '\n\u2514\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n',
    );
  }
}

/// Provider for [RagTelemetryService].
final ragTelemetryServiceProvider = Provider<RagTelemetryService>((ref) {
  return RagTelemetryService(ref);
});
