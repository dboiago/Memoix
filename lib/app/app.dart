import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/theme.dart';
import 'routes/router.dart';
import '../core/providers.dart';
import '../core/services/deep_link_service.dart';
import '../core/services/update_service.dart';
import '../core/widgets/update_available_dialog.dart';
import '../features/settings/screens/settings_screen.dart';

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
    // Initialize deep links and check for updates after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deepLinkServiceProvider).initialize(context);
      _checkForUpdatesOnLaunch();
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
