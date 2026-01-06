import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/screens/home_screen.dart';
import '../shared/widgets/app_drawer.dart';

class AppShellNavigator {
  AppShellNavigator._();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Check if the nested navigator can pop
  static bool canPop() {
    return navigatorKey.currentState?.canPop() ?? false;
  }
  
  /// Pop the nested navigator if possible
  static void maybePop() {
    navigatorKey.currentState?.maybePop();
  }
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
    // PopScope intercepts system back gestures and routes them to the nested navigator
    return PopScope(
      canPop: false, // We handle all pops manually
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return; // Already handled
        
        // Route back gesture to nested navigator
        if (AppShellNavigator.canPop()) {
          AppShellNavigator.maybePop();
        } else {
          // At root of nested navigator - allow app to exit
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text('Memoix'),
        ),
        body: Navigator(
          key: AppShellNavigator.navigatorKey,
          onGenerateRoute: (settings) {
            // Single stack starting at home; other routes are pushed via AppRoutes helpers.
            return MaterialPageRoute(builder: (_) => const HomeScreen());
          },
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
    );
  }
}
