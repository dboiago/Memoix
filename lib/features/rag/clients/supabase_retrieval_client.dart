import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rag_query_result.dart';
import 'rag_retrieval_client.dart';

/// Live retrieval client backed by a Supabase vector store.
///
/// Step 1: POSTs [query] text to [embedEndpointUrl] to obtain a 1024-dimensional
/// embedding vector.
/// Step 2: Calls the `search_walkin_recipes` Supabase RPC with the embedding
/// and optional [cuisine]/[course] filters.
/// Step 3: Maps the response rows to [RagQueryResult] via [RagQueryResult.fromJson].
///
/// Register this in [ragRetrievalServiceProvider] once the backend is live.
/// Until then the provider continues to use [StubRetrievalClient].
class SupabaseRetrievalClient implements RagRetrievalClient {
  final SupabaseClient _supabaseClient;
  final String _embedEndpointUrl;
  final String _workerSecret;

  /// SECURITY: Maximum accepted HTTP response body — 10 MB.
  static const int _maxResponseBytes = 10 * 1024 * 1024;

  /// SECURITY: Hard timeout for the embed endpoint POST.
  static const Duration _timeout = Duration(seconds: 10);

  /// Minimum cosine similarity score for a result to be returned.
  /// Adjust during testing to tune recall vs. precision.
  static const double _minSimilarity = 0.45;

  /// Content types that must be rejected before reading the response body.
  static const List<String> _blockedContentTypePrefixes = [
    'application/pdf',
    'application/zip',
    'application/octet-stream',
    'image/',
    'video/',
    'audio/',
  ];

  const SupabaseRetrievalClient(
    this._supabaseClient,
    this._embedEndpointUrl,
    this._workerSecret,
  );

  @override
  Future<List<RagQueryResult>> query(
    String query, {
    int limit = 10,
    String? cuisine,
    String? course,
  }) async {
    final embedding = await _fetchEmbedding(query);
    return _searchSupabase(
      embedding: embedding,
      limit: limit,
      cuisine: cuisine,
      course: course,
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Embed endpoint
  // ---------------------------------------------------------------------------

  /// POSTs [text] to [_embedEndpointUrl] and returns a 1024-dimensional vector.
  ///
  /// Throws an [Exception] if the request fails, times out, or the response
  /// is malformed.
  Future<List<double>> _fetchEmbedding(String text) async {
    // SECURITY: Validate URL scheme — only http/https allowed.
    final uri = Uri.parse(_embedEndpointUrl);
    if (!uri.isScheme('https') && !uri.isScheme('http')) {
      throw Exception(
        'Invalid embed endpoint scheme: "${uri.scheme}". '
        'Only https:// and http:// are permitted.',
      );
    }

    final client = http.Client();
    try {
      final request = http.Request('POST', uri)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $_workerSecret'
        ..body = jsonEncode({'text': text});

      final http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await client.send(request).timeout(_timeout);
      } on TimeoutException {
        throw Exception(
          'Embed endpoint timed out after ${_timeout.inSeconds} s '
          '(url: $_embedEndpointUrl).',
        );
      }

      // SECURITY: Fast-fail when Content-Length exceeds the 10 MB limit.
      final contentLength = streamedResponse.contentLength;
      if (contentLength != null && contentLength > _maxResponseBytes) {
        await streamedResponse.stream.drain<void>();
        throw Exception(
          'Embed endpoint response too large: '
          '${(contentLength / 1024 / 1024).toStringAsFixed(1)} MB. '
          'Maximum allowed: ${(_maxResponseBytes / 1024 / 1024).toStringAsFixed(0)} MB.',
        );
      }

      // SECURITY: Reject binary content types immediately without reading body.
      final contentType =
          streamedResponse.headers['content-type']?.toLowerCase();
      if (contentType != null) {
        for (final blocked in _blockedContentTypePrefixes) {
          if (contentType.contains(blocked)) {
            await streamedResponse.stream.drain<void>();
            throw Exception(
              'Unexpected content type from embed endpoint: "$contentType". '
              'Expected application/json.',
            );
          }
        }
      }

      // SECURITY: Stream the body with a running byte count as a safety net
      // for chunked responses that omit a Content-Length header.
      final chunks = <List<int>>[];
      int bytesRead = 0;
      await for (final chunk in streamedResponse.stream) {
        bytesRead += chunk.length;
        if (bytesRead > _maxResponseBytes) {
          throw Exception(
            'Embed endpoint response exceeded the '
            '${(_maxResponseBytes / 1024 / 1024).toStringAsFixed(0)} MB '
            'streaming limit. Download cancelled.',
          );
        }
        chunks.add(chunk);
      }

      if (streamedResponse.statusCode != 200) {
        final body = utf8.decode(
          chunks.expand((c) => c).toList(),
          allowMalformed: true,
        );
        throw Exception(
          'Embed endpoint returned HTTP ${streamedResponse.statusCode}: $body',
        );
      }

      final bodyString = utf8.decode(chunks.expand((c) => c).toList());

      final dynamic decoded;
      try {
        decoded = jsonDecode(bodyString);
      } catch (_) {
        throw Exception(
          'Embed endpoint returned a non-JSON body. '
          'Check that $_embedEndpointUrl is reachable and configured correctly.',
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Embed endpoint response is not a JSON object. '
          'Got: ${decoded.runtimeType}',
        );
      }

      final rawEmbedding = decoded['embedding'];
      if (rawEmbedding is! List) {
        throw Exception(
          'Embed endpoint response is missing the "embedding" key or it is not a list. '
          'Keys present: ${decoded.keys.toList()}',
        );
      }

      if (rawEmbedding.length != 1024) {
        throw Exception(
          'Expected embedding of length 1024, '
          'got ${rawEmbedding.length}.',
        );
      }

      return rawEmbedding.map<double>((e) => (e as num).toDouble()).toList();
    } finally {
      client.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Steps 2 & 3 — Supabase RPC + result mapping
  // ---------------------------------------------------------------------------

  /// Calls the `search_walkin_recipes` RPC and maps rows to [RagQueryResult].
  Future<List<RagQueryResult>> _searchSupabase({
    required List<double> embedding,
    required int limit,
    String? cuisine,
    String? course,
  }) async {
    final params = <String, dynamic>{
      'query_embedding': embedding,
      'match_count': limit,
      'min_similarity': _minSimilarity,
      if (cuisine != null) 'filter_cuisine': cuisine,
      if (course != null) 'filter_course': course,
    };

    final dynamic result = await _supabaseClient.rpc(
      'search_walkin_recipes',
      params: params,
    );

    final rows = result as List<dynamic>;
    return rows
        .map((row) => RagQueryResult.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<RagQueryResult>> sqlFilter({
    String? query,
    List<String>? cuisine,
    String? region,
    String? course,
    String? ingredient,
    int? maxTimeMinutes,
    bool wantsUntried = false,
    int limit = 20,
    List<String>? preferredCourses,
    bool prefersLongProject = false,
    String? excludeCuisine,
  }) async {
    final params = <String, dynamic>{
      'p_match_count': limit,
      if (query != null) 'p_query': query,
      if (cuisine != null && cuisine.isNotEmpty) 'p_cuisine': cuisine,
      if (region != null) 'p_region': region,
      if (course != null) 'p_course': course,
      if (ingredient != null) 'p_ingredient': ingredient,
      if (maxTimeMinutes != null) 'p_max_time_minutes': maxTimeMinutes,
      if (wantsUntried) 'p_wants_untried': true,
      if (preferredCourses != null && preferredCourses.isNotEmpty)
        'p_preferred_courses': preferredCourses,
      if (prefersLongProject) 'p_prefers_long_project': true,
      if (excludeCuisine != null) 'p_exclude_cuisine': excludeCuisine,
    };

    final dynamic result = await _supabaseClient.rpc(
      'search_walkin_sql_filter',
      params: params,
    );

    final rows = result as List<dynamic>;
    return rows
        .map((row) => RagQueryResult.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<RagQueryResult>> sqlDiscover({int limit = 20}) async {
    final params = <String, dynamic>{
      'p_match_count': limit,
    };

    final dynamic result = await _supabaseClient.rpc(
      'search_walkin_sql_discover',
      params: params,
    );

    final rows = result as List<dynamic>;
    return rows
        .map((row) => RagQueryResult.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
