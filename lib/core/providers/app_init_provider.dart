import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/database.dart';
import '../../features/recipes/models/course.dart' as domainModels;
import '../../features/recipes/repository/recipe_repository.dart';
import '../../features/pizzas/repository/pizza_repository.dart';
import '../../features/sandwiches/repository/sandwich_repository.dart';
import '../../features/smoking/repository/smoking_repository.dart';
import '../../features/modernist/repository/modernist_repository.dart';
import '../../features/cheese/repository/cheese_repository.dart';
import '../../features/cellar/repository/cellar_repository.dart';
import '../../features/notes/repository/scratch_pad_repository.dart';
import '../../shared/widgets/course_icon_widget.dart';
import '../services/memoix_recipe_service.dart';
import '../utils/ingredient_categorizer.dart';
import '../services/integrity_service.dart';
import '../services/interface_calibration.dart';
import '../services/schema_migration_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_secure_storage.dart';

final appInitProvider = FutureProvider<void>((ref) async {
  // 1. Database init — MemoixDatabase.initialize() calls refreshCourses()
  //    internally, which runs a Drift batch(deleteAll + insertAll) as a
  //    single committed transaction. The await here guarantees the write is
  //    fully on-disk before any subsequent step runs.
  await MemoixDatabase.initialize();

  // 2. Strict privacy gate for Supabase.
  // The user "unlocks" shared storage by signing in via the hidden 8-second
  // long-press on the Shared Storage tile. Their session is then persisted
  // to SupabaseSecureStorage (flutter_secure_storage, key: supabase.auth.token).
  // We ONLY initialize the Supabase client when that token already exists —
  // guaranteeing zero network activity for users who have never opted in.
  final storage = const SupabaseSecureStorage();
  final hasSession = await storage.hasAccessToken();

  // Read the Culinary Intelligence opt-in flag directly from SharedPreferences.
  // Defaults to false if the key is absent (fresh install / never opted in) or
  // if the read itself throws, so Supabase is never initialized unexpectedly.
  bool telemetryEnabled = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    telemetryEnabled = prefs.getBool('contribute_to_culinary_intelligence') ?? false;
  } catch (e) {
    debugPrint('appInitProvider: could not read telemetry preference — $e');
  }

  if (hasSession || telemetryEnabled) {
    final supabaseUrl = dotenv.maybeGet('SUPABASE_URL');
    final supabaseAnonKey = dotenv.maybeGet('SUPABASE_ANON_KEY');

    if (supabaseUrl != null &&
        supabaseUrl.isNotEmpty &&
        supabaseAnonKey != null &&
        supabaseAnonKey.isNotEmpty) {
      // Fire-and-forget: Supabase init must never delay the first frame.
      unawaited(
        Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
          authOptions: const FlutterAuthClientOptions(
            localStorage: SupabaseSecureStorage(),
          ),
        ).then((_) {
          SupabaseAuthService.initSyncListener();
        }).catchError((Object e) {
          debugPrint('Supabase initialisation failed: $e');
        }),
      );
    }
  }

  // 3. Parallel pre-work — kick off both of these concurrently so their
  //    wall-clock time overlaps with the DB and Supabase steps above.
  //
  //    a) SVG warm-up: pre-populates flutter_svg's svg.cache with
  //       already-resolved ByteData futures. At render time, SvgPicture.asset()
  //       calls svg.cache.putIfAbsent(key, loader) — a cache HIT returns the
  //       already-resolved Future immediately, so the FutureBuilder receives
  //       bytes on the very first frame and the icon paints without any async gap.
  //
  //    b) IngredientService: decompresses and JSON-decodes the bundled
  //       ingredient database (~2-4 s of CPU work on first call). Running it
  //       here keeps it inside the splash so the interactive UI is never frozen.
  final warmUpFuture = Future.wait([
    _warmSvgAssets(),
    IngredientService().initialize(),
  ]);

  // 4. Pre-warm the coursesProvider Riverpod StreamProvider so it is already
  //    in AsyncData state before HomeScreen builds. Because step 1 committed
  //    the Drift batch before any listener subscribed, the stream's first
  //    emission is the fully-seeded list (typically < 1 ms). When HomeScreen
  //    later calls ref.watch(coursesProvider) it finds AsyncData and renders
  //    the grid directly — never hitting its loading branch.
  await ref.read(coursesProvider.future);

  // 5. Wait for SVG warm-up to finish (started in step 3).
  await warmUpFuture;

  // 6. Integrity layer + calibration evaluator — fire-and-forget so the UI
  //    is never blocked waiting for these to complete at startup.
  unawaited(_initIntegrityLayer());

  // 7. Fresh-install gate — if the recipes table is empty (first launch or
  //    after a full clear), seed all bundled content synchronously so the
  //    home grid never renders with 0 counts.
  //
  //    On subsequent launches allRecipesProvider has data immediately and
  //    the if-block is skipped entirely, so startup time is unaffected.
  //
  //    After seedDatabase() completes:
  //      • The bundled version is persisted so _performBackgroundSync() in
  //        app.dart sees the version as already current and skips re-running
  //        the 500+ UUID existence-check loop on this launch.
  //      • All domain providers are invalidated so step 8's pre-warm resolves
  //        with post-sync data, not the empty-list snapshot from before sync.
  final initialRecipes = await ref.read(allRecipesProvider.future);
  if (initialRecipes.isEmpty) {
    await ref.read(localDataSeederProvider).seedDatabase();

    // Persist bundled version so _performBackgroundSync skips this launch.
    try {
      final versionJson = await rootBundle.loadString('assets/recipes/version.json');
      final bundledVersion = (jsonDecode(versionJson) as Map<String, dynamic>)['version'] as int? ?? 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('memoix_recipe_sync_version', bundledVersion);
    } catch (_) {}

    // Invalidate all domain providers so step 8 pre-warms with fresh data.
    ref.invalidate(allRecipesProvider);
    ref.invalidate(allPizzasProvider);
    ref.invalidate(allSandwichesProvider);
    ref.invalidate(allSmokingRecipesProvider);
    ref.invalidate(allModernistRecipesProvider);
    ref.invalidate(allCheeseEntriesProvider);
    ref.invalidate(allCellarEntriesProvider);
    await ref.read(allRecipesProvider.future);
  }

  // 8. Pre-warm every per-course and per-domain provider that HomeScreen's
  //    SliverChildBuilderDelegate watches. All of these are Drift
  //    StreamProviders backed by watch() queries — their first emission from
  //    an already-seeded DB resolves in under 1 ms. Running them in parallel
  //    costs effectively nothing on subsequent launches and guarantees that
  //    every ref.watch() call in the home grid finds AsyncData on the very
  //    first build frame, so counts are never 0 and icons never blank.
  await Future.wait(<Future<void>>[
    // Standard recipe courses — one per slug
    ...domainModels.Course.defaults.map(
      (c) => ref.read(recipesByCourseProvider(c.slug).future).then((_) {}),
    ),
    // Specialised domain tables
    ref.read(allPizzasProvider.future).then((_) {}),
    ref.read(allSandwichesProvider.future).then((_) {}),
    ref.read(allSmokingRecipesProvider.future).then((_) {}),
    ref.read(allModernistRecipesProvider.future).then((_) {}),
    ref.read(allCheeseEntriesProvider.future).then((_) {}),
    ref.read(allCellarEntriesProvider.future).then((_) {}),
    ref.read(recipeDraftsProvider.future).then((_) {}),
  ]);
});

/// A minimal [AssetBundle] that holds pre-loaded [ByteData] values with no
/// internal [Future] fields, making it fully sendable across Dart isolates.
///
/// [PlatformAssetBundle] (i.e. [rootBundle]) caches its load results as live
/// [Future] objects. Dart's isolate message-passing rejects anything that
/// transitively contains a [Future], which causes flutter_svg's [compute]
/// call inside [SvgLoader._load] to throw in AOT/release builds.  By
/// pre-loading the raw bytes here and handing them to [SvgAssetLoader] via
/// this bundle, the [SvgLoaderMessage] that travels through [compute] only
/// carries sendable types ([String], [ByteData], and this class).
class _SendableAssetBundle extends AssetBundle {
  _SendableAssetBundle(this._data);
  final Map<String, ByteData> _data;

  @override
  Future<ByteData> load(String key) {
    final data = _data[key];
    if (data == null) throw FlutterError('Asset not in preloaded bundle: $key');
    return SynchronousFuture(data);
  }
}

/// Pre-populates flutter_svg's svg.cache for the app logo and every course
/// icon SVG. Raw bytes are loaded from [rootBundle] on the main isolate first,
/// then wrapped in [_SendableAssetBundle] so [SvgAssetLoader] can safely pass
/// the loader through [compute] in AOT/release mode.  The cache key produced
/// by [SvgAssetLoader.cacheKey] only depends on the asset path, so it is
/// identical to the key used by [SvgPicture.asset] at render time.
Future<void> _warmSvgAssets() async {
  const logo = 'assets/images/memoix_logo.svg';
  final paths = <String>[logo, ...CourseIconWidget.svgAssets.values];
  await Future.wait(
    paths.map((path) async {
      try {
        final bytes = await rootBundle.load(path);
        final loader = SvgAssetLoader(
          path,
          assetBundle: _SendableAssetBundle({path: bytes}),
        );
        await svg.cache.putIfAbsent(
          loader.cacheKey(null),
          () => loader.loadBytes(null),
        );
      } catch (e) {
        debugPrint('SVG warm-up skipped ($path): $e');
      }
    }),
  );
}

Future<void> _initIntegrityLayer() async {
  try {
    await IntegrityService.initialize();

    final calibrationIndex = LocalInterfaceIndex();
    await calibrationIndex.init();
    final calibrationEvaluator = CalibrationEvaluator(
      db: MemoixDatabase.instance,
      idx: calibrationIndex,
    );

    CalibrationEvaluator.resetSessionFlag();

    IntegrityService.registerHandler((event, metadata, store) async {
      final calibrationEvaluator = CalibrationEvaluator(
        db: MemoixDatabase.instance,
        idx: calibrationIndex,
      );

      final alertsDispatched = calibrationEvaluator.countDispatchedAlerts();
      final breadcrumbResponse =
          await calibrationEvaluator.checkPendingBreadcrumb(alertsDispatched);
      if (breadcrumbResponse != null) {
        return [breadcrumbResponse];
      }

      final activated = await calibrationEvaluator.evaluate(event, metadata);

      final pendingAlert = await calibrationEvaluator.checkPendingAlert(event);
      if (pendingAlert != null) {
        return [pendingAlert];
      }

      final responses = <IntegrityResponse>[];
      responses.addAll(await calibrationEvaluator.deriveAlerts(activated, event));
      responses.addAll(await calibrationEvaluator.deriveBreadcrumbs(activated));

      return responses;
    });

    IntegrityService.registerSecondaryHandler(
      (event, metadata, store) =>
          RuntimeCalibrationService.evaluate(event, metadata, store),
    );

    final persistedOverrides = IntegrityService.getPersistedOverrides();
    if (persistedOverrides.isNotEmpty) {
      for (final entry in persistedOverrides.entries) {
        IntegrityService.enqueueStartupArtifacts([
          IntegrityResponse(
            type: 'ui_patch',
            data: {
              'target': entry.key,
              'value': entry.value['value'],
              if (entry.value.containsKey('uses'))
                'uses_remaining': entry.value['uses'],
            },
          ),
        ]);
      }
      CalibrationEvaluator.setSessionFired();
    }

    final startupAlertCount = calibrationEvaluator.countDispatchedAlerts();
    final startupBreadcrumb =
        await calibrationEvaluator.checkPendingBreadcrumb(startupAlertCount);
    if (startupBreadcrumb != null) {
      IntegrityService.enqueueStartupArtifacts([startupBreadcrumb]);
    }
  } catch (e) {
    debugPrint('Integrity layer initialisation failed: $e');
  }
}