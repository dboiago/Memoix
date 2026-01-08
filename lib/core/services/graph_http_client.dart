import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP client wrapper for Microsoft Graph API
/// 
/// Handles throttling (429 responses) by reading the Retry-After header
/// and automatically retrying the request after the specified delay.
/// 
/// All requests automatically include the Authorization header with the bearer token.
class GraphHttpClient {
  final String _accessToken;
  final int _maxRetries;
  final http.Client _httpClient;

  GraphHttpClient(this._accessToken, {int maxRetries = 3})
      : _maxRetries = maxRetries,
        _httpClient = http.Client();

  /// Dispose of the underlying HTTP client
  void dispose() {
    _httpClient.close();
  }

  /// Execute a GET request with throttling support
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return _executeWithRetry(
      () => _httpClient.get(url, headers: _buildHeaders(headers)),
      'GET',
      url.toString(),
    );
  }

  /// Execute a POST request with throttling support
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _executeWithRetry(
      () => _httpClient.post(
        url,
        headers: _buildHeaders(headers),
        body: body,
        encoding: encoding,
      ),
      'POST',
      url.toString(),
    );
  }

  /// Execute a PUT request with throttling support
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _executeWithRetry(
      () => _httpClient.put(
        url,
        headers: _buildHeaders(headers),
        body: body,
        encoding: encoding,
      ),
      'PUT',
      url.toString(),
    );
  }

  /// Execute a PATCH request with throttling support
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _executeWithRetry(
      () => _httpClient.patch(
        url,
        headers: _buildHeaders(headers),
        body: body,
        encoding: encoding,
      ),
      'PATCH',
      url.toString(),
    );
  }

  /// Execute a DELETE request with throttling support
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _executeWithRetry(
      () => _httpClient.delete(
        url,
        headers: _buildHeaders(headers),
        body: body,
        encoding: encoding,
      ),
      'DELETE',
      url.toString(),
    );
  }

  /// Execute a request with automatic retry on 429 (throttling)
  Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() request,
    String method,
    String url,
  ) async {
    int attempt = 0;

    while (attempt < _maxRetries) {
      attempt++;

      try {
        final response = await request();

        // Check for throttling (429 Too Many Requests)
        if (response.statusCode == 429) {
          if (attempt >= _maxRetries) {
            debugPrint(
              'GraphHttpClient: Max retries ($_maxRetries) reached for $method $url',
            );
            return response; // Return 429 response after max retries
          }

          // Get retry-after duration from header (in seconds)
          final retryAfterHeader = response.headers['retry-after'];
          int retryAfterSeconds = 5; // Default fallback

          if (retryAfterHeader != null) {
            retryAfterSeconds = int.tryParse(retryAfterHeader) ?? 5;
          }

          debugPrint(
            'GraphHttpClient: Throttled (429) on $method $url. '
            'Retrying in $retryAfterSeconds seconds (attempt $attempt/$_maxRetries)',
          );

          // Wait for the specified duration
          await Future.delayed(Duration(seconds: retryAfterSeconds));

          // Retry
          continue;
        }

        // Success or non-throttling error
        return response;
      } catch (e) {
        // Network error or other exception
        if (attempt >= _maxRetries) {
          debugPrint(
            'GraphHttpClient: Request failed after $attempt attempts: $e',
          );
          rethrow;
        }

        // Wait briefly before retry
        debugPrint(
          'GraphHttpClient: Request error on attempt $attempt/$_maxRetries: $e',
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // Should not reach here, but for safety
    throw Exception('GraphHttpClient: Unexpected retry loop exit');
  }

  /// Build headers with Authorization bearer token
  Map<String, String> _buildHeaders(Map<String, String>? additionalHeaders) {
    final headers = <String, String>{
      'Authorization': 'Bearer $_accessToken',
      'Content-Type': 'application/json',
    };

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }
}
