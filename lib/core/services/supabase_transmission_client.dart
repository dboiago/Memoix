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
    // TODO: Uncomment when 'rag_telemetry' table is created in Supabase
    // await _supabaseClient
    //     .from('rag_telemetry')
    //     .insert(payload.toJson());
    debugPrint('[SUPABASE_CLIENT_SCAFFOLD]: Would insert recipe ${payload.recipe.name} to Supabase.');
  }

  @override
  Future<void> transmitModernist(ModernistKnowledgePayload payload) async {
    // TODO: Uncomment when 'rag_telemetry' table is created in Supabase
    // await _supabaseClient
    //     .from('rag_telemetry')
    //     .insert(payload.toJson());
    debugPrint('[SUPABASE_CLIENT_SCAFFOLD]: Would insert modernist ${payload.recipe.name} to Supabase.');
  }

  @override
  Future<void> transmitSmoking(SmokingKnowledgePayload payload) async {
    // TODO: Uncomment when 'rag_telemetry' table is created in Supabase
    debugPrint('[SUPABASE_CLIENT_SCAFFOLD]: Would insert smoking ${payload.recipe.name} to Supabase.');
  }

  @override
  Future<void> transmitPizza(PizzaKnowledgePayload payload) async {
    // TODO: Uncomment when 'rag_telemetry' table is created in Supabase
    debugPrint('[SUPABASE_CLIENT_SCAFFOLD]: Would insert pizza ${payload.pizza.name} to Supabase.');
  }

  @override
  Future<void> transmitSandwich(SandwichKnowledgePayload payload) async {
    // TODO: Uncomment when 'rag_telemetry' table is created in Supabase
    debugPrint('[SUPABASE_CLIENT_SCAFFOLD]: Would insert sandwich ${payload.sandwich.name} to Supabase.');
  }

  @override
  Future<void> transmitCellar(CellarKnowledgePayload payload) async {
    // TODO: Uncomment when 'rag_telemetry' table is created in Supabase
    debugPrint('[SUPABASE_CLIENT_SCAFFOLD]: Would insert cellar ${payload.entry.name} to Supabase.');
  }

  @override
  Future<void> transmitCheese(CheeseKnowledgePayload payload) async {
    // TODO: Uncomment when 'rag_telemetry' table is created in Supabase
    debugPrint('[SUPABASE_CLIENT_SCAFFOLD]: Would insert cheese ${payload.entry.name} to Supabase.');
  }
}

