import 'package:flutter/foundation.dart';

import '../models/cellar_knowledge_payload.dart';
import '../models/cheese_knowledge_payload.dart';
import '../models/knowledge_payload.dart';
import '../models/modernist_knowledge_payload.dart';
import '../models/pizza_knowledge_payload.dart';
import '../models/sandwich_knowledge_payload.dart';
import '../models/smoking_knowledge_payload.dart';

/// Strategy interface for transmitting RAG knowledge payloads to a destination.
///
/// Swap implementations to change the transmission target without touching
/// [RagTelemetryService]. For example, replace [ConsoleTransmissionClient]
/// with a Supabase edge-function client or a REST client when a backend is ready.
abstract class RagTransmissionClient {
  const RagTransmissionClient();

  /// Transmits a standard [KnowledgePayload] (Recipe domains).
  Future<void> transmit(KnowledgePayload payload);

  /// Transmits a [ModernistKnowledgePayload].
  Future<void> transmitModernist(ModernistKnowledgePayload payload);

  /// Transmits a [SmokingKnowledgePayload].
  Future<void> transmitSmoking(SmokingKnowledgePayload payload);

  /// Transmits a [PizzaKnowledgePayload].
  Future<void> transmitPizza(PizzaKnowledgePayload payload);

  /// Transmits a [SandwichKnowledgePayload].
  Future<void> transmitSandwich(SandwichKnowledgePayload payload);

  /// Transmits a [CellarKnowledgePayload].
  Future<void> transmitCellar(CellarKnowledgePayload payload);

  /// Transmits a [CheeseKnowledgePayload].
  Future<void> transmitCheese(CheeseKnowledgePayload payload);
}

/// Development implementation — writes the payload to the debug console.
///
/// This is the default client injected by [ragTelemetryServiceProvider].
/// Replace it with a network client when a backend is available; no other
/// code needs to change.
class ConsoleTransmissionClient implements RagTransmissionClient {
  const ConsoleTransmissionClient();

  @override
  Future<void> transmit(KnowledgePayload payload) async {
    debugPrint('[RAG_TELEMETRY]: ${payload.toPrettyJson()}');
  }

  @override
  Future<void> transmitModernist(ModernistKnowledgePayload payload) async {
    debugPrint('[RAG_TELEMETRY_MODERNIST]: ${payload.toPrettyJson()}');
  }

  @override
  Future<void> transmitSmoking(SmokingKnowledgePayload payload) async {
    debugPrint('[RAG_TELEMETRY_SMOKING]: ${payload.toPrettyJson()}');
  }

  @override
  Future<void> transmitPizza(PizzaKnowledgePayload payload) async {
    debugPrint('[RAG_TELEMETRY_PIZZA]: ${payload.toPrettyJson()}');
  }

  @override
  Future<void> transmitSandwich(SandwichKnowledgePayload payload) async {
    debugPrint('[RAG_TELEMETRY_SANDWICH]: ${payload.toPrettyJson()}');
  }

  @override
  Future<void> transmitCellar(CellarKnowledgePayload payload) async {
    debugPrint('[RAG_TELEMETRY_CELLAR]: ${payload.toPrettyJson()}');
  }

  @override
  Future<void> transmitCheese(CheeseKnowledgePayload payload) async {
    debugPrint('[RAG_TELEMETRY_CHEESE]: ${payload.toPrettyJson()}');
  }
}

