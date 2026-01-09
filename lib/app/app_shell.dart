import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/screens/home_screen.dart';
import '../shared/widgets/app_drawer.dart';
import '../features/tools/recipe_comparison_screen.dart' show routeObserver;

class AppShellNavigator {
  AppShellNavigator._();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Check if the nested navigator can pop
  static bool canPop() {
    return navigatorKey.currentState?.canPop() ?? false;
  }
  
  /// Pop the nested navigator if possible, returns true if popped
  static Future<bool> maybePop() async {
    return await navigatorKey.currentState?.maybePop() ?? false;
  }
}

/// Observer to track navigation changes and trigger rebuilds
class _ShellNavigatorObserver extends NavigatorObserver {
  final VoidCallback onChanged;
  
  _ShellNavigatorObserver({required this.onChanged});
  
  @override
  void didPush(Route route, Route? previousRoute) => onChanged();
  
  @override
  void didPop(Route route, Route? previousRoute) => onChanged();
  
  @override
  void didRemove(Route route, Route? previousRoute) => onChanged();
  
  @override
  void didReplace({Route? newRoute, Route? oldRoute}) => onChanged();
}

/// Top-level app shell with persistent AppBar and Drawer.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  _ShellNavigatorObserver? _navObserver;
  bool _nestedCanPop = false;

  @override
  void initState() {
    super.initState();
    _navObserver = _ShellNavigatorObserver(onChanged: _onNavigationChanged);
  }
  
  void _onNavigationChanged() {
    // Schedule a microtask to check after the navigation completes
    Future.microtask(() {
      if (mounted) {
        final canPop = AppShellNavigator.canPop();
        if (canPop != _nestedCanPop) {
          setState(() {
            _nestedCanPop = canPop;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Ensure observer is initialized (handles hot reload edge cases)
    _navObserver ??= _ShellNavigatorObserver(onChanged: _onNavigationChanged);
    
    return PopScope(
      // Allow system pop only when at root (nothing to pop in nested navigator)
      canPop: !_nestedCanPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // System handled the pop (app will exit) - this happens when canPop is true
          return;
        }
        // System didn't pop because canPop was false - route to nested navigator
        await AppShellNavigator.maybePop();
      },
      child: Scaffold(
        drawer: const AppDrawer(),
        appBar: AppBar(
          title: const Text('Memoix'),
        ),
        body: Navigator(
          key: AppShellNavigator.navigatorKey,
          observers: [_navObserver!, routeObserver],
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
