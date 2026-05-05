import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/knowledge_payload.dart';
import 'rag_transmission_client.dart';

/// Supabase implementation of [RagTransmissionClient].
///
/// Scaffolded but inactive — the insert is commented out until the
/// `rag_telemetry` table exists in Supabase. Swap this into
/// [ragTelemetryServiceProvider] to activate.
class SupabaseTransmissionClient implements RagTransmissionClient {
  const SupabaseTransmissionClient(this._supabaseClient);

  final SupabaseClient _supabaseClient;

  @override
  Future<void> transmit(KnowledgePayload payload) async {
    // TODO: Uncomment when 'rag_telemetry' table is created in Supabase
    // await _supabaseClient
    //     .from('rag_telemetry')
    //     .insert(payload.toJson());

    debugPrint('[SUPABASE_CLIENT_SCAFFOLD]: Would have inserted recipe ${payload.recipe.id} to Supabase.');
  }
}
