import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai_provider_config.dart';
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
    final active = _settings.activeProviders;

    // No providers enabled + configured → hard stop
    if (active.isEmpty) {
      return const AiResponse.error(
        'No AI providers are enabled. Enable one in Settings → Agents.',
        AiErrorType.disabled,
      );
    }

    // Resolve which provider to use (respects enabled state)
    final provider = request.provider ?? _selectProvider(request, active);

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
      final model = _settings.configFor(provider).effectiveModel;

      final Map<String, dynamic> json;
      switch (provider) {
        case AiProvider.openai:
          json = await OpenAiClient(apiKey, model: model)
              .analyzeRecipe(
                systemPrompt: systemPrompt,
                text: request.text,
                imageBytes: request.imageBytes,
              )
              .timeout(_requestTimeout);
          break;
        case AiProvider.claude:
          json = await ClaudeClient(apiKey, model: model)
              .analyzeRecipe(
                systemPrompt: systemPrompt,
                text: request.text,
                imageBytes: request.imageBytes,
              )
              .timeout(_requestTimeout);
          break;
        case AiProvider.gemini:
          json = await GeminiClient(apiKey, model: model)
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

  /// Resolve which provider to use.
  ///
  /// Rules (in order):
  /// 1. If auto-select is **off** and the preferred provider is active → use it.
  /// 2. If auto-select is **off** but preferred provider is NOT active →
  ///    fall back to whatever IS active (first match).
  /// 3. If auto-select is **on** → pick the best active provider for the
  ///    request type (vision → Claude, text → OpenAI) but only from the
  ///    active list. If the ideal choice is not active, use the first active.
  AiProvider _selectProvider(
    AiRequest request,
    List<AiProviderConfig> active,
  ) {
    final activeIds = active.map((c) => c.provider).toSet();

    // ── Manual preferred provider ──
    if (!_settings.autoSelectProvider) {
      final preferred = _settings.preferredProvider;
      if (preferred != null && activeIds.contains(preferred)) {
        return preferred;
      }
      // Preferred not active – fall back to first active
      return active.first.provider;
    }

    // ── Auto-select: pick best match from active providers ──
    if (request.imageBytes != null) {
      // Vision: prefer Claude > Gemini > OpenAI
      for (final ideal in [AiProvider.claude, AiProvider.gemini, AiProvider.openai]) {
        if (activeIds.contains(ideal)) return ideal;
      }
    } else {
      // Text: prefer OpenAI > Claude > Gemini
      for (final ideal in [AiProvider.openai, AiProvider.claude, AiProvider.gemini]) {
        if (activeIds.contains(ideal)) return ideal;
      }
    }

    // Should never reach here (active is non-empty), but safe fallback
    return active.first.provider;
  }

  /// Turn an opaque [Exception] from a client into a typed [AiResponse].
  AiResponse _classifyError(Exception e, AiProvider provider) {
    final raw = e.toString();
    final msg = raw.toLowerCase();
    final label = _providerLabel(provider);
    // The raw string to hand to the copy button—strips the Dart "Exception: " prefix.
    final rawForClipboard = raw.replaceFirst('Exception: ', '');

    if (msg.contains('404') || msg.contains('not found') || msg.contains('does not exist')) {
      return AiResponse.error(
        'Model not available for your $label key. '
        'Choose a different model in Settings → Agents.',
        AiErrorType.invalidToken,
        rawError: rawForClipboard,
      );
    }
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return AiResponse.error(
        'Invalid API key for $label. '
        'Check or replace it in Settings → Agents.',
        AiErrorType.invalidToken,
        rawError: rawForClipboard,
      );
    }
    if (msg.contains('403') || msg.contains('forbidden')) {
      return AiResponse.error(
        'Access denied by $label. '
        'Your key may lack the required permissions.',
        AiErrorType.invalidToken,
        rawError: rawForClipboard,
      );
    }
    // 400 can indicate an invalid API key (Gemini: API_KEY_INVALID),
    // an unsupported model, or a malformed request body.
    if (msg.contains('400') ||
        msg.contains('api_key_invalid') ||
        msg.contains('invalid_argument')) {
      return AiResponse.error(
        'Request rejected by $label (400). '
        'Your API key may be invalid or the model may not support this '
        'request type. Check your key in Settings → Agents.',
        AiErrorType.invalidToken,
        rawError: rawForClipboard,
      );
    }
    // Use specific terms to avoid false-positives — the word "generate"
    // (as in "GenerateContent") contains the substring "rate" and would
    // mis-fire here if we used msg.contains('rate').
    if (msg.contains('429') ||
        msg.contains('resource_exhausted') ||
        msg.contains('rate_limit') ||
        msg.contains('quota')) {
      return AiResponse.error(
        '$label is rate-limited. Wait a moment and try again.',
        AiErrorType.rateLimited,
        rawError: rawForClipboard,
      );
    }
    if (msg.contains('503') ||
        msg.contains('unavailable') ||
        msg.contains('overloaded')) {
      final apiMsg = _extractApiMessage(raw);
      return AiResponse.error(
        apiMsg != null
            ? '$label (503): $apiMsg'
            : '$label is temporarily unavailable. Try again in a moment.',
        AiErrorType.unknown,
        rawError: rawForClipboard,
      );
    }
    if (msg.contains('formatexception') || msg.contains('unexpected')) {
      return AiResponse.error(
        'The AI returned an unreadable response. Try again.',
        AiErrorType.malformedResponse,
        rawError: rawForClipboard,
      );
    }
    // Generic fallback: try to surface the API's own message rather than
    // dumping raw JSON at the user.
    final apiMsg = _extractApiMessage(raw);
    final statusMatch = RegExp(r'\((\d{3})\)').firstMatch(raw);
    final status = statusMatch?.group(1);
    return AiResponse.error(
      apiMsg != null
          ? '$label error${status != null ? ' ($status)' : ''}: $apiMsg'
          : 'Unexpected error from $label. Tap the copy icon for details.',
      AiErrorType.unknown,
      rawError: rawForClipboard,
    );
  }

  /// Extract the human-readable message from a raw API error body.
  ///
  /// Handles the JSON shapes used by Gemini, OpenAI, and Claude—all of which
  /// nest the user-facing message under `error.message`.
  /// Returns `null` if the body cannot be parsed.
  static String? _extractApiMessage(String exceptionStr) {
    final jsonStart = exceptionStr.indexOf('{');
    if (jsonStart == -1) return null;
    try {
      final decoded =
          jsonDecode(exceptionStr.substring(jsonStart)) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map) {
        final message = error['message'] as String?;
        if (message != null && message.trim().isNotEmpty) return message.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
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
