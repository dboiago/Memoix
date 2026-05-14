import 'package:flutter/foundation.dart';
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
    try {
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'recipe',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': payload.toJson(),
          });
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmit PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint('[SupabaseTransmissionClient] transmit error — $e');
    }
  }

  @override
  Future<void> transmitModernist(ModernistKnowledgePayload payload) async {
    try {
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'modernist',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': payload.toJson(),
          });
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitModernist PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint('[SupabaseTransmissionClient] transmitModernist error — $e');
    }
  }

  @override
  Future<void> transmitSmoking(SmokingKnowledgePayload payload) async {
    try {
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'smoking',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': payload.toJson(),
          });
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitSmoking PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint('[SupabaseTransmissionClient] transmitSmoking error — $e');
    }
  }

  @override
  Future<void> transmitPizza(PizzaKnowledgePayload payload) async {
    try {
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'pizza',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': payload.toJson(),
          });
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitPizza PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint('[SupabaseTransmissionClient] transmitPizza error — $e');
    }
  }

  @override
  Future<void> transmitSandwich(SandwichKnowledgePayload payload) async {
    try {
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'sandwich',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': payload.toJson(),
          });
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitSandwich PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint('[SupabaseTransmissionClient] transmitSandwich error — $e');
    }
  }

  @override
  Future<void> transmitCellar(CellarKnowledgePayload payload) async {
    try {
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'cellar',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': payload.toJson(),
          });
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitCellar PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint('[SupabaseTransmissionClient] transmitCellar error — $e');
    }
  }

  @override
  Future<void> transmitCheese(CheeseKnowledgePayload payload) async {
    try {
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'cheese',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': payload.toJson(),
          });
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitCheese PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint('[SupabaseTransmissionClient] transmitCheese error — $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Batch methods — one POST per chunk of 25 rows, used by backfillOnOptIn().
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Future<void> transmitBatch(List<KnowledgePayload> payloads) async {
    if (payloads.isEmpty) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'recipe',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': p.toJson(),
              })
          .toList();
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert(rows);
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitBatch PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint('[SupabaseTransmissionClient] transmitBatch error — $e');
    }
  }

  @override
  Future<void> transmitModernistBatch(
      List<ModernistKnowledgePayload> payloads) async {
    if (payloads.isEmpty) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'modernist',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': p.toJson(),
              })
          .toList();
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert(rows);
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitModernistBatch PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint(
          '[SupabaseTransmissionClient] transmitModernistBatch error — $e');
    }
  }

  @override
  Future<void> transmitSmokingBatch(
      List<SmokingKnowledgePayload> payloads) async {
    if (payloads.isEmpty) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'smoking',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': p.toJson(),
              })
          .toList();
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert(rows);
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitSmokingBatch PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint(
          '[SupabaseTransmissionClient] transmitSmokingBatch error — $e');
    }
  }

  @override
  Future<void> transmitPizzaBatch(
      List<PizzaKnowledgePayload> payloads) async {
    if (payloads.isEmpty) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'pizza',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': p.toJson(),
              })
          .toList();
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert(rows);
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitPizzaBatch PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint('[SupabaseTransmissionClient] transmitPizzaBatch error — $e');
    }
  }

  @override
  Future<void> transmitSandwichBatch(
      List<SandwichKnowledgePayload> payloads) async {
    if (payloads.isEmpty) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'sandwich',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': p.toJson(),
              })
          .toList();
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert(rows);
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitSandwichBatch PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint(
          '[SupabaseTransmissionClient] transmitSandwichBatch error — $e');
    }
  }

  @override
  Future<void> transmitCellarBatch(
      List<CellarKnowledgePayload> payloads) async {
    if (payloads.isEmpty) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'cellar',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': p.toJson(),
              })
          .toList();
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert(rows);
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitCellarBatch PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint(
          '[SupabaseTransmissionClient] transmitCellarBatch error — $e');
    }
  }

  @override
  Future<void> transmitCheeseBatch(
      List<CheeseKnowledgePayload> payloads) async {
    if (payloads.isEmpty) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'cheese',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': p.toJson(),
              })
          .toList();
      await _supabaseClient
          .schema('memoix')
          .from('rag_telemetry')
          .insert(rows);
    } on PostgrestException catch (e) {
      debugPrint(
        '[SupabaseTransmissionClient] transmitCheeseBatch PostgrestException — '
        'message: ${e.message}, code: ${e.code}, details: ${e.details}',
      );
    } catch (e) {
      debugPrint(
          '[SupabaseTransmissionClient] transmitCheeseBatch error — $e');
    }
  }
}

