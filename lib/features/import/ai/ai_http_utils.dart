/// Shared HTTP utilities for all AI provider clients.
///
/// Centralises the response-reading, size-limiting, logging, and error-throwing
/// logic that would otherwise be duplicated across GeminiClient, OpenAiClient,
/// and ClaudeClient.

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Maximum AI response body size (10 MB, per AGENTS.md security rules).
const int kMaxAiResponseBytes = 10 * 1024 * 1024;

/// Reads a streamed HTTP response, enforces a [maxBytes] size cap, then:
///
/// * Decodes the body as UTF-8.
/// * On non-200 status: logs the raw status code and body at WARNING level,
///   then throws a labelled [Exception] so the service layer can inspect it.
/// * On 200: returns the decoded body string for further parsing.
///
/// [provider] is used as the label in log entries and exception messages
/// (e.g. `'Gemini'`, `'OpenAI'`, `'Claude'`).
Future<String> readAiResponse(
  http.StreamedResponse response,
  String provider, {
  int maxBytes = kMaxAiResponseBytes,
}) async {
  final buffer = <int>[];
  await for (final chunk in response.stream) {
    buffer.addAll(chunk);
    if (buffer.length > maxBytes) {
      throw Exception(
        'Response exceeded ${maxBytes ~/ (1024 * 1024)} MB limit',
      );
    }
  }

  final body = utf8.decode(buffer);

  if (response.statusCode != 200) {
    throw Exception('$provider error (${response.statusCode}): $body');
  }

  return body;
}
