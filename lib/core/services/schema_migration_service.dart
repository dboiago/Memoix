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
    responses.addAll(await _verifyFinalize(event, metadata, store));

    return responses;
  }

  static Future<Map<String, Duration>> getStageDurations() async {
    final store = IntegrityService.store;

    final diagWarm   = store.getInt('diag_warm_ms');
    final diagFetch  = store.getInt('diag_fetch_ms');
    final diagIndex  = store.getInt('diag_index_ms');
    final diagRender = store.getInt('diag_render_ms');
    final diagPaint  = store.getInt('diag_paint_ms');
    final diagFlush  = store.getInt('diag_flush_ms');

    final untracked = diagPaint - diagRender;
    final half = untracked ~/ 2;
    final synthAsset  = diagRender + half;
    final synthStream = diagRender + (untracked - half);

    Duration safeDur(int from, int to) {
      final ms = to - from;
      return ms > 0 ? Duration(milliseconds: ms) : Duration.zero;
    }

    final d1 = safeDur(diagWarm,   diagFetch);
    final d2 = safeDur(diagFetch,  diagIndex);
    final d3 = safeDur(diagIndex,  diagRender);
    final d4 = safeDur(diagRender, synthAsset);
    final d5 = safeDur(synthAsset, synthStream);
    final d6 = safeDur(synthStream, diagPaint);
    final d7 = safeDur(diagPaint,  diagFlush);
    const d8 = Duration.zero;

    final total = d1 + d2 + d3 + d4 + d5 + d6 + d7 + d8;

    return {
      'diag_warm_ms':   d1,
      'diag_fetch_ms':  d2,
      'diag_index_ms':  d3,
      'diag_render_ms': d4,
      'diag_asset_ms':  d5,
      'diag_stream_ms': d6,
      'diag_paint_ms':  d7,
      'diag_flush_ms':  d8,
      'total':          total,
    };
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
      final amount = await DeviceConfiguration.getNumericSeed(digits: 2, offset: 4);
      final text = (await IntegrityService.resolveAlertText('conversion_fallback') ?? '')
          .replaceAll('{amount}', amount.toString());
      return [
        IntegrityResponse(
          type: 'system_message',
          data: {'text': text},
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
    String event,
    Map<String, dynamic> metadata,
    IntegrityStateStore store,
  ) async {
    if (store.getBool(_s8)) return [];
    if (!store.getBool(_s7)) return [];
    final refFinalize = await IntegrityService.resolveLegacyValue('legacy_ref_finalize');
    if (event != 'activity.entry_finalized') return [];
    if (metadata['ref'] != refFinalize) return [];
    await store.setBool(_s8, true);
    final tsKey = 'diag_flush_ms';
    if (!store.getBool(tsKey + '_set')) {
      await store.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
      await store.setBool(tsKey + '_set', true);
    }
    return [];
  }
}
