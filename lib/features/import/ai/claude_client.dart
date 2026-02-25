/// Claude (Anthropic, Messages API)
// Excellent at multi-column cookbooks
// Very conservative
// Doesn’t hallucinate structure as aggressively
  
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Maximum response body size (10 MB per AGENTS.md).
const _maxResponseBytes = 10 * 1024 * 1024;

class ClaudeClient {
  final String apiKey;

  ClaudeClient(this.apiKey);

  Future<Map<String, dynamic>> analyzeRecipe({
    required String systemPrompt,
    String? text,
    Uint8List? imageBytes,
  }) async {
    final content = <Map<String, dynamic>>[];

    if (text != null && text.trim().isNotEmpty) {
      content.add({
        "type": "text",
        "text": text,
      });
    }

    if (imageBytes != null) {
      content.add({
        "type": "image",
        "source": {
          "type": "base64",
          "media_type": "image/jpeg",
          "data": base64Encode(imageBytes),
        }
      });
    }

    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('https://api.anthropic.com/v1/messages'),
      );
      request.headers.addAll({
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      });
      request.body = jsonEncode({
        "model": "claude-3-5-sonnet-20240620",
        "system": systemPrompt,
        "messages": [
          {"role": "user", "content": content}
        ],
        "temperature": 0.0,
        "max_tokens": 4096,
      });

      final streamed = await client.send(request);
      final bodyBytes = await _readWithLimit(streamed);
      final body = utf8.decode(bodyBytes);

      if (streamed.statusCode != 200) {
        throw Exception('Claude error (${streamed.statusCode}): $body');
      }

      final decoded = jsonDecode(body);
      return jsonDecode(decoded['content'][0]['text']);
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
}
