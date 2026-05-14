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

  // ──────────────────────────────────────────────────────────────────────────
  // Batch methods — used by backfillOnOptIn() only.
  // ──────────────────────────────────────────────────────────────────────────

  /// Transmits a batch of [KnowledgePayload]s in a single request.
  Future<void> transmitBatch(List<KnowledgePayload> payloads);

  /// Transmits a batch of [ModernistKnowledgePayload]s in a single request.
  Future<void> transmitModernistBatch(List<ModernistKnowledgePayload> payloads);

  /// Transmits a batch of [SmokingKnowledgePayload]s in a single request.
  Future<void> transmitSmokingBatch(List<SmokingKnowledgePayload> payloads);

  /// Transmits a batch of [PizzaKnowledgePayload]s in a single request.
  Future<void> transmitPizzaBatch(List<PizzaKnowledgePayload> payloads);

  /// Transmits a batch of [SandwichKnowledgePayload]s in a single request.
  Future<void> transmitSandwichBatch(List<SandwichKnowledgePayload> payloads);

  /// Transmits a batch of [CellarKnowledgePayload]s in a single request.
  Future<void> transmitCellarBatch(List<CellarKnowledgePayload> payloads);

  /// Transmits a batch of [CheeseKnowledgePayload]s in a single request.
  Future<void> transmitCheeseBatch(List<CheeseKnowledgePayload> payloads);
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

  @override
  Future<void> transmitBatch(List<KnowledgePayload> payloads) async {
    debugPrint('[RAG_TELEMETRY_BATCH]: ${payloads.length} recipe payload(s)');
  }

  @override
  Future<void> transmitModernistBatch(
      List<ModernistKnowledgePayload> payloads) async {
    debugPrint(
        '[RAG_TELEMETRY_MODERNIST_BATCH]: ${payloads.length} modernist payload(s)');
  }

  @override
  Future<void> transmitSmokingBatch(
      List<SmokingKnowledgePayload> payloads) async {
    debugPrint(
        '[RAG_TELEMETRY_SMOKING_BATCH]: ${payloads.length} smoking payload(s)');
  }

  @override
  Future<void> transmitPizzaBatch(
      List<PizzaKnowledgePayload> payloads) async {
    debugPrint(
        '[RAG_TELEMETRY_PIZZA_BATCH]: ${payloads.length} pizza payload(s)');
  }

  @override
  Future<void> transmitSandwichBatch(
      List<SandwichKnowledgePayload> payloads) async {
    debugPrint(
        '[RAG_TELEMETRY_SANDWICH_BATCH]: ${payloads.length} sandwich payload(s)');
  }

  @override
  Future<void> transmitCellarBatch(
      List<CellarKnowledgePayload> payloads) async {
    debugPrint(
        '[RAG_TELEMETRY_CELLAR_BATCH]: ${payloads.length} cellar payload(s)');
  }

  @override
  Future<void> transmitCheeseBatch(
      List<CheeseKnowledgePayload> payloads) async {
    debugPrint(
        '[RAG_TELEMETRY_CHEESE_BATCH]: ${payloads.length} cheese payload(s)');
  }
}

