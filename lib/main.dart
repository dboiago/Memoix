import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'core/database/database.dart';
import 'core/services/integrity_service.dart';
import 'core/services/interface_calibration.dart';
import 'core/services/schema_migration_service.dart';
import 'core/services/supabase_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (optional - falls back to dev keys)
  await dotenv.load(fileName: '.env', isOptional: true);

  // Initialize Supabase and local database in parallel
  final supabaseUrl = dotenv.maybeGet('SUPABASE_URL');
  final supabaseAnonKey = dotenv.maybeGet('SUPABASE_ANON_KEY');

  final supabaseFuture = (supabaseUrl != null && supabaseUrl.isNotEmpty &&
          supabaseAnonKey != null && supabaseAnonKey.isNotEmpty)
      ? Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
        ).catchError((e) {
          debugPrint('Supabase initialization failed: $e');
        })
      : Future.value().then((_) => debugPrint(
          'Supabase: SUPABASE_URL or SUPABASE_ANON_KEY not set — skipping initialization.',),);

  await Future.wait([
    supabaseFuture,
    MemoixDatabase.initialize(),
  ]);

  // Subscribe to auth state changes to trigger sync once the persisted
  // session is restored (or on fresh sign-in). Must be called before runApp.
  SupabaseAuthService.initSyncListener();

  // Configure desktop window
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(400, 600),
      center: true,
      title: 'Memoix',
      titleBarStyle: TitleBarStyle.normal,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Initialize integrity layer
  await IntegrityService.initialize();

  // Initialize calibration evaluator (single instance, reused across events)
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

  runApp(
    const ProviderScope(
      child: MemoixApp(),
    ),
  );
}