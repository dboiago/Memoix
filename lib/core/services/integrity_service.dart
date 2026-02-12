import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

import '../../app/app.dart';

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
      debugPrint('[Integrity] Event: $event');
      if (metadata != null && metadata.isNotEmpty) {
        debugPrint('[Integrity] Metadata: $metadata');
      }
    }

    if (_handler != null) {
      try {
        final responses = await _handler!(event, metadata ?? {}, _store);
        _queue.addAll(responses);
      } catch (e) {
        if (_diagnosticsEnabled) {
          debugPrint('[Integrity] Handler error: $e');
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
      } else {
        state = {
          ...state,
          key: ViewOverrideEntry(value: entry.value, remainingUses: remaining),
        };
      }
    }
  }

  /// Remove override for [key].
  void remove(String key) {
    if (!state.containsKey(key)) return;
    state = Map.from(state)..remove(key);
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
      debugPrint('[Content] Failed to load: $e');
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
      debugPrint('[Integrity] ${response.debug}');
    }

    switch (response.type) {
      case 'noop':
        break;

      case 'system_message':
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(response.data['text'] ?? ''),
            duration: Duration(
              seconds: (response.data['duration_seconds'] as int?) ?? 3,
            ),
          ),
        );
        break;
      
      case 'alert':
        debugPrint('[PROCESS] Processing alert');
        final alertId = response.data['alert_id'] as String?;
        if (alertId != null) {
            final text = await _ContentResolver.getAlertText(alertId);
            if (text != null) {
            rootScaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(
                content: Text(text),
                duration: Duration(seconds: 5),
                ),
            );
            debugPrint('[PROCESS] Showed alert: $alertId');
            }
        }
        break;

        case 'breadcrumb':
        debugPrint('[PROCESS] Processing breadcrumb');
        final breadcrumbId = response.data['breadcrumb_id'] as String?;
        if (breadcrumbId != null) {
            final patch = await _ContentResolver.getBreadcrumbPatch(breadcrumbId);
            if (patch != null) {
            ref.read(viewOverrideProvider.notifier).set(
                patch['target'] as String,
                patch['value'],
                remainingUses: patch['uses'] as int?,
            );
            debugPrint('[PROCESS] Applied breadcrumb: $breadcrumbId');
            }
        }
        break;

        case 'noop':
        debugPrint('[PROCESS] Processing effect noop');
        final effectKey = response.data['effect_key'] as String?;
        if (effectKey != null) {
            final patch = await _ContentResolver.getEffectPatch(effectKey);
            if (patch != null) {
            ref.read(viewOverrideProvider.notifier).set(
                patch['target'] as String,
                patch['value'],
                remainingUses: patch['uses'] as int?,
            );
            debugPrint('[PROCESS] Applied effect: $effectKey');
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
        if (screen != null) {
          if (IntegrityService.diagnosticsEnabled) {
            debugPrint('[Integrity] Navigation request: $screen');
          }
          // Navigation targets are registered by the encrypted handler.
          // Default: log unknown targets.
        }
        break;

      default:
        if (IntegrityService.diagnosticsEnabled) {
          debugPrint('[Integrity] Unknown response type: ${response.type}');
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

  if (IntegrityService.diagnosticsEnabled) {
    debugPrint('[Integrity] Applied view adjustment: $id');
  }
}