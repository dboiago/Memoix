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

  /// Queries the `search_walkin_sql_filter` RPC using structured SQL filters
  /// rather than a vector embedding. Suitable when no BYOK AI key is active.
  Future<List<RagQueryResult>> sqlFilter({
    String? query,
    String? cuisine,
    String? region,
    String? course,
    String? ingredient,
    int? maxTimeMinutes,
    bool wantsUntried = false,
    int limit = 20,
  });

  /// Queries the `search_walkin_sql_discover` RPC for a curated selection
  /// of community recipes with no query or filter parameters.
  Future<List<RagQueryResult>> sqlDiscover({int limit = 20});
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

  @override
  Future<List<RagQueryResult>> sqlFilter({
    String? query,
    String? cuisine,
    String? region,
    String? course,
    String? ingredient,
    int? maxTimeMinutes,
    bool wantsUntried = false,
    int limit = 20,
  }) async {
    return const [];
  }

  @override
  Future<List<RagQueryResult>> sqlDiscover({int limit = 20}) async {
    return const [];
  }
}
