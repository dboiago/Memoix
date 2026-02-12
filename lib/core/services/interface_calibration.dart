import 'dart:math' show min;

import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/mealplan/models/meal_plan.dart';
import '../../features/recipes/models/recipe.dart';
import 'integrity_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Returns a zero-padded `YYYY-MM-DD` string for [d].
String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ---------------------------------------------------------------------------
// LocalInterfaceIndex — persisted activation & supplemental state
// ---------------------------------------------------------------------------

/// Minimal persistent store for calibration state.
///
/// Stores only what cannot be derived from existing Isar models:
///   - Set of activated payload keys
///   - Set of dispatched effect keys
///   - Share counter (no Isar model tracks share events)
///
/// Also exposes read-only derived flags (e.g. settings) so that specs
/// never need to fetch SharedPreferences themselves.
///
/// All calibration keys are prefixed `cal_` in SharedPreferences.
class LocalInterfaceIndex {
  static const _activated = 'cal_activated';
  static const _dispatched = 'cal_dispatched';
  static const _shareCount = 'cal_share_count';

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // --- activated payload keys ------------------------------------------------

  Set<String> get activatedKeys =>
      (_prefs?.getStringList(_activated) ?? []).toSet();

  int get activatedCount => activatedKeys.length;

  bool isActivated(String key) => activatedKeys.contains(key);

  Future<void> activate(String key) async {
    final keys = activatedKeys..add(key);
    await _prefs?.setStringList(_activated, keys.toList());
  }

  // --- dispatched effect keys ------------------------------------------------

  Set<String> get _dispatchedKeys =>
      (_prefs?.getStringList(_dispatched) ?? []).toSet();

  bool isEffectDispatched(String key) => _dispatchedKeys.contains(key);

  Future<void> markEffectDispatched(String key) async {
    final keys = _dispatchedKeys..add(key);
    await _prefs?.setStringList(_dispatched, keys.toList());
  }

  // --- supplemental counters -------------------------------------------------
  // Only for events with no backing Isar model.

  int get shareCount => _prefs?.getInt(_shareCount) ?? 0;

  Future<void> incrementShareCount() async {
    await _prefs?.setInt(_shareCount, shareCount + 1);
  }

  // --- derived settings flags ------------------------------------------------
  // Read-only so specs stay pure queries without fetching prefs themselves.

  /// Whether the user has the "show header images" setting enabled.
  bool get showHeaderImages => _prefs?.getBool('show_header_images') ?? true;

  // --- maintenance -----------------------------------------------------------

  Future<void> clear() async {
    for (final key in [_activated, _dispatched, _shareCount]) {
      await _prefs?.remove(key);
    }
  }
}

// ---------------------------------------------------------------------------
// CalibrationSpec — a single activation rule
// ---------------------------------------------------------------------------

/// Defines one activation condition.
///
/// [relevantEvents] — the event names that should trigger re-evaluation.
/// [condition] — a **pure** query function.  It must not mutate state;
///   any counter updates (e.g. share count) are handled by the evaluator
///   *before* conditions are checked.
class _CalibrationSpec {
  final String key;
  final Set<String> relevantEvents;
  final Future<bool> Function(
    String event,
    Map<String, dynamic> metadata,
    Isar db,
    LocalInterfaceIndex index,
  ) condition;

  const _CalibrationSpec({
    required this.key,
    required this.relevantEvents,
    required this.condition,
  });
}

// ---------------------------------------------------------------------------
// CalibrationEvaluator — instantiated once, shared across events
// ---------------------------------------------------------------------------

class CalibrationEvaluator {
  final Isar _db;
  final LocalInterfaceIndex _index;

  /// In-memory flag — ensures at most one effect batch is emitted per
  /// app session even if multiple thresholds are crossed in a single
  /// evaluation or across successive evaluations within one launch.
  bool _effectsFiredThisSession = false;

  CalibrationEvaluator({required Isar db, required LocalInterfaceIndex index})
      : _db = db,
        _index = index;

  // ---- public API ----------------------------------------------------------

  /// Evaluate all non-activated specs relevant to [event].
  ///
  /// Counter side-effects (share count) are applied *once* before condition
  /// evaluation so that specs remain pure query functions.
  Future<List<String>> evaluate(
    String event,
    Map<String, dynamic> metadata,
  ) async {
    // --- pre-evaluation counter mutations (separated from specs) ---
    await _applyCounterMutations(event, metadata);

    // --- condition evaluation (pure) ---
    final activated = <String>[];

    for (final spec in _specs) {
      if (_index.isActivated(spec.key)) continue;
      if (!spec.relevantEvents.contains(event)) continue;

      final met = await spec.condition(event, metadata, _db, _index);
      if (met) {
        await _index.activate(spec.key);
        activated.add(spec.key);
      }
    }

    return activated;
  }

  /// Derive effect responses for any newly-crossed activation thresholds.
  ///
  /// At most **one** effect is dispatched per app session. Persistent tracking
  /// (SharedPreferences via [LocalInterfaceIndex]) ensures an effect that has
  /// already been dispatched is never re-emitted across restarts.
  ///
  /// Effect payloads are intentionally empty (`noop`) — real payloads will
  /// be provided externally.
  Future<List<IntegrityResponse>> deriveEffects() async {
    if (_effectsFiredThisSession) return [];

    final total = _index.activatedCount;
    final responses = <IntegrityResponse>[];

    for (final entry in _effectThresholds.entries) {
      final threshold = entry.key;
      final effectKey = entry.value;
      if (total >= threshold && !_index.isEffectDispatched(effectKey)) {
        await _index.markEffectDispatched(effectKey);
        responses.add(IntegrityResponse(
          type: 'noop',
          data: {'effect_key': effectKey, 'threshold': threshold},
          debug: 'Effect threshold $threshold reached → $effectKey',
        ));
        // Only emit one effect per session — break after the first match.
        _effectsFiredThisSession = true;
        break;
      }
    }

    return responses;
  }

  // ---- counter mutations (non-spec) ----------------------------------------

  Future<void> _applyCounterMutations(
    String event,
    Map<String, dynamic> metadata,
  ) async {
    if (event == 'activity.recipe_shared') {
      await _index.incrementShareCount();
    }
    // Other events derive counts from Isar — no supplemental counters needed.
  }

  // ---- effect thresholds ---------------------------------------------------

  /// Maps activation-count thresholds to effect keys.
  /// Ordered ascending so [deriveEffects] fires the lowest unmet threshold first.
  static const _effectThresholds = <int, String>{
    2: 'effect.threshold_2',
    4: 'effect.threshold_4',
    6: 'effect.threshold_6',
    8: 'effect.threshold_8',
  };

  // ---- specs ----------------------------------------------------------------

  static final List<_CalibrationSpec> _specs = [
    // 1. Sharing recipes ≥ 3 times
    _CalibrationSpec(
      key: 'calibration.share_frequency',
      relevantEvents: {'activity.recipe_shared'},
      condition: (event, meta, db, index) async {
        return index.shareCount >= 3;
      },
    ),

    // 2. Re-editing same saved recipe ≥ 3 times across ≥ 2 distinct
    //    calendar days.  Uses Recipe.editCount, firstEditAt, lastEditAt
    //    (persisted on the model).
    _CalibrationSpec(
      key: 'calibration.edit_recurrence',
      relevantEvents: {'activity.recipe_saved'},
      condition: (event, meta, db, index) async {
        if (meta['is_edit'] != true) return false;
        final editCount = (meta['edit_count'] as int?) ?? 0;
        if (editCount < 3) return false;

        // Parse actual timestamps from metadata
        final firstStr = meta['first_edit_at'] as String?;
        final lastStr = meta['last_edit_at'] as String?;
        if (firstStr == null || lastStr == null) return false;

        final firstDay = _dateKey(DateTime.parse(firstStr));
        final lastDay = _dateKey(DateTime.parse(lastStr));
        // ≥ 2 distinct calendar days means first and last fall on different days
        return firstDay != lastDay;
      },
    ),

    // 3. Create shopping list with no meat items and ≥ 7 produce items
    _CalibrationSpec(
      key: 'calibration.produce_list',
      relevantEvents: {'activity.shopping_list_created'},
      condition: (event, meta, db, index) async {
        final meatCount = (meta['meat_count'] as int?) ?? 0;
        final produceCount = (meta['produce_count'] as int?) ?? 0;
        return meatCount == 0 && produceCount >= 7;
      },
    ),

    // 4. Set any meal for 5 distinct days within rolling 7-day window
    _CalibrationSpec(
      key: 'calibration.meal_coverage',
      relevantEvents: {'activity.meal_plan_updated'},
      condition: (event, meta, db, index) async {
        final today = DateTime.now();
        final windowStart = DateTime(today.year, today.month, today.day)
            .subtract(const Duration(days: 6)); // 7-day window inclusive
        final windowStartKey = _dateKey(windowStart);
        final todayKey = _dateKey(today);

        // MealPlan.date is stored as yyyy-MM-dd string with unique index.
        // Query all plans from windowStart onward, then filter by non-empty.
        final plans = await db.mealPlans
            .where()
            .dateGreaterThan(windowStartKey, include: true)
            .filter()
            .mealsIsNotEmpty()
            .findAll();

        final distinctDays = plans
            .where((p) =>
                p.date.compareTo(windowStartKey) >= 0 &&
                p.date.compareTo(todayKey) <= 0)
            .map((p) => p.date)
            .toSet();

        return distinctDays.length >= 5;
      },
    ),

    // 5. Add 5 recipes to favourites
    _CalibrationSpec(
      key: 'calibration.favourite_breadth',
      relevantEvents: {'activity.recipe_favourited'},
      condition: (event, meta, db, index) async {
        final count = await db.recipes
            .filter()
            .isFavoriteEqualTo(true)
            .count();
        return count >= 5;
      },
    ),

    // 6. Add 4 header images to manually created recipes AND
    //    "show header images" setting is enabled.
    //    Setting is read from LocalInterfaceIndex (no SharedPreferences
    //    fetch inside the spec).
    _CalibrationSpec(
      key: 'calibration.visual_config',
      relevantEvents: {'activity.recipe_saved', 'activity.setting_changed'},
      condition: (event, meta, db, index) async {
        if (!index.showHeaderImages) return false;

        final count = await db.recipes
            .filter()
            .sourceEqualTo(RecipeSource.personal)
            .and()
            .headerImageIsNotNull()
            .and()
            .headerImageIsNotEmpty()
            .count();
        return count >= 4;
      },
    ),

    // 7. When comparing 2 recipes, saving a new draft whose steps
    //    < min(originalA.steps, originalB.steps)
    _CalibrationSpec(
      key: 'calibration.synthesis_efficiency',
      relevantEvents: {'activity.recipes_compared'},
      condition: (event, meta, db, index) async {
        final resultSaved = meta['result_saved'] as bool? ?? false;
        if (!resultSaved) return false;

        final resultSteps = (meta['result_steps'] as int?) ?? 0;
        final aSteps = (meta['recipe_a_steps'] as int?) ?? 0;
        final bSteps = (meta['recipe_b_steps'] as int?) ?? 0;
        if (aSteps == 0 || bSteps == 0) return false;

        return resultSteps < min(aSteps, bSteps);
      },
    ),

    // 8. Create 40 manual recipes (not OCR/URL), each with ≥ 4 steps
    //    and ≥ 5 ingredients, across ≥ 14 distinct creation days
    _CalibrationSpec(
      key: 'calibration.manual_depth',
      relevantEvents: {'activity.recipe_saved'},
      condition: (event, meta, db, index) async {
        if (meta['recipe_source'] != 'personal') return false;

        // Count gate — avoid expensive full scan
        final totalPersonal = await db.recipes
            .filter()
            .sourceEqualTo(RecipeSource.personal)
            .count();
        if (totalPersonal < 40) return false;

        // Full scan needed to check per-recipe step/ingredient/date constraints
        final qualifying = await db.recipes
            .filter()
            .sourceEqualTo(RecipeSource.personal)
            .findAll();

        final filtered = qualifying
            .where((r) =>
                r.directions.length >= 4 && r.ingredients.length >= 5)
            .toList();

        if (filtered.length < 40) return false;

        final distinctDays = filtered
            .map((r) => _dateKey(r.createdAt))
            .toSet();

        return distinctDays.length >= 14;
      },
    ),
  ];
}
