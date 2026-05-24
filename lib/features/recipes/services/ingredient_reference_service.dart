/// Service that fetches AI-generated reference data for a single ingredient.
///
/// Delegates provider dispatch, key management, and error classification to
/// [AiService] — caching lives in the Riverpod provider layer.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/models/ai_response.dart';
import '../../ai/services/ai_service.dart';
import '../../ai/services/memoix_ai_service.dart';
import '../models/ingredient_reference.dart';

/// System prompt sent to the AI for ingredient reference lookups.
const _systemPrompt = '''
You are a culinary reference assistant for professional and home cooks.

Given a single ingredient, return ONLY a JSON object with this exact shape:
{
  "description": string,
    // What the ingredient is. Max 10 words. Do NOT repeat the ingredient name.
    // Focus only on what it is, not history or origin.
    // Example good: "Slightly chewy yellow noodles made with wheat flour"
    // Example bad: "Alkaline noodles are a type of Asian noodle made with wheat
    //   flour, water and an alkaline solution, typically kansui, which gives them
    //   their characteristic yellow hue, springy texture, and slightly chewy bite."
  "aliases": string[],     // Common alternate names. Empty array if none.
  "flavour": string,
    // Flavour profile only. Max 12 words. No filler phrases.
    // Example good: "Neutral, slightly savoury flavour that absorbs accompanying sauces"
    // Example bad: "They have a neutral, slightly savoury flavour that readily absorbs
    //   the tastes of accompanying sauces and broths"
  "substitutions": [       // Max 3. Empty array if no good substitute exists.
    {
      "name": string,      // Substitute ingredient name
      "ratio": number,     // Units of substitute per 1 unit of original.
                           // 1.0 = same amount. Omit if uncertain.
      "note": string       // Max 8 words. Practical only. No filler.
    }
  ]
}

Rules:
- Return ONLY the JSON object. No markdown. No preamble. No explanation.
- Only include substitutes you are highly confident are used by professional cooks. When in doubt, omit.
- If uncertain about a ratio, omit the ratio field entirely — do not guess.
- If no good substitute exists, return an empty substitutions array.
- Use Canadian/British spelling throughout: "flavour" not "flavor", "savoury" not "savory", "colour" not "color".
''';

/// Result of an ingredient reference fetch — either success or typed error.
class IngredientReferenceResult {
  final IngredientReference? data;
  final String? errorMessage;
  final String? rawError;

  const IngredientReferenceResult.success(this.data)
      : errorMessage = null,
        rawError = null;

  const IngredientReferenceResult.error(this.errorMessage, {this.rawError})
      : data = null;

  bool get isSuccess => data != null;
}

/// Fetches ingredient reference data from the configured AI provider.
///
/// Does NOT cache — that responsibility belongs to the provider layer.
class IngredientReferenceService {
  final AiService _aiService;

  IngredientReferenceService(this._aiService);

  /// Build the user-facing text sent to the AI.
  static String _buildUserMessage({
    required String ingredientName,
    String? category,
    String? cuisine,
  }) {
    final buffer = StringBuffer('Ingredient: $ingredientName');
    if (category != null && category.isNotEmpty) {
      buffer.write('\nCategory: $category');
    }
    if (cuisine != null && cuisine.isNotEmpty) {
      buffer.write('\nCuisine: $cuisine');
    }
    return buffer.toString();
  }

  /// Fetch reference data for [ingredientName].
  ///
  /// [category] is from [IngredientService.classify()].
  /// [cuisine] is from the recipe model.
  Future<IngredientReferenceResult> fetchReference({
    required String ingredientName,
    String? category,
    String? cuisine,
  }) async {
    final userMessage = _buildUserMessage(
      ingredientName: ingredientName,
      category: category,
      cuisine: cuisine,
    );

    final response = await _aiService.sendMessage(AiRequest(
      text: userMessage,
      systemPrompt: _systemPrompt,
      temperature: 0.2,
    ));

    if (!response.isSuccess) {
      return IngredientReferenceResult.error(
        response.errorMessage,
        rawError: response.rawError,
      );
    }

    try {
      final ref = IngredientReference.fromJson(response.data!);
      return IngredientReferenceResult.success(ref);
    } catch (e) {
      return IngredientReferenceResult.error(
        'Unable to parse ingredient reference',
        rawError: jsonEncode(response.data!),
      );
    }
  }
}

/// Riverpod provider for the ingredient reference service.
final ingredientReferenceServiceProvider =
    Provider<IngredientReferenceService>((ref) {
  final service = ref.watch(aiServiceProvider);
  return IngredientReferenceService(service);
});
