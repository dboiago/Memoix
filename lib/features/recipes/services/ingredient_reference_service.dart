/// Service that fetches AI-generated reference data for a single ingredient.
///
/// Reuses the existing [ClaudeClient] / [OpenAiClient] / [GeminiClient]
/// pipeline and follows the same error-handling pattern as [MemoixAiService].
///
/// This service is stateless — caching lives in the Riverpod provider layer.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_settings.dart';
import '../../ai/ai_settings_provider.dart';
import '../../ai/ai_provider_config.dart';
import '../../ai/services/ai_key_storage.dart';
import '../../import/ai/ai_provider.dart';
import '../../import/ai/claude_client.dart';
import '../../import/ai/gemini_client.dart';
import '../../import/ai/openai_client.dart';
import '../models/ingredient_reference.dart';

/// Timeout for a single ingredient reference request.
const _requestTimeout = Duration(seconds: 30);

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
  final AiSettings _settings;

  IngredientReferenceService(this._settings);

  /// Build the user message for the AI request.
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
    final active = _settings.activeProviders;
    if (active.isEmpty) {
      return const IngredientReferenceResult.error(
        'No AI providers are enabled. Enable one in Settings.',
      );
    }

    // Select provider — text-only, so prefer OpenAI > Claude > Gemini
    final provider = _selectProvider(active);

    final apiKey = await AiKeyStorage.getToken(provider);
    if (apiKey == null || apiKey.isEmpty) {
      return IngredientReferenceResult.error(
        'No API key set for ${_providerLabel(provider)}.',
      );
    }

    final userMessage = _buildUserMessage(
      ingredientName: ingredientName,
      category: category,
      cuisine: cuisine,
    );

    try {
      final model = _settings.configFor(provider).effectiveModel;
      final Map<String, dynamic> json;

      switch (provider) {
        case AiProvider.openai:
          json = await OpenAiClient(apiKey, model: model)
              .analyzeRecipe(
                systemPrompt: _systemPrompt,
                text: userMessage,
                temperature: 0.2,
              )
              .timeout(_requestTimeout);
          break;
        case AiProvider.claude:
          json = await ClaudeClient(apiKey, model: model)
              .analyzeRecipe(
                systemPrompt: _systemPrompt,
                text: userMessage,
                temperature: 0.2,
              )
              .timeout(_requestTimeout);
          break;
        case AiProvider.gemini:
          json = await GeminiClient(apiKey, model: model)
              .analyzeRecipe(
                systemPrompt: _systemPrompt,
                text: userMessage,
                temperature: 0.2,
              )
              .timeout(_requestTimeout);
          break;
      }

      // Parse the structured result — same try/catch pattern as AI import
      try {
        final ref = IngredientReference.fromJson(json);
        return IngredientReferenceResult.success(ref);
      } catch (e) {
        return IngredientReferenceResult.error(
          'Unable to parse ingredient reference',
          rawError: jsonEncode(json),
        );
      }
    } on TimeoutException {
      return const IngredientReferenceResult.error(
        'Request timed out. Try again.',
      );
    } on SocketException {
      return const IngredientReferenceResult.error(
        'No internet connection. Check your network.',
      );
    } on Exception catch (e) {
      return _classifyError(e, provider);
    }
  }

  /// Text-only request: prefer OpenAI > Claude > Gemini.
  AiProvider _selectProvider(List<AiProviderConfig> active) {
    final activeIds = active.map((c) => c.provider).toSet();

    if (!_settings.autoSelectProvider) {
      final preferred = _settings.preferredProvider;
      if (preferred != null && activeIds.contains(preferred)) {
        return preferred;
      }
      return active.first.provider;
    }

    for (final ideal in [
      AiProvider.openai,
      AiProvider.claude,
      AiProvider.gemini,
    ]) {
      if (activeIds.contains(ideal)) return ideal;
    }
    return active.first.provider;
  }

  /// Mirror [MemoixAiService._classifyError] — maps raw exceptions to
  /// user-facing messages with raw detail for clipboard copy.
  IngredientReferenceResult _classifyError(Exception e, AiProvider provider) {
    final raw = e.toString();
    final msg = raw.toLowerCase();
    final label = _providerLabel(provider);
    final rawForClipboard = raw.replaceFirst('Exception: ', '');

    if (msg.contains('401') || msg.contains('unauthorized')) {
      return IngredientReferenceResult.error(
        'Invalid API key for $label. Check Settings.',
        rawError: rawForClipboard,
      );
    }
    if (msg.contains('429') ||
        msg.contains('rate_limit') ||
        msg.contains('quota')) {
      return IngredientReferenceResult.error(
        '$label is rate-limited. Wait a moment.',
        rawError: rawForClipboard,
      );
    }
    if (msg.contains('formatexception') || msg.contains('unexpected')) {
      return IngredientReferenceResult.error(
        'Unable to fetch ingredient reference',
        rawError: rawForClipboard,
      );
    }

    return IngredientReferenceResult.error(
      'Unable to fetch ingredient reference',
      rawError: rawForClipboard,
    );
  }

  static String _providerLabel(AiProvider p) {
    switch (p) {
      case AiProvider.openai:
        return 'OpenAI';
      case AiProvider.claude:
        return 'Claude';
      case AiProvider.gemini:
        return 'Gemini';
    }
  }
}

/// Riverpod provider for the ingredient reference service.
final ingredientReferenceServiceProvider =
    Provider<IngredientReferenceService>((ref) {
  final settings = ref.watch(aiSettingsProvider);
  return IngredientReferenceService(settings);
});
