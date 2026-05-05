import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/knowledge_payload.dart';
import 'rag_transmission_client.dart';
import '../../features/recipes/models/recipe.dart';
import '../../features/settings/screens/settings_screen.dart';

/// Decoupled service for the Culinary Intelligence RAG pipeline.
///
/// Validates privacy gates, constructs a [KnowledgePayload], and delegates
/// transmission to the injected [RagTransmissionClient]. The default client
/// is [ConsoleTransmissionClient]; swap it for a network client when a
/// backend is available — no other code needs to change.
///
/// **Privacy guarantees enforced here:**
/// 1. The individual [Recipe.isShared] flag must be true.
/// 2. The master 'Contribute to Culinary Intelligence' switch must be ON.
/// If either condition fails, the method returns immediately with no side effects.
class RagTelemetryService {
  final Ref _ref;
  final RagTransmissionClient _client;

  RagTelemetryService(this._ref, this._client);

  /// Validates privacy gates, constructs a [KnowledgePayload], and delegates
  /// to [RagTransmissionClient.transmit].
  ///
  /// [recipe] — the fully hydrated recipe to export.
  /// [rawSource] — the original text that produced this recipe (OCR, URL, typed input, etc.).
  /// Optional: pass null or omit for recipes created or edited manually.
  Future<void> queueForExport(Recipe recipe, [String? rawSource]) async {
    // Gate 1 (sync, no state read): individual recipe must opt in via isShared.
    // Checked first so we never touch Riverpod state for recipes the user has
    // explicitly marked as hidden.
    if (!recipe.isShared) {
      debugPrint(
        'RagTelemetryService: skipped \u2014 recipe "${recipe.name}" (${recipe.uuid}) '
        'has isShared = false.',
      );
      return;
    }

    // Gate 2: master Culinary Intelligence switch must be explicitly ON.
    final masterSwitchOn = _ref.read(contributeToIntelligenceProvider);
    if (!masterSwitchOn) {
      debugPrint(
        'RagTelemetryService: skipped \u2014 master Culinary Intelligence switch is OFF.',
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

    await _client.transmit(payload);
  }
}

/// Provider for [RagTelemetryService].
/// Injects [ConsoleTransmissionClient] as the default transmission strategy.
/// Replace with a network client here when a backend is configured.
final ragTelemetryServiceProvider = Provider<RagTelemetryService>((ref) {
  return RagTelemetryService(ref, const ConsoleTransmissionClient());
});
