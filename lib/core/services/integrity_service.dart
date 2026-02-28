import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

import '../../app/app.dart';
import '../widgets/memoix_snackbar.dart';

// ---------------------------------------------------------------------------
// Response model
// ---------------------------------------------------------------------------

/// A queued response artifact from the integrity layer.
class IntegrityResponse {
  final String type;
  final Map<String, dynamic> data;
  final String? debug;

  IntegrityResponse({
    required this.type,
    required this.data,
    this.debug,
  });
}

// ---------------------------------------------------------------------------
// Persistent state store
// ---------------------------------------------------------------------------

/// Key-value store backed by SharedPreferences.
/// All keys are prefixed to avoid collisions with app settings.
class IntegrityStateStore {
  static const _prefix = 'runtime_';
  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // --- int ---
  int getInt(String key, {int defaultValue = 0}) =>
      _prefs?.getInt('$_prefix$key') ?? defaultValue;

  Future<void> setInt(String key, int value) async =>
      await _prefs?.setInt('$_prefix$key', value);

  // --- bool ---
  bool getBool(String key, {bool defaultValue = false}) =>
      _prefs?.getBool('$_prefix$key') ?? defaultValue;

  Future<void> setBool(String key, bool value) async =>
      await _prefs?.setBool('$_prefix$key', value);

  // --- String ---
  String? getString(String key) => _prefs?.getString('$_prefix$key');

  Future<void> setString(String key, String value) async =>
      await _prefs?.setString('$_prefix$key', value);

  // --- List<String> ---
  List<String> getStringList(String key) =>
      _prefs?.getStringList('$_prefix$key') ?? [];

  Future<void> setStringList(String key, List<String> value) async =>
      await _prefs?.setStringList('$_prefix$key', value);

  // --- Active view overrides (persisted across sessions) ---
  Map<String, Map<String, dynamic>> getActiveOverrides() {
    final json = _prefs?.getString('${_prefix}active_overrides');
    if (json == null) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map(
          (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    } catch (_) {
      return {};
    }
  }

  Future<void> persistOverride(
      String target, dynamic value, int? remainingUses) async {
    final overrides = getActiveOverrides();
    overrides[target] = {
      'value': value,
      if (remainingUses != null) 'uses': remainingUses,
    };
    await _prefs?.setString(
        '${_prefix}active_overrides', jsonEncode(overrides));
  }

  Future<void> updateOverrideUses(
      String target, int? remainingUses) async {
    final overrides = getActiveOverrides();
    if (!overrides.containsKey(target)) return;
    if (remainingUses == null || remainingUses <= 0) {
      overrides.remove(target);
    } else {
      overrides[target]!['uses'] = remainingUses;
    }
    await _prefs?.setString(
        '${_prefix}active_overrides', jsonEncode(overrides));
  }

  // --- maintenance ---
  Future<void> clear() async {
    final keys =
        _prefs?.getKeys().where((k) => k.startsWith(_prefix)).toList() ?? [];
    for (final key in keys) {
      await _prefs?.remove(key);
    }
  }
}

// ---------------------------------------------------------------------------
// Event handler type
// ---------------------------------------------------------------------------

/// Signature for the registered event handler.
///
/// Receives the event name, its metadata, and the persistent state store.
/// Returns zero or more response artifacts to be queued.
typedef IntegrityEventHandler = Future<List<IntegrityResponse>> Function(
  String event,
  Map<String, dynamic> metadata,
  IntegrityStateStore store,
);

// ---------------------------------------------------------------------------
// IntegrityService  –  static API
// ---------------------------------------------------------------------------

class IntegrityService {
  IntegrityService._();

  static bool _diagnosticsEnabled = false;
  static bool get diagnosticsEnabled => _diagnosticsEnabled;

  static final List<IntegrityResponse> _queue = [];
  static final IntegrityStateStore _store = IntegrityStateStore();
  static IntegrityEventHandler? _handler;
  static IntegrityEventHandler? _secondaryHandler;
  static bool _initialized = false;

  /// Initialise the persistent store. Call once before [runApp].
  static Future<void> initialize() async {
    await _store.initialize();
    _initialized = true;
  }

  /// Register the runtime rule handler.
  static void registerHandler(IntegrityEventHandler handler) {
    _handler = handler;
  }

  /// Register a secondary handler for downstream validation passes.
  /// Runs independently — errors do not affect primary handler execution.
  static void registerSecondaryHandler(IntegrityEventHandler handler) {
    _secondaryHandler = handler;
  }

  /// Toggle diagnostic logging (debug builds only).
  static void enableDiagnostics(bool enabled) {
    _diagnosticsEnabled = enabled;
  }

  /// Report a completed user action.
  static Future<void> reportEvent(
    String event, {
    Map<String, dynamic>? metadata,
  }) async {
    if (!_initialized) return;

    if (_diagnosticsEnabled) {
      if (metadata != null && metadata.isNotEmpty) {
      }
    }

    if (_handler != null) {
      try {
        final responses = await _handler!(event, metadata ?? {}, _store);
        _queue.addAll(responses);
      } catch (e) {
        if (_diagnosticsEnabled) {
        }
      }
    }

    if (_secondaryHandler != null) {
      try {
        final secondaryResponses =
            await _secondaryHandler!(event, metadata ?? {}, _store);
        _queue.addAll(secondaryResponses);
      } catch (e) {
        if (_diagnosticsEnabled) {
        }
      }
    }
  }

  /// Drain and return all queued response artifacts.
  static Future<List<IntegrityResponse>> getQueuedArtifacts() async {
    final items = List<IntegrityResponse>.from(_queue);
    _queue.clear();
    return items;
  }

  /// Direct access to the persistent store (for handler registration).
  static IntegrityStateStore get store => _store;

  /// Reset all persistent state and the queue (debug only).
  static Future<void> resetState() async {
    _queue.clear();
    await _store.clear();
  }

  /// Persist an active view override for cross-session restoration.
  static Future<void> persistOverride(
      String target, dynamic value, int? remainingUses) async {
    await _store.persistOverride(target, value, remainingUses);
  }

  /// Update persisted remaining uses after consumption.
  static Future<void> updatePersistedOverrideUses(
      String target, int? remainingUses) async {
    await _store.updateOverrideUses(target, remainingUses);
  }

  /// Retrieve all persisted overrides for startup hydration.
  static Map<String, Map<String, dynamic>> getPersistedOverrides() {
    return _store.getActiveOverrides();
  }

  /// Pre-queue responses generated during app bootstrap.
  static void enqueueStartupArtifacts(List<IntegrityResponse> responses) {
    _queue.addAll(responses);
  }

  /// Resolve alert text by ID from the local asset configuration.
  static Future<String?> resolveAlertText(String alertId) =>
      _ContentResolver.getAlertText(alertId);
}

// ---------------------------------------------------------------------------
// View-override system  (Riverpod)
// ---------------------------------------------------------------------------

/// A transient UI override entry.
class ViewOverrideEntry {
  final dynamic value;
  int? remainingUses;

  ViewOverrideEntry({required this.value, this.remainingUses});
}

/// Manages transient view overrides set by integrity responses.
class ViewOverrideNotifier extends StateNotifier<Map<String, ViewOverrideEntry>> {
  ViewOverrideNotifier() : super({});

  /// Keys currently being consumed this microtask — prevents
  /// rebuild loops from draining all uses in one frame.
  final Set<String> _consumingThisFrame = {};

  /// Set an override for [target]. If [remainingUses] is provided, the
  /// override is automatically removed after that many consumptions.
  void set(String target, dynamic value, {int? remainingUses}) {
    state = {
      ...state,
      target: ViewOverrideEntry(value: value, remainingUses: remainingUses),
    };
  }

  /// Consume one use of the override keyed by [key].
  /// Call this when the UI element that reads the override is displayed.
  ///
  /// Guards against re-entrant consumption: if the same key is consumed
  /// multiple times within the same microtask (e.g. because the state
  /// change triggers a rebuild that calls consumeUse again), only the
  /// first call takes effect.
  void consumeUse(String key) {
    final entry = state[key];
    if (entry == null) return;

    // Prevent the watch→consume→rebuild→consume loop from
    // draining all remaining uses in a single frame.
    if (_consumingThisFrame.contains(key)) return;
    _consumingThisFrame.add(key);
    Future.microtask(() => _consumingThisFrame.remove(key));

    if (entry.remainingUses != null) {
      final remaining = entry.remainingUses! - 1;
      if (remaining <= 0) {
        state = Map.from(state)..remove(key);
        IntegrityService.updatePersistedOverrideUses(key, null);
      } else {
        state = {
          ...state,
          key: ViewOverrideEntry(value: entry.value, remainingUses: remaining),
        };
        IntegrityService.updatePersistedOverrideUses(key, remaining);
      }
    }
  }

  /// Remove override for [key].
  void remove(String key) {
    if (!state.containsKey(key)) return;
    state = Map.from(state)..remove(key);
    IntegrityService.updatePersistedOverrideUses(key, null);
  }
}

final viewOverrideProvider =
    StateNotifierProvider<ViewOverrideNotifier, Map<String, ViewOverrideEntry>>(
  (ref) => ViewOverrideNotifier(),
);

// ---------------------------------------------------------------------------
// Executed-adjustments tracker (in-memory, session-scoped)
// ---------------------------------------------------------------------------

class _ExecutedAdjustmentsNotifier extends StateNotifier<Set<String>> {
  _ExecutedAdjustmentsNotifier() : super({});

  void add(String id) => state = {...state, id};
}

final executedAdjustmentsProvider =
    StateNotifierProvider<_ExecutedAdjustmentsNotifier, Set<String>>(
  (ref) => _ExecutedAdjustmentsNotifier(),
);

class _ContentResolver {
  static Map<String, dynamic>? _content;
  
  static Future<void> _ensureLoaded() async {
    if (_content != null) return;
    
    try {
      // TODO: This will load encrypted content
      // For now, load from a JSON file
      final data = await rootBundle.loadString('assets/integrity_content.json');
      _content = jsonDecode(data);
    } catch (e) {
      _content = {};
    }
  }
  
  static Future<String?> getAlertText(String alertId) async {
    await _ensureLoaded();
    return _content?['alerts']?[alertId] as String?;
  }
  
  static Future<Map<String, dynamic>?> getBreadcrumbPatch(String breadcrumbId) async {
    await _ensureLoaded();
    return _content?['breadcrumbs']?[breadcrumbId] as Map<String, dynamic>?;
  }
  
  static Future<Map<String, dynamic>?> getEffectPatch(String effectKey) async {
    await _ensureLoaded();
    return _content?['effects']?[effectKey] as Map<String, dynamic>?;
  }
}

// ---------------------------------------------------------------------------
// Response processor
// ---------------------------------------------------------------------------

/// Process all queued integrity responses.
///
/// Call after [IntegrityService.reportEvent] from any widget context,
/// or on app lifecycle resume.
Future<void> processIntegrityResponses(WidgetRef ref) async {
  final responses = await IntegrityService.getQueuedArtifacts();
  if (responses.isEmpty) return;

  for (final response in responses) {
    if (IntegrityService.diagnosticsEnabled && response.debug != null) {
    }

    switch (response.type) {
      case 'noop':
        final effectKey = response.data['effect_key'] as String?;
        if (effectKey != null) {
          final patch = await _ContentResolver.getEffectPatch(effectKey);
          if (patch != null) {
            final target = patch['target'] as String;
            final value = patch['value'];
            final uses = patch['uses'] as int?;
            ref.read(viewOverrideProvider.notifier).set(
              target, value, remainingUses: uses,
            );
            await IntegrityService.persistOverride(target, value, uses);
          }
        }
        break;

      case 'system_message':
        MemoixSnackBar.show(response.data['text'] ?? '');
        break;
      
      case 'alert':
        final alertId = response.data['alert_id'] as String?;
        if (alertId != null) {
          final text = await _ContentResolver.getAlertText(alertId);
          if (text != null) {
            
            MemoixSnackBar.show(text);
          }
        }
        break;

      case 'breadcrumb':
        final breadcrumbId = response.data['breadcrumb_id'] as String?;
        if (breadcrumbId != null) {
          final patch = await _ContentResolver.getBreadcrumbPatch(breadcrumbId);
          if (patch != null) {
            final target = patch['target'] as String;
            final value = patch['value'];
            final uses = patch['uses'] as int?;
            ref.read(viewOverrideProvider.notifier).set(
              target, value, remainingUses: uses,
            );
            await IntegrityService.persistOverride(target, value, uses);
          }
        }
        break;

      case 'ui_patch':
        final target = response.data['target'] as String?;
        final value = response.data['value'];
        final uses = response.data['uses_remaining'] as int?;
        if (target != null) {
          ref.read(viewOverrideProvider.notifier).set(
            target,
            value,
            remainingUses: uses,
          );
        }
        break;

      case 'view_adjustment':
        final id = response.data['id'] as String?;
        if (id == null) break;
        final executeOnce = response.data['once'] as bool? ?? false;
        final executed = ref.read(executedAdjustmentsProvider);

        if (!executeOnce || !executed.contains(id)) {
          _applyViewAdjustment(ref, response.data);
          if (executeOnce) {
            ref.read(executedAdjustmentsProvider.notifier).add(id);
          }
        }
        break;

      case 'config_update':
        final key = response.data['key'] as String?;
        final value = response.data['value'];
        if (key != null) {
          final prefs = await SharedPreferences.getInstance();
          if (value is bool) {
            await prefs.setBool(key, value);
          } else if (value is String) {
            await prefs.setString(key, value);
          } else if (value is int) {
            await prefs.setInt(key, value);
          }
        }
        break;

      case 'navigation_request':
        final screen = response.data['screen'] as String?;
        if (screen != null && IntegrityService.diagnosticsEnabled) {
        }
        break;

      default:
        if (IntegrityService.diagnosticsEnabled) {
        }
    }
  }
}

void _applyViewAdjustment(WidgetRef ref, Map<String, dynamic> data) {
  final id = data['id'] as String?;
  if (id == null) return;

  // Delegate specific adjustments to the override system or any
  // custom behaviour the encrypted handler defines.
  // Override values can be read via the [viewOverrideProvider].
  if (data.containsKey('value')) {
    ref.read(viewOverrideProvider.notifier).set(
          id,
          data['value'],
          remainingUses: data['uses'] as int?,
        );
  }
}