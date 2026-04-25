import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'theme/theme.dart';
import 'routes/router.dart';
import '../core/providers.dart';
import '../core/services/deep_link_service.dart';
import '../core/services/integrity_service.dart';
import '../core/services/update_service.dart';
import '../core/services/memoix_recipe_service.dart';
import '../core/widgets/update_available_dialog.dart';
import '../core/widgets/memoix_snackbar.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/tools/timer_service.dart';
import '../features/personal_storage/services/personal_storage_service.dart';
import '../core/database/database.dart';
import '../core/services/image_migration_service.dart';
import '../core/utils/ingredient_categorizer.dart';

/// Global key for the root ScaffoldMessenger - use this to show snackbars after navigation
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Global navigator key for navigating from anywhere
final rootNavigatorKey = GlobalKey<NavigatorState>();

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

// Search your memory. Find your identity. Reflect on the origin.
const _origin = 'Cl ul xkzqvd, vvwrchmz yph hwh zxpfmfoq xpc gf gch: "kzkf wv aqvpo Q vqyf kxkz."';

class _DeepLinkWrapperState extends ConsumerState<_DeepLinkWrapper>
  with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      processIntegrityResponses(ref);
      ref.read(deepLinkServiceProvider).initialize(context);
      if (!isPlayStore) _checkForUpdatesOnLaunch();
      _performBackgroundSync();
      _setupTimerAlarmCallbacks();
      _triggerPersonalStorageSync();
      _deferredInit();
    });
  }

  Future<void> _deferredInit() async {
    await ImageMigrationService.runIfNeeded();
    await IngredientService().initialize();
    await MemoixDatabase.refreshCourses();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final storageService = ref.read(personalStorageServiceProvider);
    
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background - push any pending changes
      storageService.onAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      // App coming back to foreground - could trigger pull if needed
      // Currently handled by onAppLaunched on startup
      processIntegrityResponses(ref);
    }
  }

  /// Trigger personal storage pull on app launch (if connected + automatic mode)
  void _triggerPersonalStorageSync() {
    Future.microtask(() async {
      if (!mounted) return;
      try {
        final storageService = ref.read(personalStorageServiceProvider);
        await storageService.onAppLaunched();
      } catch (e) {
        debugPrint('Personal storage sync on launch failed: $e');
      }
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
    final AppVersion? appVersion;
    try {
      appVersion = await updateService.checkForUpdate();
    } catch (e) {
      debugPrint('Update check on launch failed: $e');
      return;
    }

    if (!mounted || appVersion == null || !appVersion.hasUpdate) return;
    final validVersion = appVersion;

    // Show update dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateAvailableDialog(
        currentVersion: validVersion.currentVersion,
        latestVersion: validVersion.latestVersion,
        releaseNotes: validVersion.releaseNotes,
        releaseUrl: validVersion.downloadUrl,
        onUpdate: () async {
          final success = await updateService.installUpdate(validVersion.downloadUrl);
          if (!success && ctx.mounted) {
            // Fallback: open browser if auto-install failed
            Navigator.pop(ctx);
            await updateService.openReleaseUrl(validVersion.downloadUrl);
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
    WidgetsBinding.instance.removeObserver(this);
    ref.read(deepLinkServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
