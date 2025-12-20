import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'theme/theme.dart';
import 'routes/router.dart';
import '../core/providers.dart';
import '../core/services/deep_link_service.dart';
import '../core/services/update_service.dart';
import '../core/services/github_recipe_service.dart';
import '../core/widgets/update_available_dialog.dart';
import '../core/widgets/memoix_snackbar.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/tools/timer_service.dart';

/// Global key for the root ScaffoldMessenger - use this to show snackbars after navigation
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Global navigator key for navigating from anywhere
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Update desktop window title bar color based on brightness
Future<void> _updateTitleBarColor(Brightness brightness) async {
  if (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux) return;
  
  final isDark = brightness == Brightness.dark;
  final bgColor = isDark ? MemoixTheme.darkSurface : MemoixTheme.lightSurface;
  
  await windowManager.setBackgroundColor(bgColor);
  
  // On Windows, also set the title bar text brightness
  if (Platform.isWindows) {
    await windowManager.setTitleBarStyle(
      TitleBarStyle.normal,
      windowButtonVisibility: true,
    );
    // Windows 11 DWM attribute for dark/light title bar
    await windowManager.setBrightness(brightness);
  }
}

class MemoixApp extends ConsumerStatefulWidget {
  const MemoixApp({super.key});

  @override
  ConsumerState<MemoixApp> createState() => _MemoixAppState();
}

class _MemoixAppState extends ConsumerState<MemoixApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Set initial title bar color after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTitleBarWithTheme();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // System theme changed - update title bar if following system
    final mode = ref.read(themeModeProvider);
    if (mode == ThemeMode.system) {
      _syncTitleBarWithTheme();
    }
  }

  void _syncTitleBarWithTheme() {
    final mode = ref.read(themeModeProvider);
    final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    
    final brightness = switch (mode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => platformBrightness,
    };
    
    _updateTitleBarColor(brightness);
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    
    // Update title bar color when theme mode changes
    ref.listen(themeModeProvider, (_, __) {
      _syncTitleBarWithTheme();
    });
    
    return MaterialApp(
      title: 'Memoix',
      debugShowCheckedModeBanner: false,
      theme: MemoixTheme.light,
      darkTheme: MemoixTheme.dark,
      themeMode: mode,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
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
    // Initialize deep links and check for updates after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deepLinkServiceProvider).initialize(context);
      _checkForUpdatesOnLaunch();
      _performBackgroundSync();
      _setupTimerAlarmCallbacks();
    });
  }

  /// Set up global timer alarm callbacks
  void _setupTimerAlarmCallbacks() {
    final timerService = ref.read(timerServiceProvider.notifier);
    timerService.onAlarmTriggered = (timer) {
      _showAlarmNotification(timer);
    };
    timerService.onAllAlarmsDismissed = () {
      MemoixSnackBar.clear();
    };
  }

  void _showAlarmNotification(TimerData timer) {
    MemoixSnackBar.showAlarm(
      timerLabel: timer.label,
      onDismiss: () {
        ref.read(timerServiceProvider.notifier).stopAlarm(timer.id);
      },
      onGoToAlarm: () {
        // Navigate to kitchen timer screen
        AppRoutes.toKitchenTimer(context);
      },
    );
  }

  /// Perform initial recipe sync in background without blocking UI
  void _performBackgroundSync() {
    // Trigger sync in background - won't block UI
    // The syncNotifierProvider handles errors gracefully
    // Use Future.microtask to ensure ref is available
    Future.microtask(() async {
      if (!mounted) return;
      try {
        final syncNotifier = ref.read(syncNotifierProvider.notifier);
        // Only sync if not already syncing
        final currentState = ref.read(syncNotifierProvider);
        if (!currentState.isLoading) {
          await syncNotifier.sync();
        }
      } catch (e) {
        // Silently fail - sync can happen later via manual trigger
        debugPrint('Background sync failed: $e');
      }
    });
  }

  Future<void> _checkForUpdatesOnLaunch() async {
    // Check if auto-check is enabled
    final autoCheck = ref.read(autoCheckUpdatesProvider);
    if (!autoCheck) return;

    final updateService = ref.read(updateServiceProvider);
    final appVersion = await updateService.checkForUpdate();

    if (!mounted || appVersion == null || !appVersion.hasUpdate) return;

    // Show update dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateAvailableDialog(
        currentVersion: appVersion.currentVersion,
        latestVersion: appVersion.latestVersion,
        releaseNotes: appVersion.releaseNotes,
        releaseUrl: appVersion.downloadUrl,
        onUpdate: () async {
          final success = await updateService.installUpdate(appVersion.downloadUrl);
          if (!success && ctx.mounted) {
            // Fallback: open browser if auto-install failed
            Navigator.pop(ctx);
            await updateService.openReleaseUrl(appVersion.downloadUrl);
          }
          return success;
        },
        onDismiss: () {
          Navigator.pop(ctx);
        },
      ),
    );
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
