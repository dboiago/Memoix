/// Gemini (Gemini 2.0 Flash)
// Fast, high-throughput model with generous free-tier limits
// Very good with dense scanned PDFs and images
  
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'ai_http_utils.dart';

class GeminiClient {
  final String apiKey;
  final String model;

  GeminiClient(this.apiKey, {this.model = 'gemini-2.5-flash-lite'});

  Future<Map<String, dynamic>> analyzeRecipe({
    required String systemPrompt,
    String? text,
    Uint8List? imageBytes,
  }) async {
    final parts = <Map<String, dynamic>>[];

    if (text != null && text.trim().isNotEmpty) {
      parts.add({"text": text});
    }

    if (imageBytes != null) {
      parts.add({
        "inlineData": {
          "mimeType": "image/jpeg",
          "data": base64Encode(imageBytes),
        }
      });
    }

    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/'
          '$model:generateContent?key=$apiKey',
        ),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode({
        "systemInstruction": {
          "parts": [
            {"text": systemPrompt}
          ]
        },
        "contents": [
          {
            "role": "user",
            "parts": parts,
          }
        ],
        "generationConfig": {
          "temperature": 0.0,
          "responseMimeType": "application/json",
        }
      });

      final streamed = await client.send(request);
      final body = await readAiResponse(streamed, 'Gemini');
      final decoded = jsonDecode(body);
      return jsonDecode(
          decoded['candidates'][0]['content']['parts'][0]['text']);
    } finally {
      client.close();
    }
  }
}
