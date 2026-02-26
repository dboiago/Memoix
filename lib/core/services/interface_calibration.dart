import 'dart:math' show min;
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/mealplan/models/meal_plan.dart';
import '../../features/recipes/models/recipe.dart';
import 'integrity_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

// Helper: zero-padded YYYY-MM-DD string
String _dKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class LocalInterfaceIndex {
  static const _act = 'db.active_index';
  static const _dis = 'db.operation_log';
  static const _share = 'sync.buffer_count';
  static const _alertDis = 'state.notification_log';
  static const _breadDis = 'state.trace_log';
  static const _pendingQueue = 'cache.deferred_queue';

  SharedPreferences? _prefs;

  Future<void> init() async => _prefs ??= await SharedPreferences.getInstance();

  Set<String> get activatedKeys => (_prefs?.getStringList(_act) ?? []).toSet();
  int get activatedCount => activatedKeys.length;
  bool isActivated(String key) => activatedKeys.contains(key);
  Future<void> activate(String key) async {
    final keys = activatedKeys..add(key);
    await _prefs?.setStringList(_act, keys.toList());
  }

  Set<String> get _disKeys => (_prefs?.getStringList(_dis) ?? []).toSet();
  bool isEffectDispatched(String key) => _disKeys.contains(key);
  Future<void> markEffectDispatched(String key) async {
    final keys = _disKeys..add(key);
    await _prefs?.setStringList(_dis, keys.toList());
  }

  Set<String> get _alertDisKeys => (_prefs?.getStringList(_alertDis) ?? []).toSet();
  bool isAlertDispatched(String id) => _alertDisKeys.contains(id);
  Future<void> markAlertDispatched(String id) async {
    final keys = _alertDisKeys..add(id);
    await _prefs?.setStringList(_alertDis, keys.toList());
  }

  Set<String> get _breadDisKeys => (_prefs?.getStringList(_breadDis) ?? []).toSet();
  bool isBreadcrumbDispatched(String id) => _breadDisKeys.contains(id);
  Future<void> markBreadcrumbDispatched(String id) async {
    final keys = _breadDisKeys..add(id);
    await _prefs?.setStringList(_breadDis, keys.toList());
  }

  int get shareCount => _prefs?.getInt(_share) ?? 0;
  Future<void> incrementShareCount() async =>
      await _prefs?.setInt(_share, shareCount + 1);

  bool get showHeaderImages => _prefs?.getBool('show_header_images') ?? true;

  Map<String, String> get pendingAlerts {
    final json = _prefs?.getString(_pendingQueue) ?? '{}';
    try {
      return Map<String, String>.from(jsonDecode(json));
    } catch (e) {
      return {};
    }
  }

  Future<void> queueAlert(String alertId, String eventType) async {
    final pending = pendingAlerts;
    pending[alertId] = eventType;
    await _prefs?.setString(_pendingQueue, jsonEncode(pending));
  }
  
  Future<void> clearPendingAlert(String alertId) async {
    final pending = pendingAlerts;
    pending.remove(alertId);
    await _prefs?.setString(_pendingQueue, jsonEncode(pending));
  }

  Future<void> clear() async {
    for (final k in [_act, _dis, _share, _alertDis, _breadDis, _pendingQueue]) {
      await _prefs?.remove(k);
    }
  }
}

class _Spec {
  final String key;
  final Set<String> events;
  final Future<bool> Function(
      String, Map<String, dynamic>, Isar, LocalInterfaceIndex) condition;
  final String? alertId;
  final String? breadcrumbId;
  const _Spec({
    required this.key,
    required this.events,
    required this.condition,
    this.alertId,
    this.breadcrumbId,
  });
}

class CalibrationEvaluator {
  final Isar _db;
  final LocalInterfaceIndex _idx;
  static bool _sessionHasFired = false;

  static void resetSessionFlag() {
    _sessionHasFired = false;
  }

  int countDispatchedAlerts() {
    return _specs
        .where((s) => s.alertId != null && _idx.isAlertDispatched(s.alertId!))
        .length;
  }

  CalibrationEvaluator({required Isar db, required LocalInterfaceIndex idx})
      : _db = db,
        _idx = idx;

  Future<List<String>> evaluate(String event, Map<String, dynamic> meta) async {
    await _applyCounters(event, meta);
    final activated = <String>[];
    for (final s in _specs) {
      if (_idx.isActivated(s.key) || !s.events.contains(event)) {
        continue;
      }
      final passed = await s.condition(event, meta, _db, _idx);
      if (passed) {
        await _idx.activate(s.key);
        activated.add(s.key);
      }
    }
    return activated;
  }

  Future<IntegrityResponse?> checkPendingAlert(String currentEvent) async {
    if (_sessionHasFired) return null;
    
    for (final entry in _idx.pendingAlerts.entries) {
      if (entry.value == currentEvent) {
        await _idx.clearPendingAlert(entry.key);
        await _idx.markAlertDispatched(entry.key);
        _sessionHasFired = true;
        
        String? specKey;
        for (final s in _specs) {
          if (s.alertId == entry.key) {
            specKey = s.key;
            break;
          }
        }
        
        return IntegrityResponse(
          type: 'alert',
          data: {'alert_id': entry.key, 'spec_key': specKey},
        );
      }
    }
    return null;
  }

  Future<IntegrityResponse?> checkPendingBreadcrumb(int alertsDispatched) async {
    if (_sessionHasFired) return null;
    
    for (final entry in _effectThresholds.entries) {
      final threshold = entry.key;
      final effectKey = entry.value;
      
      if (alertsDispatched >= threshold && !_idx.isEffectDispatched(effectKey)) {
        await _idx.markEffectDispatched(effectKey);
        _sessionHasFired = true;
        
        return IntegrityResponse(
          type: 'noop',
          data: {'effect_key': effectKey, 'threshold': threshold},
        );
      }
    }
    
    return null;
  }

  Future<List<IntegrityResponse>> deriveAlerts(List<String> activated, String currentEvent) async {
    if (_sessionHasFired) {
      for (final s in _specs) {
        if (s.alertId == null || !activated.contains(s.key)) continue;
        if (_idx.isAlertDispatched(s.alertId!)) continue;
        await _idx.queueAlert(s.alertId!, currentEvent);
      }
      return [];
    }
    
    for (final s in _specs) {
      if (s.alertId == null || !activated.contains(s.key)) continue;
      if (_idx.isAlertDispatched(s.alertId!)) continue;
      
      await _idx.markAlertDispatched(s.alertId!);
      _sessionHasFired = true;
      return [
        IntegrityResponse(
          type: 'alert',
          data: {'alert_id': s.alertId, 'spec_key': s.key},
        ),
      ];
    }
    
    return [];
  }

  Future<List<IntegrityResponse>> deriveBreadcrumbs(List<String> activated) async {
     if (_sessionHasFired) return [];
    
    for (final s in _specs) {
      if (s.breadcrumbId == null || !activated.contains(s.key)) continue;
      if (_idx.isBreadcrumbDispatched(s.breadcrumbId!)) continue;
      
      await _idx.markBreadcrumbDispatched(s.breadcrumbId!);
      _sessionHasFired = true;
      return [
        IntegrityResponse(
          type: 'breadcrumb',
          data: {'breadcrumb_id': s.breadcrumbId, 'spec_key': s.key},
        ),
      ];
    }
    return [];
  }

  Future<void> _applyCounters(String event, Map<String, dynamic> meta) async {
    if (event == 'activity.recipe_shared') await _idx.incrementShareCount();
  }

  static const _effectThresholds = <int, String>{
    2: 'effect.threshold_2',
    4: 'effect.threshold_4',
    6: 'effect.threshold_6',
    8: 'effect.threshold_8',
  };

  static final List<_Spec> _specs = [
    _Spec(
      key: 'sync.export_buffer_v1',
      events: {'activity.recipe_shared'},
      alertId: 'sync.label_01',
      condition: (ev, m, db, idx) async => idx.shareCount >= 3,
    ),
    _Spec(
      key: 'db.entry_update_v2',
      events: {'activity.recipe_saved'},
      alertId: 'db.label_01',
      breadcrumbId: 'cache.entry_log_02',
      condition: (ev, m, db, idx) async {
        if (m['is_edit'] != true) return false;
        final cnt = (m['edit_count'] as int?) ?? 0;
        if (cnt < 3) return false;
        final f = m['first_edit_at'] as String?, l = m['last_edit_at'] as String?;
        if (f == null || l == null) return false;
        return _dKey(DateTime.parse(f)) != _dKey(DateTime.parse(l));
      },
    ),
    _Spec(
      key: 'parser.list_attr_sum',
      events: {'activity.shopping_list_created'},
      alertId: 'parser.label_01',
      condition: (ev, m, db, idx) async {
        final meat = (m['meat_count'] as int?) ?? 0;
        final prod = (m['produce_count'] as int?) ?? 0;
        return meat == 0 && prod >= 7;
      },
    ),
    _Spec(
      key: 'cache.view_range_v01',
      events: {'activity.meal_plan_updated'},
      alertId: 'cache.label_02',
      condition: (ev, m, db, idx) async {
        final plans = await db.mealPlans.where().findAll();
        if (plans.isEmpty) return false;
        
        final daysWithMeals = plans
            .where((p) => p.meals.isNotEmpty)
            .map((p) => p.date)
            .toSet()
            .toList()
          ..sort();
        
        if (daysWithMeals.length < 5) return false;
        
        for (int i = 0; i < daysWithMeals.length - 4; i++) {
          final startDate = daysWithMeals[i];
          final endDate = DateTime.parse(startDate).add(Duration(days: 6));
          final endKey = _dKey(endDate);
          
          final daysInWindow = daysWithMeals
              .skip(i)
              .takeWhile((d) => d.compareTo(endKey) <= 0)
              .length;
              
          if (daysInWindow >= 5) return true;
        }
        
        return false;
      },
    ),
    _Spec(
      key: 'cache.favourite_index',
      events: {'activity.recipe_favourited'},
      alertId: 'cache.label_03',
      condition: (ev, m, db, idx) async {
        if (m['is_adding'] != true) return false;
        
        final count = await db.recipes.filter().isFavoriteEqualTo(true).count();
        return count >= 5;
      },
    ),
    _Spec(
      key: 'gfx.render_pipeline_state',
      events: {'activity.recipe_saved', 'activity.setting_changed'},
      alertId: 'gfx.label_01',
      condition: (ev, m, db, idx) async {
        if (!idx.showHeaderImages) return false;
        
        return await db.recipes
            .filter()
            .sourceEqualTo(RecipeSource.personal)
            .and()
            .headerImageIsNotNull()
            .and()
            .headerImageIsNotEmpty()
            .count() >= 4;
      },
    ),
    _Spec(
      key: 'util.calc_node_diff',
      events: {'activity.recipes_compared'},
      alertId: 'util.label_01',
      condition: (ev, m, db, idx) async {
        final saved = m['result_saved'] as bool? ?? false;
        final steps = m['result_steps'] as int? ?? 0;
        final a = m['recipe_a_steps'] as int? ?? 0;
        final b = m['recipe_b_steps'] as int? ?? 0;
        
        if (!saved) return false;
        if (a == 0 || b == 0) return false;
        return steps < min(a, b);
      },
    ),
    _Spec(
      key: 'storage.archive_density_check',
      events: {'activity.recipe_saved'},
      alertId: 'storage.label_01',
      condition: (ev, m, db, idx) async {
        if (m['recipe_source'] != 'personal') return false;
        
        final total = await db.recipes.filter().sourceEqualTo(RecipeSource.personal).count();
        if (total < 40) return false;
        
        final items = await db.recipes.filter().sourceEqualTo(RecipeSource.personal).findAll();
        final filtered = items.where((r) => 
            r.directions.length >= 4 && 
            r.ingredients.length >= 5
        ).toList();
        
        final days = filtered.map((r) => _dKey(r.createdAt)).toSet();
        return filtered.length >= 40 && days.length >= 14;
      },
    ),
  ];
}