import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../clients/rag_retrieval_client.dart';
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
  Future<List<RagQueryResult>> query(String query, {int limit = 10}) {
    return _client.query(query, limit: limit);
  }
}

/// Provider for [RagRetrievalService].
///
/// Wired to [StubRetrievalClient] until a live retrieval backend is available.
final ragRetrievalServiceProvider = Provider<RagRetrievalService>((ref) {
  return RagRetrievalService(const StubRetrievalClient());
});
