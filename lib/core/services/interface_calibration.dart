import 'dart:math' show min;
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/mealplan/models/meal_plan.dart';
import '../../features/recipes/models/recipe.dart';
import 'integrity_service.dart';

// Helper: zero-padded YYYY-MM-DD string
String _dKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class LocalInterfaceIndex {
  static const _act = 'db.active_index';
  static const _dis = 'db.operation_log';
  static const _share = 'metrics.sync_counter';
  static const _alertDis = 'metrics.alert_index';
  static const _breadDis = 'metrics.trace_index';
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

  Future<void> clear() async {
    for (final k in [_act, _dis, _share, _alertDis, _breadDis]) {
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
  bool _sessionFired = false;
  bool _alertFiredThisSession = false;
  bool _breadcrumbFiredThisSession = false;

  CalibrationEvaluator({required Isar db, required LocalInterfaceIndex idx})
      : _db = db,
        _idx = idx;

  Future<List<String>> evaluate(String event, Map<String, dynamic> meta) async {
    await _applyCounters(event, meta);
    final activated = <String>[];
    for (final s in _specs) {
      if (_idx.isActivated(s.key) || !s.events.contains(event)) continue;
      if (await s.condition(event, meta, _db, _idx)) {
        await _idx.activate(s.key);
        activated.add(s.key);
      }
    }
    return activated;
  }

  Future<List<IntegrityResponse>> deriveEffects() async {
    if (_sessionFired) return [];
    final total = _idx.activatedCount;
    final res = <IntegrityResponse>[];
    for (final e in _effectThresholds.entries) {
      final t = e.key, k = e.value;
      if (total >= t && !_idx.isEffectDispatched(k)) {
        await _idx.markEffectDispatched(k);
        res.add(IntegrityResponse(
            type: 'noop', data: {'effect_key': k, 'threshold': t}));
        _sessionFired = true;
        break;
      }
    }
    return res;
  }

  Future<List<IntegrityResponse>> deriveAlerts(List<String> activated) async {
    if (_alertFiredThisSession) return [];
    for (final s in _specs) {
      if (s.alertId == null || !activated.contains(s.key)) continue;
      if (_idx.isAlertDispatched(s.alertId!)) continue;
      await _idx.markAlertDispatched(s.alertId!);
      _alertFiredThisSession = true;
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
    if (_breadcrumbFiredThisSession) return [];
    for (final s in _specs) {
      if (s.breadcrumbId == null || !activated.contains(s.key)) continue;
      if (_idx.isBreadcrumbDispatched(s.breadcrumbId!)) continue;
      await _idx.markBreadcrumbDispatched(s.breadcrumbId!);
      _breadcrumbFiredThisSession = true;
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
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        final startKey = _dKey(start);
        final todayKey = _dKey(now);
        // Fetch all meal plans and filter in Dart (string comparison on date)
        final plans = await db.mealPlans.where().findAll();
        final inRange = plans
            .where((p) =>
                p.date.compareTo(startKey) >= 0 &&
                p.date.compareTo(todayKey) <= 0 &&
                p.meals.isNotEmpty)
            .map((p) => p.date)
            .toSet();
        return inRange.length >= 5;
      },
    ),
    _Spec(
      key: 'cache.favourite_index',
      events: {'activity.recipe_favourited'},
      breadcrumbId: 'cache.entry_log_03',
      condition: (ev, m, db, idx) async => await db.recipes.filter().isFavoriteEqualTo(true).count() >= 5,
    ),
    _Spec(
      key: 'gfx.render_pipeline_state',
      events: {'activity.recipe_saved', 'activity.setting_changed'},
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
      condition: (ev, m, db, idx) async {
        final saved = m['result_saved'] as bool? ?? false;
        if (!saved) return false;
        final steps = (m['result_steps'] as int?) ?? 0;
        final a = (m['recipe_a_steps'] as int?) ?? 0;
        final b = (m['recipe_b_steps'] as int?) ?? 0;
        if (a == 0 || b == 0) return false;
        return steps < min(a, b);
      },
    ),
    _Spec(
      key: 'storage.archive_density_check',
      events: {'activity.recipe_saved'},
      condition: (ev, m, db, idx) async {
        if (m['recipe_source'] != 'personal') return false;
        final total = await db.recipes.filter().sourceEqualTo(RecipeSource.personal).count();
        if (total < 40) return false;
        final items = await db.recipes.filter().sourceEqualTo(RecipeSource.personal).findAll();
        final filtered = items.where((r) => r.directions.length >= 4 && r.ingredients.length >= 5).toList();
        final days = filtered.map((r) => _dKey(r.createdAt)).toSet();
        return filtered.length >= 40 && days.length >= 14;
      },
    ),
  ];
}
