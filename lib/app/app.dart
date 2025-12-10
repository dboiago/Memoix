import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/theme.dart';
import 'routes/router.dart';

class MemoixApp extends ConsumerWidget {
  const MemoixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Memoix',
      debugShowCheckedModeBanner: false,
      theme: MemoixTheme.light,
      darkTheme: MemoixTheme.dark,
      themeMode: ThemeMode.system,
      home: const AppRouter(),
    );
  }
}
