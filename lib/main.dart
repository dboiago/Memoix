import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'core/database/database.dart';
import 'core/services/image_migration_service.dart';
import 'core/services/integrity_service.dart';
import 'core/services/interface_calibration.dart';
import 'core/services/schema_migration_service.dart';
import 'core/services/supabase_auth_service.dart';
import 'core/services/supabase_sync_service.dart';
import 'core/utils/ingredient_categorizer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (optional - falls back to dev keys)
  await dotenv.load(fileName: '.env', isOptional: true);

  // Initialize Supabase (non-fatal — app starts normally if keys are absent)
  try {
    final supabaseUrl = dotenv.maybeGet('SUPABASE_URL');
    final supabaseAnonKey = dotenv.maybeGet('SUPABASE_ANON_KEY');
    if (supabaseUrl != null && supabaseUrl.isNotEmpty &&
        supabaseAnonKey != null && supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    } else {
      debugPrint('Supabase: SUPABASE_URL or SUPABASE_ANON_KEY not set — skipping initialization.');
    }
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

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

  // Initialize local database
  await MemoixDatabase.initialize();

  // Migrate existing local image paths to blob storage (one-time, non-fatal)
  await ImageMigrationService.runIfNeeded();

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
    final breadcrumbResponse = await calibrationEvaluator.checkPendingBreadcrumb(alertsDispatched);
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

  await IngredientService().initialize();
  await MemoixDatabase.refreshCourses();

  // Note: Initial recipe sync now happens in background after app starts
  // See _DeepLinkWrapper in app/app.dart

  // Supabase background sync — fire-and-forget; sync() never throws.
  if (SupabaseAuthService.isSignedIn) {
    SupabaseSyncService.sync().then((_) {});
  }

  runApp(
    const ProviderScope(
      child: MemoixApp(),
    ),
  );
}