import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai_settings.dart';
import '../ai_settings_provider.dart';
import '../models/ai_response.dart';
import '../../import/ai/ai_provider.dart';
import '../../import/ai/ai_recipe_importer.dart';
import '../../import/ai/openai_client.dart';
import '../../import/ai/claude_client.dart';
import '../../import/ai/gemini_client.dart';
import 'ai_key_storage.dart';
import 'ai_service.dart';

/// Timeout for a single AI request.
const _requestTimeout = Duration(seconds: 60);

/// Concrete [AiService] backed by the three provider clients.
///
/// * Reads the API key from [AiKeyStorage] at call time.
/// * Never stores credentials in memory beyond the request scope.
/// * Maps all failure modes to [AiResponse.error].
class MemoixAiService implements AiService {
  final AiSettings _settings;

  MemoixAiService(this._settings);

  @override
  Future<AiResponse> sendMessage(AiRequest request) async {
    // Check if any provider is active
    if (_settings.activeProviders.isEmpty) {
      return const AiResponse.error(
        'No AI providers are enabled. Enable one in Settings → Agents.',
        AiErrorType.disabled,
      );
    }

    // Determine provider
    final provider = request.provider ?? _selectProvider(request);
    final config = _settings.configFor(provider);

    if (!config.enabled) {
      return AiResponse.error(
        '${_providerLabel(provider)} is disabled in settings.',
        AiErrorType.disabled,
      );
    }

    // Read key from secure storage
    final apiKey = await AiKeyStorage.getToken(provider);
    if (apiKey == null || apiKey.isEmpty) {
      return AiResponse.error(
        'No API key set for ${_providerLabel(provider)}. '
        'Add one in Settings → Agents.',
        AiErrorType.noToken,
      );
    }

    try {
      final systemPrompt = AiRecipeImporter.buildSystemPrompt();

      final Map<String, dynamic> json;
      switch (provider) {
        case AiProvider.openai:
          json = await OpenAiClient(apiKey)
              .analyzeRecipe(
                systemPrompt: systemPrompt,
                text: request.text,
                imageBytes: request.imageBytes,
              )
              .timeout(_requestTimeout);
          break;
        case AiProvider.claude:
          json = await ClaudeClient(apiKey)
              .analyzeRecipe(
                systemPrompt: systemPrompt,
                text: request.text,
                imageBytes: request.imageBytes,
              )
              .timeout(_requestTimeout);
          break;
        case AiProvider.gemini:
          json = await GeminiClient(apiKey)
              .analyzeRecipe(
                systemPrompt: systemPrompt,
                text: request.text,
                imageBytes: request.imageBytes,
              )
              .timeout(_requestTimeout);
          break;
      }

      return AiResponse.success(json);
    } on TimeoutException {
      return const AiResponse.error(
        'The request timed out. Try again or choose a different provider.',
        AiErrorType.timeout,
      );
    } on SocketException {
      return const AiResponse.error(
        'No internet connection. Check your network and try again.',
        AiErrorType.noInternet,
      );
    } on Exception catch (e) {
      return _classifyError(e, provider);
    }
  }

  /// Auto-select the best provider for a given request.
  AiProvider _selectProvider(AiRequest request) {
    if (!_settings.autoSelectProvider &&
        _settings.preferredProvider != null) {
      return _settings.preferredProvider!;
    }
    // Vision → Claude, Text → OpenAI (matches existing logic)
    if (request.imageBytes != null) return AiProvider.claude;
    return AiProvider.openai;
  }

  /// Turn an opaque [Exception] from a client into a typed [AiResponse].
  AiResponse _classifyError(Exception e, AiProvider provider) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return AiResponse.error(
        'Invalid API key for ${_providerLabel(provider)}. '
        'Check or replace it in Settings → Agents.',
        AiErrorType.invalidToken,
      );
    }
    if (msg.contains('403') || msg.contains('forbidden')) {
      return AiResponse.error(
        'Access denied by ${_providerLabel(provider)}. '
        'Your key may lack the required permissions.',
        AiErrorType.invalidToken,
      );
    }
    if (msg.contains('429') || msg.contains('rate')) {
      return AiResponse.error(
        'Rate limit exceeded. Wait a moment and try again.',
        AiErrorType.rateLimited,
      );
    }
    if (msg.contains('formatexception') || msg.contains('unexpected')) {
      return AiResponse.error(
        'The AI returned an unreadable response. Try again.',
        AiErrorType.malformedResponse,
      );
    }
    return AiResponse.error(
      'Something went wrong: ${e.toString().replaceAll('Exception: ', '')}',
      AiErrorType.unknown,
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

/// Riverpod provider for the AI service, rebuilt whenever settings change.
final aiServiceProvider = Provider<AiService>((ref) {
  final settings = ref.watch(aiSettingsProvider);
  return MemoixAiService(settings);
});
