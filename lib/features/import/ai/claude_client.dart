/// Claude (Anthropic, Messages API)
// Excellent at multi-column cookbooks
// Very conservative
// Doesn’t hallucinate structure as aggressively
  
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'ai_http_utils.dart';

class ClaudeClient {
  final String apiKey;
  final String model;

  ClaudeClient(this.apiKey, {this.model = 'claude-sonnet-4-20250514'});

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
        "model": model,
        "system": systemPrompt,
        "messages": [
          {"role": "user", "content": content}
        ],
        "temperature": 0.0,
        "max_tokens": 4096,
      });

      final streamed = await client.send(request);
      final body = await readAiResponse(streamed, 'Claude');
      final decoded = jsonDecode(body);
      return jsonDecode(decoded['content'][0]['text']);
    } finally {
      client.close();
    }
  }
}
