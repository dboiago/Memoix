import 'dart:convert';
import 'dart:typed_data';

import '../../recipes/import/recipe_import_result.dart';
import 'ai_provider.dart';
import 'openai_client.dart';
import 'claude_client.dart';
import 'gemini_client.dart';

class AiRecipeImporter {
  final AiProvider provider;
  final String apiKey;

  AiRecipeImporter({
    required this.provider,
    required this.apiKey,
  });

  /// Main entry point
  ///
  /// At least ONE of [ocrText], [imageBytes], or [urlText] must be provided
  Future<RecipeImportResult> importRecipe({
    String? ocrText,
    Uint8List? imageBytes,
    String? urlText,
    String? sourceUrl,
  }) async {
    if (ocrText == null && imageBytes == null && urlText == null) {
      throw ArgumentError('AI import requires OCR text, image, or URL content');
    }

    final systemPrompt = _buildSystemPrompt();

    final Map<String, dynamic> responseJson;

    switch (provider) {
      case AiProvider.openai:
        responseJson = await OpenAiClient(apiKey).analyzeRecipe(
          systemPrompt: systemPrompt,
          imageBytes: imageBytes,
          text: _combineText(ocrText, urlText),
        );
        break;

      case AiProvider.claude:
        responseJson = await ClaudeClient(apiKey).analyzeRecipe(
          systemPrompt: systemPrompt,
          imageBytes: imageBytes,
          text: _combineText(ocrText, urlText),
        );
        break;

      case AiProvider.gemini:
        responseJson = await GeminiClient(apiKey).analyzeRecipe(
          systemPrompt: systemPrompt,
          imageBytes: imageBytes,
          text: _combineText(ocrText, urlText),
        );
        break;
    }

    return RecipeImportResult.fromAi({
      ...responseJson,
      'sourceUrl': sourceUrl,
      'source': 'ai',
    });
  }

  /// Combine OCR + URL text without losing provenance
  String? _combineText(String? ocrText, String? urlText) {
    if (ocrText == null && urlText == null) return null;
    if (ocrText != null && urlText == null) return ocrText;
    if (ocrText == null && urlText != null) return urlText;

    return '''
--- OCR TEXT ---
$ocrText

--- URL TEXT ---
$urlText
''';
  }

  String _buildSystemPrompt() {
    return '''
You are extracting structured recipe data from OCR text or images.

Your goal is accuracy, not completeness.

Rules:
- Do NOT invent ingredients, quantities, or steps.
- Preserve original wording whenever possible.
- If information is unclear, omit it or mark it as uncertain.
- Never merge multiple recipes into one.

Multi-recipe handling:
- If more than one recipe is detected:
  - Identify each recipe internally.
  - Select the most complete recipe as the primary result.
  - Reduce overall confidence.
  - Preserve all original text in rawText.
  - Do not mention discarded recipes unless asked.

Output requirements:
- title
- ingredients
- instructions
- optional metadata (time, servings)
- per-field confidence scores (0.0–1.0)
- overall confidence score

Formatting rules:
- Ingredients must remain separate entries.
- Instructions must preserve original order.
- Do not guess missing quantities.

If input is ambiguous, prioritize transparency.

Return ONLY valid JSON.
''';
  }
}
