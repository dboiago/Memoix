import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cellar_knowledge_payload.dart';
import '../models/cheese_knowledge_payload.dart';
import '../models/knowledge_payload.dart';
import '../models/modernist_knowledge_payload.dart';
import '../models/pizza_knowledge_payload.dart';
import '../models/sandwich_knowledge_payload.dart';
import '../models/smoking_knowledge_payload.dart';
import 'rag_transmission_client.dart';

/// Supabase implementation of [RagTransmissionClient].
///
/// Scaffolded but inactive — inserts are commented out until the
/// `rag_telemetry` table exists in Supabase. Swap this into
/// [ragTelemetryServiceProvider] to activate.
class SupabaseTransmissionClient implements RagTransmissionClient {
  const SupabaseTransmissionClient(this._supabaseClient);

  final SupabaseClient _supabaseClient;

  @override
  Future<void> transmit(KnowledgePayload payload) async {
    await _supabaseClient
        .from('rag_telemetry')
        .insert({
          'domain_type': 'recipe',
          'schema_version': 2,
          'lineage_hash': payload.lineageHash,
          'content_hash': payload.contentHash,
          'payload': payload.toJson(),
        });
  }

  @override
  Future<void> transmitModernist(ModernistKnowledgePayload payload) async {
    await _supabaseClient
        .from('rag_telemetry')
        .insert({
          'domain_type': 'modernist',
          'schema_version': 2,
          'lineage_hash': payload.lineageHash,
          'content_hash': payload.contentHash,
          'payload': payload.toJson(),
        });
  }

  @override
  Future<void> transmitSmoking(SmokingKnowledgePayload payload) async {
    await _supabaseClient
        .from('rag_telemetry')
        .insert({
          'domain_type': 'smoking',
          'schema_version': 2,
          'lineage_hash': payload.lineageHash,
          'content_hash': payload.contentHash,
          'payload': payload.toJson(),
        });
  }

  @override
  Future<void> transmitPizza(PizzaKnowledgePayload payload) async {
    await _supabaseClient
        .from('rag_telemetry')
        .insert({
          'domain_type': 'pizza',
          'schema_version': 2,
          'lineage_hash': payload.lineageHash,
          'content_hash': payload.contentHash,
          'payload': payload.toJson(),
        });
  }

  @override
  Future<void> transmitSandwich(SandwichKnowledgePayload payload) async {
    await _supabaseClient
        .from('rag_telemetry')
        .insert({
          'domain_type': 'sandwich',
          'schema_version': 2,
          'lineage_hash': payload.lineageHash,
          'content_hash': payload.contentHash,
          'payload': payload.toJson(),
        });
  }

  @override
  Future<void> transmitCellar(CellarKnowledgePayload payload) async {
    await _supabaseClient
        .from('rag_telemetry')
        .insert({
          'domain_type': 'cellar',
          'schema_version': 2,
          'lineage_hash': payload.lineageHash,
          'content_hash': payload.contentHash,
          'payload': payload.toJson(),
        });
  }

  @override
  Future<void> transmitCheese(CheeseKnowledgePayload payload) async {
    await _supabaseClient
        .from('rag_telemetry')
        .insert({
          'domain_type': 'cheese',
          'schema_version': 2,
          'lineage_hash': payload.lineageHash,
          'content_hash': payload.contentHash,
          'payload': payload.toJson(),
        });
  }
}

