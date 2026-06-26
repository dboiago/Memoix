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
  const SupabaseTransmissionClient();

  /// Returns the Supabase client only when Supabase is fully initialised.
  /// Returns null if called before [Supabase.initialize] has completed.
  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<SupabaseClient?> _awaitClient({
    int retries = 3,
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    for (var i = 0; i < retries; i++) {
      final client = _supabaseClient;
      if (client != null) return client;
      if (i < retries - 1) await Future<void>.delayed(delay);
    }
    return null;
  }

  @override
  Future<void> transmit(KnowledgePayload payload) async {
    final client = await _awaitClient();
    if (client == null) return;
    try {
      final insertedRows = await client
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'recipe',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': _enrichRecipePayload(payload),
          })
          .select();
      debugPrint(
        '[SupabaseTransmissionClient] transmit insert returned rows: '
        '$insertedRows',
      );
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
    final client = _supabaseClient;
    if (client == null) return;
    try {
      await client
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'modernist',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': _enrichModernistPayload(payload),
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
    final client = _supabaseClient;
    if (client == null) return;
    try {
      await client
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
    final client = _supabaseClient;
    if (client == null) return;
    try {
      await client
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'pizza',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': _enrichPizzaPayload(payload),
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
    final client = _supabaseClient;
    if (client == null) return;
    try {
      await client
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'sandwich',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': _enrichSandwichPayload(payload),
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
    final client = _supabaseClient;
    if (client == null) return;
    try {
      await client
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'cellar',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': _enrichCellarPayload(payload),
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
    final client = _supabaseClient;
    if (client == null) return;
    try {
      await client
          .schema('memoix')
          .from('rag_telemetry')
          .insert({
            'domain_type': 'cheese',
            'schema_version': 2,
            'lineage_hash': payload.lineageHash,
            'content_hash': payload.contentHash,
            'payload': _enrichCheesePayload(payload),
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
    final client = await _awaitClient();
    if (client == null) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'recipe',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': _enrichRecipePayload(p),
              })
          .toList();
      await client
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
    final client = await _awaitClient();
    if (client == null) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'modernist',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': _enrichModernistPayload(p),
              })
          .toList();
      await client
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
    final client = await _awaitClient();
    if (client == null) return;
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
      await client
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
    final client = await _awaitClient();
    if (client == null) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'pizza',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': _enrichPizzaPayload(p),
              })
          .toList();
      await client
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
    final client = _supabaseClient;
    if (client == null) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'sandwich',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': _enrichSandwichPayload(p),
              })
          .toList();
      await client
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
    final client = _supabaseClient;
    if (client == null) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'cellar',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': _enrichCellarPayload(p),
              })
          .toList();
      await client
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
    final client = _supabaseClient;
    if (client == null) return;
    try {
      final rows = payloads
          .map((p) => {
                'domain_type': 'cheese',
                'schema_version': 2,
                'lineage_hash': p.lineageHash,
                'content_hash': p.contentHash,
                'payload': _enrichCheesePayload(p),
              })
          .toList();
      await client
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

  // ─────────────────────────────────────────────────────────────────────────
  // Payload enrichment helpers
  //
  // Each helper calls the payload’s own toJson() (preserving all existing
  // serialisation) then injects fields that are present on the local model
  // but absent from the payload’s toJson() implementation.
  // Null / empty values are included explicitly so the telemetry row always
  // carries the fullest possible snapshot of the record.
  // ─────────────────────────────────────────────────────────────────────────

  /// Adds [subcategory], [continent], [country], [sourceUrl], [editCount],
  /// [version] to the recipe object, and [alternative] + [bakerPercent] to
  /// every ingredient entry.
  Map<String, dynamic> _enrichRecipePayload(KnowledgePayload p) {
    final json = p.toJson();
    final recipe = json['recipe'] as Map<String, dynamic>;
    recipe['region'] = p.recipe.subcategory;
    recipe['continent'] = p.recipe.continent;
    recipe['country'] = p.recipe.country;
    recipe['sourceUrl'] = p.recipe.sourceUrl;
    recipe['editCount'] = p.recipe.editCount;
    recipe['version'] = p.recipe.version;
    final ingredients = (recipe['ingredients'] as List<dynamic>)
        .asMap()
        .entries
        .map((e) {
          final m =
              Map<String, dynamic>.from(e.value as Map<String, dynamic>);
          final ing = p.recipe.ingredients[e.key];
          m['alternative'] = ing.alternative;
          m['bakerPercent'] = ing.bakerPercent;
          return m;
        })
        .toList();
    recipe['ingredients'] = ingredients;
    return json;
  }

  /// Adds [sourceUrl] to the modernist recipe object.
  Map<String, dynamic> _enrichModernistPayload(ModernistKnowledgePayload p) {
    final json = p.toJson();
    (json['recipe'] as Map<String, dynamic>)['sourceUrl'] = p.recipe.sourceUrl;
    return json;
  }

  /// Adds [version] to the pizza recipe object.
  Map<String, dynamic> _enrichPizzaPayload(PizzaKnowledgePayload p) {
    final json = p.toJson();
    (json['recipe'] as Map<String, dynamic>)['version'] = p.pizza.version;
    return json;
  }

  /// Adds [version] to the sandwich recipe object.
  Map<String, dynamic> _enrichSandwichPayload(SandwichKnowledgePayload p) {
    final json = p.toJson();
    (json['recipe'] as Map<String, dynamic>)['version'] = p.sandwich.version;
    return json;
  }

  /// Adds [version] to the cellar entry object.
  Map<String, dynamic> _enrichCellarPayload(CellarKnowledgePayload p) {
    final json = p.toJson();
    (json['entry'] as Map<String, dynamic>)['version'] = p.entry.version;
    return json;
  }

  /// Adds [version] to the cheese entry object.
  Map<String, dynamic> _enrichCheesePayload(CheeseKnowledgePayload p) {
    final json = p.toJson();
    (json['entry'] as Map<String, dynamic>)['version'] = p.entry.version;
    return json;
  }
}

