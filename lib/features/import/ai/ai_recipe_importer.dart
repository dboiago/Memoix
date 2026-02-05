import 'dart:convert';
import 'dart:typed_data';

import '../../recipes/import/recipe_import_result.dart';
import 'ai_provider.dart';
import 'openai_client.dart';
import 'claude_client.dart';
import 'gemini_client.dart';

enum AiProvider {
  openai,
  claude,
  gemini,
}

enum AiImportInputType {
  image,
  url,
  rawText,
}

class AiImportInput {
  final AiImportInputType type;
  final String? text; // URL or raw text
  final Uint8List? image; // Image bytes

  AiImportInput.image(this.image)
      : type = AiImportInputType.image,
        text = null;

  AiImportInput.url(this.text)
      : type = AiImportInputType.url,
        image = null;

  AiImportInput.rawText(this.text)
      : type = AiImportInputType.rawText,
        image = null;
}

class AiRecipeImporter {
  final OpenAiClient openAi;
  final ClaudeClient claude;
  final GeminiClient gemini;

  final AiProvider defaultProvider;
  final bool autoSelect;

  AiRecipeImporter({
    required this.openAi,
    required this.claude,
    required this.gemini,
    required this.defaultProvider,
    this.autoSelect = true,
  });

  /// Main entry point for importing
  Future<RecipeImportResult> import(AiImportInput input, {String? sourceUrl}) async {
    final provider = _selectProvider(input);
    final systemPrompt = _buildSystemPrompt();
    final Map<String, dynamic> responseJson;

    switch (provider) {
      case AiProvider.openai:
        responseJson = await _importWithOpenAi(systemPrompt, input);
        break;
      case AiProvider.claude:
        responseJson = await _importWithClaude(systemPrompt, input);
        break;
      case AiProvider.gemini:
        responseJson = await _importWithGemini(systemPrompt, input);
        break;
    }

    return RecipeImportResult.fromAi({
      ...responseJson,
      'sourceUrl': sourceUrl,
      'source': 'ai',
    });
  }

  AiProvider _selectProvider(AiImportInput input) {
    if (!autoSelect) return defaultProvider;

    switch (input.type) {
      case AiImportInputType.image:
        return AiProvider.claude; // best vision reliability
      case AiImportInputType.url:
      case AiImportInputType.rawText:
        return AiProvider.openai;
    }
  }

  Future<Map<String, dynamic>> _importWithOpenAi(
    String systemPrompt,
    AiImportInput input,
  ) async {
    return openAi.extractRecipe(
      systemPrompt: systemPrompt,
      input: input,
    );
  }

  Future<Map<String, dynamic>> _importWithClaude(
    String systemPrompt,
    AiImportInput input,
  ) async {
    return claude.extractRecipe(
      systemPrompt: systemPrompt,
      input: input,
    );
  }

  Future<Map<String, dynamic>> _importWithGemini(
    String systemPrompt,
    AiImportInput input,
  ) async {
    return gemini.extractRecipe(
      systemPrompt: systemPrompt,
      input: input,
    );
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

Layout handling:
- Images may contain multiple columns, pages, or non-linear layouts.
- You may reorder text mentally to reconstruct the recipe.
- Do not assume left-to-right, top-to-bottom order.

Multi-recipe handling:
- If more than one recipe is detected:
  - Identify each recipe internally.
  - Select the most complete recipe as the primary result.
  - Reduce overall confidence.
  - Preserve all original text in rawText.
  - Do not mention discarded recipes unless asked.

Output requirements:
- Title
- Ingredients (structured if possible, raw otherwise)
- Instructions
- Optional metadata (time, servings)
- Per-field confidence scores (0.0–1.0)
- Overall confidence score

Formatting rules:
- Ingredients must remain separate entries.
- Instructions must preserve original order.
- Do not guess missing quantities.

Output ONLY valid JSON.
''';
  }
}
