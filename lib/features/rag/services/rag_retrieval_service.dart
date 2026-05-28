import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../clients/rag_retrieval_client.dart';
import '../clients/supabase_retrieval_client.dart';
import '../models/rag_query_result.dart';

/// Exposes semantic recipe retrieval to the rest of the application.
///
/// Delegates all I/O to the injected [RagRetrievalClient], keeping business
/// logic and transport concerns separate.
class RagRetrievalService {
  final RagRetrievalClient _client;

  RagRetrievalService(this._client);

  /// Returns the [limit] most semantically relevant results for [query],
  /// ranked by similarity score descending.
  Future<List<RagQueryResult>> query(
    String query, {
    int limit = 10,
    String? cuisine,
    String? course,
  }) {
    return _client.query(query, limit: limit, cuisine: cuisine, course: course);
  }

  /// Queries the Walk-in corpus using SQL filters, with no vector embedding
  /// required. Suitable when no BYOK AI key is active.
  Future<List<RagQueryResult>> sqlFilter({
    String? query,
    String? cuisine,
    String? region,
    String? course,
    String? ingredient,
    int? maxTimeMinutes,
    bool wantsUntried = false,
    int limit = 20,
    List<String>? preferredCourses,
    bool prefersLongProject = false,
    String? excludeCuisine,
  }) {
    return _client.sqlFilter(
      query: query,
      cuisine: cuisine,
      region: region,
      course: course,
      ingredient: ingredient,
      maxTimeMinutes: maxTimeMinutes,
      wantsUntried: wantsUntried,
      limit: limit,
      preferredCourses: preferredCourses,
      prefersLongProject: prefersLongProject,
      excludeCuisine: excludeCuisine,
    );
  }

  /// Queries the Walk-in corpus for a curated discovery set with no filters.
  Future<List<RagQueryResult>> sqlDiscover({int limit = 20}) {
    return _client.sqlDiscover(limit: limit);
  }
}

/// Availability gate for Memoix-powered features.
///
/// Returns false until the live backend is ready.
final memoixAvailableProvider = Provider<bool>((ref) => false);

/// Provider for [RagRetrievalService].
///
/// Uses [SupabaseRetrievalClient] when both CLOUDFLARE_WORKER_URL and
/// CLOUDFLARE_WORKER_SECRET are present in the environment; otherwise falls
/// back to [StubRetrievalClient] silently.
final ragRetrievalServiceProvider = Provider<RagRetrievalService>((ref) {
  final workerUrl = dotenv.maybeGet('CLOUDFLARE_WORKER_URL');
  final workerSecret = dotenv.maybeGet('CLOUDFLARE_WORKER_SECRET');

  if (workerUrl != null &&
      workerUrl.isNotEmpty &&
      workerSecret != null &&
      workerSecret.isNotEmpty) {
    return RagRetrievalService(
      SupabaseRetrievalClient(
        Supabase.instance.client,
        workerUrl,
        workerSecret,
      ),
    );
  }

  return RagRetrievalService(const StubRetrievalClient());
});
