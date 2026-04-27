import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/database.dart';
import '../../features/recipes/repository/recipe_repository.dart';
import '../services/integrity_service.dart';
import '../services/interface_calibration.dart';
import '../services/schema_migration_service.dart';
import '../services/supabase_auth_service.dart';
import '../services/supabase_secure_storage.dart';

final appInitProvider = FutureProvider<void>((ref) async {
  // 1. Initialize the local database. All other features depend on this.
  await MemoixDatabase.initialize();

  // 2. Strict privacy gate for Supabase.
  // The user "unlocks" shared storage by signing in via the hidden 8-second
  // long-press on the Shared Storage tile. Their session is then persisted
  // to SupabaseSecureStorage (flutter_secure_storage, key: supabase.auth.token).
  // We ONLY initialize the Supabase client when that token already exists -
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

  // 3. Integrity layer + calibration evaluator — fire-and-forget so the UI
  //    is never blocked waiting for these to complete at startup.
  unawaited(_initIntegrityLayer());
  await ref.read(allRecipesProvider.future);
});

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