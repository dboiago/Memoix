import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  if (hasSession) {
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

  // 3. Asset warm-up — kick off parallel preloading of the app logo and all
  //    course-icon SVGs into Flutter's PlatformAssetBundle byte cache.
  //    We use rootBundle.load() directly rather than svg.cache because
  //    SvgAssetLoader.cacheKey(null) in flutter_svg 2.x calls
  //    DefaultAssetBundle.of(null!) which may throw or produce keys that
  //    don't match render-time keys, corrupting the SVG picture cache.
  //    rootBundle.load() caches the raw bytes; SvgAssetLoader reads through
  //    that same cache via DefaultAssetBundle.of(context).load().
  final warmUpFuture = _warmSvgAssets();

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
  //    After sync() the Drift stream will emit the new rows, but that
  //    notification is async. We invalidate allRecipesProvider and re-await
  //    it so HomeScreen always receives AsyncData with real recipes on its
  //    very first build — never an empty list.
  final initialRecipes = await ref.read(allRecipesProvider.future);
  if (initialRecipes.isEmpty) {
    await ref.read(syncNotifierProvider.notifier).sync();
    ref.invalidate(allRecipesProvider);
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

/// Pre-populates Flutter's PlatformAssetBundle byte cache for the app logo
/// and every course-icon SVG. Using rootBundle.load() is safe with any version
/// of flutter_svg — SvgAssetLoader ultimately calls
/// DefaultAssetBundle.of(context).load(name) which is backed by rootBundle.
Future<void> _warmSvgAssets() async {
  const logo = 'assets/images/memoix-appicon-orange-1200.svg';
  final paths = <String>[logo, ...CourseIconWidget.svgAssets.values];
  await Future.wait(
    paths.map((path) async {
      try {
        await rootBundle.load(path);
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