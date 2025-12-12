import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/theme.dart';
import 'routes/router.dart';
import '../core/providers.dart';
import '../core/services/deep_link_service.dart';

class MemoixApp extends ConsumerWidget {
  const MemoixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Memoix',
      debugShowCheckedModeBanner: false,
      theme: MemoixTheme.light,
      darkTheme: MemoixTheme.dark,
      themeMode: mode,
      home: const _DeepLinkWrapper(child: AppRouter()),
    );
  }
}

/// Wrapper widget that initializes deep link handling
class _DeepLinkWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const _DeepLinkWrapper({required this.child});

  @override
  ConsumerState<_DeepLinkWrapper> createState() => _DeepLinkWrapperState();
}

class _DeepLinkWrapperState extends ConsumerState<_DeepLinkWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize deep links after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deepLinkServiceProvider).initialize(context);
    });
  }

  @override
  void dispose() {
    ref.read(deepLinkServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
