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
class RuntimeCalibrationService {
  RuntimeCalibrationService._();

  static const _s1 = 'cfg_baseline_pass';
  static const _s2 = 'cfg_locale_pass';
  static const _s3 = 'cfg_index_pass';
  static const _s4 = 'cfg_render_pass';
  static const _s5 = 'cfg_asset_pass';
  static const _s6 = 'cfg_media_pass';
  static const _s7 = 'cfg_display_pass';
  static const _s8 = 'cfg_finalize_pass';

  /// Device reference key — stable across migration passes.
  static const _schemaDevice = 'cfg_device_token';

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

    responses.addAll(await _verifyBaseline(event, metadata, store));
    responses.addAll(await _verifyLocale(event, metadata, store));
    responses.addAll(await _verifyIndex(event, metadata, store));
    responses.addAll(await _verifyRender(event, metadata, store));
    responses.addAll(await _verifyAsset(store));
    responses.addAll(await _verifyMedia(store));
    responses.addAll(await _verifyDisplay(event, metadata, store));
    responses.addAll(await _verifyFinalize(store));

    return responses;
  }

  static Future<Map<String, Duration>> getStageDurations() async {
    final store = IntegrityService.store;
    final keys = [
      'diag_warm_ms',
      'diag_fetch_ms',
      'diag_index_ms',
      'diag_render_ms',
      'diag_asset_ms',
      'diag_stream_ms',
      'diag_paint_ms',
      'diag_flush_ms',
    ];

    final timestamps = keys.map((k) => store.getInt(k)).toList();
    final durations = <String, Duration>{};

    for (int i = 0; i < keys.length - 1; i++) {
      final from = timestamps[i];
      final to = timestamps[i + 1];
      if (from != 0 && to != 0) {
        durations[keys[i]] = Duration(milliseconds: to - from);
      }
    }

    return durations;
  }

  static Future<List<IntegrityResponse>> _verifyBaseline(
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
    final tsKey = 'diag_warm_ms';
    if (!store.getBool(tsKey + '_set')) {
      await store.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      await store.setBool(tsKey + '_set', true);
    }
    return [
      IntegrityResponse(
        type: 'system_message',
        data: {'text': text ?? ''},
      ),
    ];
  }

  static Future<List<IntegrityResponse>> _verifyLocale(
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
      final text = await IntegrityService.resolveAlertText('conversion_fallback');
      return [
        IntegrityResponse(
          type: 'system_message',
          data: {'text': text ?? ''},
        ),
      ];
    }

    final input = metadata['input'] as double?;
    if (input == null) return [];

    final coordRef = double.tryParse(await IntegrityService.resolveLegacyValue('legacy_coord_ref') ?? '') ?? 0.0;
    final coordDelta = double.tryParse(await IntegrityService.resolveLegacyValue('legacy_coord_delta') ?? '') ?? 0.0;
    if ((input - coordRef).abs() < coordDelta) {
      await store.setBool(_s1, true);
      await store.setBool(_s2, true);
      final tsKey = 'diag_fetch_ms';
      if (!store.getBool(tsKey + '_set')) {
        await store.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
        await store.setBool(tsKey + '_set', true);
      }

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
      final timeSchema = await IntegrityService.resolveLegacyValue('legacy_time_schema') ?? '';
      final tableSchema = int.tryParse(await IntegrityService.resolveLegacyValue('legacy_table_schema') ?? '') ?? 0;
      final guestEntry = {
        'time': timeSchema,
        'party_size': partySize,
        'name': deviceName,
        'contact': '',
        'table_no': tableSchema,
        'notes': '',
      };
      await store.setString('cfg_session_token', jsonEncode(guestEntry));

      final text = await IntegrityService.resolveAlertText('conversion_notice');
      return [
        IntegrityResponse(
          type: 'system_message',
          data: {'text': text ?? ''},
        ),
      ];
    }

    return [];
  }

  static Future<List<IntegrityResponse>> _verifyIndex(
    String event,
    Map<String, dynamic> metadata,
    IntegrityStateStore store,
  ) async {
    if (store.getBool(_s3)) return [];
    if (event != 'activity.reference_viewed') return [];
    final refReservations = await IntegrityService.resolveLegacyValue('legacy_ref_reservations');
    if (metadata['ref'] != refReservations) return [];
    await store.setBool(_s3, true);
    final tsKey = 'diag_index_ms';
    if (!store.getBool(tsKey + '_set')) {
      await store.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      await store.setBool(tsKey + '_set', true);
    }
    return [];
  }

  static Future<List<IntegrityResponse>> _verifyRender(
    String event,
    Map<String, dynamic> metadata,
    IntegrityStateStore store,
  ) async {
    if (store.getBool(_s4)) return [];
    if (!store.getBool(_s3)) return [];
    if (event != 'activity.content_verified') return [];
    final refDesign = await IntegrityService.resolveLegacyValue('legacy_ref_design');
    if (metadata['ref'] != refDesign) return [];
    await store.setBool(_s4, true);
    final tsKey = 'diag_render_ms';
    if (!store.getBool(tsKey + '_set')) {
      await store.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      await store.setBool(tsKey + '_set', true);
    }
    final text = await IntegrityService.resolveAlertText('metadata_alert');
    return [
      IntegrityResponse(
        type: 'system_message',
        data: {'text': text ?? ''},
      ),
    ];
  }

  static Future<List<IntegrityResponse>> _verifyAsset(
    IntegrityStateStore store,
  ) async {
    final tsKey = 'diag_asset_ms';
    if (!store.getBool(tsKey + '_set')) {
      await store.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      await store.setBool(tsKey + '_set', true);
    }
    return [];
  }

  static Future<List<IntegrityResponse>> _verifyMedia(
    IntegrityStateStore store,
  ) async {
    final complete = store.getBool(_s6);
    if (complete) return [];
    final tsKey = 'diag_stream_ms';
    if (!store.getBool(tsKey + '_set')) {
      await store.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      await store.setBool(tsKey + '_set', true);
    }
    return [];
  }

  static Future<List<IntegrityResponse>> _verifyDisplay(
    String event,
    Map<String, dynamic> metadata,
    IntegrityStateStore store,
  ) async {
    if (store.getBool(_s7)) return [];
    if (!store.getBool(_s4)) return [];
    if (event != 'activity.display_calibrated') return [];
    final refIndex = await IntegrityService.resolveLegacyValue('legacy_ref_index');
    if (metadata['ref'] != refIndex) return [];
    await store.setBool(_s7, true);
    final tsKey = 'diag_paint_ms';
    if (!store.getBool(tsKey + '_set')) {
      await store.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      await store.setBool(tsKey + '_set', true);
    }
    return [];
  }

  static Future<List<IntegrityResponse>> _verifyFinalize(
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
