/// Gemini (Gemini 2.0 Flash)
// Fast, high-throughput model with generous free-tier limits
// Very good with dense scanned PDFs and images
  
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Maximum response body size (10 MB per AGENTS.md).
const _maxResponseBytes = 10 * 1024 * 1024;

class GeminiClient {
  final String apiKey;
  final String model;

  GeminiClient(this.apiKey, {this.model = 'gemini-2.0-flash'});

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
      final bodyBytes = await _readWithLimit(streamed);
      final body = utf8.decode(bodyBytes);

      if (streamed.statusCode != 200) {
        throw Exception('Gemini error (${streamed.statusCode}): $body');
      }

      final decoded = jsonDecode(body);
      return jsonDecode(
          decoded['candidates'][0]['content']['parts'][0]['text']);
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
