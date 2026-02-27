import 'dart:typed_data';

import '../../import/models/recipe_import_result.dart';
import 'ai_provider.dart';
import 'openai_client.dart';
import 'claude_client.dart';
import 'gemini_client.dart';

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
    final systemPrompt = buildSystemPrompt();
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
      if (sourceUrl != null) 'sourceUrl': sourceUrl,
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
    return openAi.analyzeRecipe(
      systemPrompt: systemPrompt,
      text: input.text,
      imageBytes: input.image,
    );
  }

  Future<Map<String, dynamic>> _importWithClaude(
    String systemPrompt,
    AiImportInput input,
  ) async {
    return claude.analyzeRecipe(
      systemPrompt: systemPrompt,
      text: input.text,
      imageBytes: input.image,
    );
  }

  Future<Map<String, dynamic>> _importWithGemini(
    String systemPrompt,
    AiImportInput input,
  ) async {
    return gemini.analyzeRecipe(
      systemPrompt: systemPrompt,
      text: input.text,
      imageBytes: input.image,
    );
  }

  static String buildSystemPrompt() {
    return r'''
You are extracting structured recipe data from OCR text or images.

Your goal is accuracy, not completeness.

Rules:
- Do NOT invent ingredients, quantities, or steps.
- Preserve original wording whenever possible.
- If information is unclear, omit it — do not guess.
- Never merge multiple recipes into one.

Layout handling:
- Images may contain multiple columns, pages, or non-linear layouts.
- You may reorder text mentally to reconstruct the recipe.
- Do not assume left-to-right, top-to-bottom order.
- Sidebar notes, drink pairings, and serving suggestions are NOT directions.

Multi-recipe handling:
- If more than one recipe is detected, select the most complete recipe as
  the primary result and reduce overall confidence.

Output ONLY valid JSON matching EXACTLY this schema — no extra keys, no
renamed keys, no markdown fences:

{
  "name": "<recipe title as a string>",
  "course": "<one of: Mains | Desserts | Baking | Brunch | Sides | Salads | Soups | Drinks | Sandwiches | Smoking | Pizzas | Modernist | Cheese | Cellar | Snacks>",
  "cuisine": "<country or region, or null>",
  "serves": "<serving size as a string, e.g. \"4\" or \"Makes 12\", or null>",
  "time": "<total time as a string, e.g. \"1 hr 15 mins\", or null>",
  "ingredients": [
    {
      "name": "<ingredient name>",
      "amount": "<numeric quantity as a string, e.g. \"250\" or \"1½\", or null>",
      "unit": "<unit of measurement, e.g. \"g\" or \"cup\", or null>",
      "preparation": "<prep note, e.g. \"peeled and crushed\", or null>",
      "section": "<ingredient group heading if present, e.g. \"For the sauce\", or null>"
    }
  ],
  "directions": [
    "<step 1 as a plain string>",
    "<step 2 as a plain string>"
  ],
  "comments": "<chef notes, serving suggestions, drink pairings — everything that is NOT an ingredient or direction — or null>",
  "nameConfidence": <0.0–1.0>,
  "courseConfidence": <0.0–1.0>,
  "cuisineConfidence": <0.0–1.0>,
  "ingredientsConfidence": <0.0–1.0>,
  "directionsConfidence": <0.0–1.0>,
  "servesConfidence": <0.0–1.0>,
  "timeConfidence": <0.0–1.0>
}

Confidence scoring:
- 1.0 = clearly present and unambiguous
- 0.7 = present but slightly uncertain
- 0.4 = partially extracted or guessed
- 0.0 = not found

Do not include any text outside the JSON object.
''';
  }
}
