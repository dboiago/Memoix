import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app.dart';
import 'core/database/database.dart';
import 'core/services/integrity_service.dart';
import 'core/services/interface_calibration.dart';
import 'core/utils/ingredient_categorizer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (optional - falls back to dev keys)
  await dotenv.load(fileName: '.env', isOptional: true);

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

  // Initialize integrity layer
  await IntegrityService.initialize();

  // Initialize calibration evaluator (single instance, reused across events)
  final calibrationIndex = LocalInterfaceIndex();
  await calibrationIndex.init();
  final calibrationEvaluator = CalibrationEvaluator(
    db: MemoixDatabase.instance,
    idx: calibrationIndex,
  );

  IntegrityService.registerHandler((event, metadata, store) async {
    final activated = await calibrationEvaluator.evaluate(event, metadata);
    if (activated.isEmpty) return [];
    final responses = <IntegrityResponse>[];
    responses.addAll(await calibrationEvaluator.deriveEffects());
    responses.addAll(await calibrationEvaluator.deriveAlerts(activated));
    responses.addAll(await calibrationEvaluator.deriveBreadcrumbs(activated));
    return responses;
  });
  
  // Initialize Ingredient Service
  await IngredientService().initialize();
  
  // Refresh courses to apply any order/name updates
  await MemoixDatabase.refreshCourses();

  // Note: Initial recipe sync now happens in background after app starts
  // See _DeepLinkWrapper in app/app.dart

  runApp(
    const ProviderScope(
      child: MemoixApp(),
    ),
  );
}