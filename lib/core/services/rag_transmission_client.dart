import 'package:flutter/foundation.dart';

import '../models/knowledge_payload.dart';

/// Strategy interface for transmitting a [KnowledgePayload] to a destination.
///
/// Swap implementations to change the transmission target without touching
/// [RagTelemetryService]. For example, replace [ConsoleTransmissionClient]
/// with a Supabase edge-function client or a REST client when a backend is ready.
abstract class RagTransmissionClient {
  const RagTransmissionClient();

  /// Transmits [payload] to the configured destination.
  Future<void> transmit(KnowledgePayload payload);
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
}
