import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/database/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database
  await MemoixDatabase.initialize();

  runApp(
    const ProviderScope(
      child: MemoixApp(),
    ),
  );
}
