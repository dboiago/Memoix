/// Memoix hosted agent — forwards requests to the Memoix Cloudflare Worker.
///
/// When [baseUrl] resolves to an active generative endpoint, responses are
/// returned as structured JSON matching the same schema used by the other
/// provider clients. Until that endpoint is deployed, all calls return {}.
///
/// [apiKey] is forwarded as a Bearer token when non-empty; it is not required
/// when the hosted endpoint is used without a user-supplied key.

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'ai_http_utils.dart';

/// Default URL for the Memoix Cloudflare Worker generative endpoint.
const _kDefaultBaseUrl =
    'https://memoix-worker.dboiago.workers.dev/generate';

class MemoixClient {
  final String apiKey;
  final String model;

  /// Base URL for the hosted generative endpoint.
  ///
  /// Override this to point at a custom domain or staging environment.
  /// Only this value needs to change when the endpoint goes live.
  final String baseUrl;

  MemoixClient(this.apiKey, {this.model = '', this.baseUrl = _kDefaultBaseUrl});

  Future<Map<String, dynamic>> analyzeRecipe({
    required String systemPrompt,
    String? text,
    Uint8List? imageBytes,
    double temperature = 0.0,
  }) async {
    final client = http.Client();
    try {
      final body = <String, dynamic>{
        'system': systemPrompt,
        'temperature': temperature,
        if (text != null && text.trim().isNotEmpty) 'text': text,
        if (imageBytes != null) 'image': base64Encode(imageBytes),
      };

      final request = http.Request('POST', Uri.parse(baseUrl));
      request.headers['Content-Type'] = 'application/json';
      if (apiKey.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $apiKey';
      }
      request.body = jsonEncode(body);

      final streamed = await client.send(request);
      final responseBody = await readAiResponse(streamed, 'Memoix');
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) return decoded;
      return const {};
    } catch (_) {
      return const {};
    } finally {
      client.close();
    }
  }
}
