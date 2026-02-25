/// OpenAI (ChatGPT, Responses API – vision + text)
// Uses vision + text together
// Forces JSON-only output
// Temperature = 0 (no creativity)
//Matches OpenAI’s current best practice

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Maximum response body size (10 MB per AGENTS.md).
const _maxResponseBytes = 10 * 1024 * 1024;

class OpenAiClient {
  final String apiKey;

  OpenAiClient(this.apiKey);

  Future<Map<String, dynamic>> analyzeRecipe({
    required String systemPrompt,
    String? text,
    Uint8List? imageBytes,
  }) async {
    final messages = <Map<String, dynamic>>[
      {
        "role": "system",
        "content": systemPrompt,
      },
      {
        "role": "user",
        "content": _buildUserContent(text, imageBytes),
      }
    ];

    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('https://api.openai.com/v1/chat/completions'),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode({
        "model": imageBytes != null ? "gpt-4o" : "gpt-4.1",
        "messages": messages,
        "temperature": 0.0,
        "response_format": {"type": "json_object"},
      });

      final streamed = await client.send(request);
      final bodyBytes = await _readWithLimit(streamed);
      final body = utf8.decode(bodyBytes);

      if (streamed.statusCode != 200) {
        throw Exception('OpenAI error (${streamed.statusCode}): $body');
      }

      final decoded = jsonDecode(body);
      return jsonDecode(decoded['choices'][0]['message']['content']);
    } finally {
      client.close();
    }
  }

  Future<List<int>> _readWithLimit(http.StreamedResponse response) async {
    final buffer = <int>[];
    await for (final chunk in response.stream) {
      buffer.addAll(chunk);
      if (buffer.length > _maxResponseBytes) {
        throw Exception(
            'Response exceeded ${_maxResponseBytes ~/ (1024 * 1024)} MB limit');
      }
    }
    return buffer;
  }

  List<Map<String, dynamic>> _buildUserContent(
    String? text,
    Uint8List? imageBytes,
  ) {
    final content = <Map<String, dynamic>>[];

    if (text != null && text.trim().isNotEmpty) {
      content.add({
        "type": "text",
        "text": text,
      });
    }

    if (imageBytes != null) {
      content.add({
        "type": "image_url",
        "image_url": {
          "url": "data:image/jpeg;base64,${base64Encode(imageBytes)}"
        }
      });
    }

    return content;
  }
}
