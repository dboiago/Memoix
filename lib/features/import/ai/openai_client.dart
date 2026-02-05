/// OpenAI (ChatGPT, Responses API – vision + text)
// Uses vision + text together
// Forces JSON-only output
// Temperature = 0 (no creativity)
//Matches OpenAI’s current best practice

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

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

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": imageBytes != null ? "gpt-4o" : "gpt-4.1",
        "messages": messages,
        "temperature": 0.0,
        "response_format": { "type": "json_object" },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenAI error: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    return jsonDecode(decoded['choices'][0]['message']['content']);
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
