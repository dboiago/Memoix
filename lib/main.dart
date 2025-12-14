import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database
  await MemoixDatabase.initialize();
  
  // Refresh categories to apply any order/name updates
  await MemoixDatabase.refreshCategories();

  // Note: Initial recipe sync now happens in background after app starts
  // See _DeepLinkWrapper in app/app.dart

  runApp(
    const ProviderScope(
      child: MemoixApp(),
    ),
  );
}
