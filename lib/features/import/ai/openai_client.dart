/// OpenAI (ChatGPT, Responses API – vision + text)
// Uses vision + text together
// Forces JSON-only output
// Temperature = 0 (no creativity)
//Matches OpenAI’s current best practice

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'ai_http_utils.dart';

class OpenAiClient {
  final String apiKey;
  final String model;

  OpenAiClient(this.apiKey, {this.model = 'gpt-4.1'});

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
        "model": model,
        "messages": messages,
        "temperature": 0.0,
        "response_format": {"type": "json_object"},
      });

      final streamed = await client.send(request);
      final body = await readAiResponse(streamed, 'OpenAI');
      final decoded = jsonDecode(body);
      return jsonDecode(decoded['choices'][0]['message']['content']);
    } finally {
      client.close();
    }
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
