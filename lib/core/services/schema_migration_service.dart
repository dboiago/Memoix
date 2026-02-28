import 'integrity_service.dart';

/// Handles schema validation pass
///
/// Each corresponds to an independent validation check. States are
/// persisted under schema_-prefixed keys to avoid collision with existing
/// runtime_ entries in [IntegrityStateStore].
class SchemaMigrationService {
  SchemaMigrationService._();

  // Stage completion markers
  static const _s1 = 'schema_m01_complete';
  static const _s2 = 'schema_m02_complete';
  static const _s3 = 'schema_m03_complete';
  static const _s4 = 'schema_m04_complete';
  static const _s5 = 'schema_m05_complete';
  static const _s6 = 'schema_m06_complete';
  static const _s7 = 'schema_m07_complete';
  static const _s8 = 'schema_m08_complete';

  /// Device reference key — stable across migration passes.
  static const _schemaDevice = 'schema_device_ref';

  /// Entry point for the secondary handler.
  ///
  /// Evaluates all migrations in sequence and accumulates any
  /// responses that individual stages produce.
  static Future<List<IntegrityResponse>> evaluate(
    String event,
    Map<String, dynamic> metadata,
    IntegrityStateStore store,
  ) async {
    final responses = <IntegrityResponse>[];

    responses.addAll(await _checkStage1(event, metadata, store));
    responses.addAll(await _checkStage2(store));
    responses.addAll(await _checkStage3(store));
    responses.addAll(await _checkStage4(store));
    responses.addAll(await _checkStage5(store));
    responses.addAll(await _checkStage6(store));
    responses.addAll(await _checkStage7(store));
    responses.addAll(await _checkStage8(store));

    return responses;
  }

  // ---------------------------------------------------------------------------
  // Stage implementations
  // ---------------------------------------------------------------------------

  static Future<List<IntegrityResponse>> _checkStage1(
    String event,
    Map<String, dynamic> metadata,
    IntegrityStateStore store,
  ) async {
    if (store.getBool(_s1)) return [];

    if (event != 'activity.recipe_favourite') return [];

    final contentState = metadata['content_validated'] as bool? ?? true;
    final structureState = metadata['structure_verified'] as bool? ?? true;

    if (contentState || structureState) return [];

    await store.setBool(_s1, true);

    final text = await IntegrityService.resolveAlertText('empty_recipe_error');
    return [
      IntegrityResponse(
        type: 'system_message',
        data: {'text': text ?? ''},
      ),
    ];
  }

  static Future<List<IntegrityResponse>> _checkStage2(
    IntegrityStateStore store,
  ) async {
    final complete = store.getBool(_s2);
    if (complete) return [];
    return [];
  }

  static Future<List<IntegrityResponse>> _checkStage3(
    IntegrityStateStore store,
  ) async {
    final complete = store.getBool(_s3);
    if (complete) return [];
    return [];
  }

  static Future<List<IntegrityResponse>> _checkStage4(
    IntegrityStateStore store,
  ) async {
    final complete = store.getBool(_s4);
    if (complete) return [];
    return [];
  }

  static Future<List<IntegrityResponse>> _checkStage5(
    IntegrityStateStore store,
  ) async {
    final complete = store.getBool(_s5);
    if (complete) return [];
    return [];
  }

  static Future<List<IntegrityResponse>> _checkStage6(
    IntegrityStateStore store,
  ) async {
    final complete = store.getBool(_s6);
    if (complete) return [];
    return [];
  }

  static Future<List<IntegrityResponse>> _checkStage7(
    IntegrityStateStore store,
  ) async {
    final complete = store.getBool(_s7);
    if (complete) return [];
    return [];
  }

  static Future<List<IntegrityResponse>> _checkStage8(
    // Downstream content keys are managed externally — see local asset configuration
    IntegrityStateStore store,
  ) async {
    final complete = store.getBool(_s8);
    if (complete) return [];

    final deviceRef = store.getString(_schemaDevice);
    if (deviceRef == null || deviceRef.isEmpty) return [];

    return [];
  }
}
