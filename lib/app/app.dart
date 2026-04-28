import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/theme.dart';
import 'routes/router.dart';
import '../core/providers.dart';
import '../core/providers/app_init_provider.dart';
import '../core/services/deep_link_service.dart';
import '../core/services/integrity_service.dart';
import '../core/services/memoix_recipe_service.dart';
import '../core/widgets/memoix_snackbar.dart';
import '../features/tools/timer_service.dart';
import '../features/personal_storage/services/personal_storage_service.dart';
import '../core/database/database.dart';
import '../core/services/image_migration_service.dart';

/// Global key for the root ScaffoldMessenger - use this to show snackbars after navigation
final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Global navigator key for navigating from anywhere
final rootNavigatorKey = GlobalKey<NavigatorState>();

class MemoixApp extends ConsumerWidget {
  const MemoixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final init = ref.watch(appInitProvider);
    return MaterialApp(
      title: 'Memoix',
      debugShowCheckedModeBanner: false,
      theme: MemoixTheme.light,
      darkTheme: MemoixTheme.dark,
      themeMode: mode,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: init.when(
        loading: () => Scaffold(
          backgroundColor: const Color(0xFF242424),
          body: Center(
            child: SvgPicture.asset(
              'assets/images/memoix-appicon-orange-1200.svg',
              width: 220,
            ),
          ),
        ),
        data: (_) => const _DeepLinkWrapper(child: AppRouter()),
        error: (e, _) => Scaffold(
          backgroundColor: const Color(0xFF242424),
          body: Center(child: Text('Initialization error:\n$e', style: const TextStyle(color: Colors.white))),
        ),
      ),
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
      _performBackgroundSync();
      _setupTimerAlarmCallbacks();
      _triggerPersonalStorageSync();
      _deferredInit();
    });
  }

  Future<void> _deferredInit() async {
    // IngredientService is now initialised inside appInitProvider (concurrently
    // with SVG warm-up) so that the 2-4 s of GZip + JSON work happens during
    // the splash rather than freezing the UI after first interaction.
    await ImageMigrationService.runIfNeeded();
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

  /// Perform initial recipe sync only when the bundled recipe version has
  /// changed since the last sync. Comparing a single integer stored in
  /// SharedPreferences against the version in assets/recipes/version.json
  /// eliminates the 500+ sequential DB round-trips that previously ran on
  /// every launch (one getRecipeByUuid existence check per bundled recipe),
  /// which was the primary cause of the 4-7 second blank-grid period.
  void _performBackgroundSync() {
    Future.microtask(() async {
      if (!mounted) return;
      try {
        // 1. Read the bundled recipe version (fast — already in rootBundle cache).
        final versionJson = await rootBundle.loadString('assets/recipes/version.json');
        final bundledVersion = (jsonDecode(versionJson) as Map<String, dynamic>)['version'] as int? ?? 0;

        // 2. Read the last version we successfully synced.
        final prefs = await SharedPreferences.getInstance();
        final lastSynced = prefs.getInt('memoix_recipe_sync_version') ?? -1;

        if (bundledVersion <= lastSynced) {
          // Nothing new — skip the entire sync loop.
          return;
        }

        // 3. New version detected: run sync and persist the new version on success.
        final syncNotifier = ref.read(syncNotifierProvider.notifier);
        final currentState = ref.read(syncNotifierProvider);
        if (!currentState.isLoading) {
          await syncNotifier.sync();
          await prefs.setInt('memoix_recipe_sync_version', bundledVersion);
        }
      } catch (e) {
        debugPrint('Background sync failed: $e');
      }
    });
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
