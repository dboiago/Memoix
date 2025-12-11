import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/screens/home_screen.dart';
import '../features/recipes/widgets/recipe_search_delegate.dart';
import '../shared/widgets/app_drawer.dart';

class AppShellNavigator {
  AppShellNavigator._();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

/// Top-level app shell with persistent AppBar and Drawer.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Recipe Book'),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                AppShellNavigator.navigatorKey.currentState?.maybePop();
              },
            );
          },
        ),
      ),
      body: Navigator(
        key: AppShellNavigator.navigatorKey,
        onGenerateRoute: (settings) {
          // Single stack starting at home; other routes are pushed via AppRoutes helpers.
          return MaterialPageRoute(builder: (_) => const HomeScreen());
        },
      ),
      backgroundColor: theme.colorScheme.surface,
    );
  }
}
