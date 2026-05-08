import '../models/rag_query_result.dart';

/// Strategy interface for querying the RAG vector store.
///
/// Swap implementations to change the retrieval backend without touching
/// [RagRetrievalService]. Replace [StubRetrievalClient] with a Supabase RPC
/// client or a REST client when a backend is ready.
abstract class RagRetrievalClient {
  const RagRetrievalClient();

  /// Queries the vector store and returns the [limit] most semantically
  /// relevant results for [query].
  Future<List<RagQueryResult>> query(String query, {int limit = 10, String? cuisine, String? course});
}

/// Inert implementation used until a live retrieval backend is wired up.
///
/// Returns an empty list immediately without any I/O.
class StubRetrievalClient implements RagRetrievalClient {
  const StubRetrievalClient();

  @override
  Future<List<RagQueryResult>> query(String query, {int limit = 10, String? cuisine, String? course}) async {
    return const [];
  }
}
