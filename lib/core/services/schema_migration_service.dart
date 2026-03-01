import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../../utils/device_configuration.dart';
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
    responses.addAll(await _checkStage2(event, metadata, store));
    responses.addAll(await _checkStage3(event, metadata, store));
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
    if (store.getBool(_s2)) return [];

    if (event != 'activity.recipe_favourite') return [];

    final refCount = metadata['ref_count'] as int? ?? 1;
    final nodeCount = metadata['node_count'] as int? ?? 1;

    if (refCount > 0 || nodeCount > 0) return [];

    final text = await IntegrityService.resolveAlertText('empty_recipe_error');
    return [
      IntegrityResponse(
        type: 'system_message',
        data: {'text': text ?? ''},
      ),
    ];
  }

  static Future<List<IntegrityResponse>> _checkStage2(
    String event,
    Map<String, dynamic> metadata,
    IntegrityStateStore store,
  ) async {
    if (store.getBool(_s2)) return [];

    if (event != 'activity.measurement_query') return [];
    if (metadata['tab'] != 'temperature') return [];

    // Soft hint path: raw input that could not be parsed as a number.
    final inputRaw = metadata['input_raw'] as String?;
    if (inputRaw != null) {
      final text = await IntegrityService.resolveAlertText('stage2_hint');
      return [
        IntegrityResponse(
          type: 'system_message',
          data: {'text': text ?? ''},
        ),
      ];
    }

    final input = metadata['input'] as double?;
    if (input == null) return [];

    if ((input - 2.2810).abs() < 0.0001) {
      await store.setBool(_s1, true);
      await store.setBool(_s2, true);

      // Generate and persist the configuration reference entry for this session.
      final partySize = await DeviceConfiguration.getNumericSeed(digits: 2);
      String deviceName = 'Guest';
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          deviceName = (await deviceInfo.androidInfo).model;
        } else if (Platform.isIOS) {
          deviceName = (await deviceInfo.iosInfo).name;
        } else if (Platform.isWindows) {
          deviceName = (await deviceInfo.windowsInfo).computerName;
        } else if (Platform.isMacOS) {
          deviceName = (await deviceInfo.macOsInfo).computerName;
        } else if (Platform.isLinux) {
          deviceName = (await deviceInfo.linuxInfo).name;
        }
      } catch (_) {
        // Platform API unavailable — retain fallback name.
      }
      final guestEntry = {
        'time': '8:02',
        'party_size': partySize,
        'name': deviceName,
        'contact': '',
        'table_no': 17,
        'notes': '',
      };
      await store.setString('schema_guest_ref', jsonEncode(guestEntry));

      final text = await IntegrityService.resolveAlertText('stage2_clue');
      return [
        IntegrityResponse(
          type: 'system_message',
          data: {'text': text ?? ''},
        ),
      ];
    }

    return [];
  }

  static Future<List<IntegrityResponse>> _checkStage3(
    String event,
    Map<String, dynamic> metadata,
    IntegrityStateStore store,
  ) async {
    if (store.getBool(_s3)) return [];
    if (event != 'activity.reference_viewed') return [];
    if (metadata['ref'] != 'reservations') return [];
    await store.setBool(_s3, true);
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
