/// Claude (Anthropic, Messages API)
// Excellent at multi-column cookbooks
// Very conservative
// Doesn’t hallucinate structure as aggressively
  
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

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

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        "model": "claude-3-5-sonnet-20240620",
        "system": systemPrompt,
        "messages": [
          { "role": "user", "content": content }
        ],
        "temperature": 0.0,
        "max_tokens": 4096,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Claude error: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    return jsonDecode(decoded['content'][0]['text']);
  }
}
