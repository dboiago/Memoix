import 'dart:typed_data';

import '../models/ai_response.dart';
import '../../import/ai/ai_provider.dart';

/// Request payload for the AI service.
///
/// Exactly one of [text] or [imageBytes] must be non-null.
class AiRequest {
  /// Free-form text or URL the user wants analysed.
  final String? text;

  /// Image bytes (JPEG) for vision-based extraction.
  final Uint8List? imageBytes;

  /// Which provider to use. `null` means auto-select.
  final AiProvider? provider;

  /// Sampling temperature forwarded to the provider. `null` uses the
  /// service default (0.0 for recipe extraction, 0.2 for reference lookups).
  final double? temperature;

  /// Override the system prompt. When `null`, each feature supplies its own
  /// default (e.g. [AiRecipeImporter.buildSystemPrompt] for import calls).
  final String? systemPrompt;

  const AiRequest({this.text, this.imageBytes, this.provider, this.temperature, this.systemPrompt});
}

/// Clean abstraction over any AI provider.
///
/// Implementations must:
/// * Inject the token at call time (not store it).
/// * Return [AiResponse] – never throw.
/// * Contain **no** UI or storage logic.
abstract class AiService {
  /// Send a structured request and return a structured response.
  Future<AiResponse> sendMessage(AiRequest request);
}
