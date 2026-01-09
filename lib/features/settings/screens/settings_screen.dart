import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/github_recipe_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/database/database.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/update_available_dialog.dart';
import '../services/recipe_backup_service.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../../app/routes/router.dart';

/// Provider for app preferences
final preferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Provider for hiding Memoix collection recipes (show only personal)
final hideMemoixRecipesProvider = StateNotifierProvider<HideMemoixRecipesNotifier, bool>((ref) {
  return HideMemoixRecipesNotifier();
});

class HideMemoixRecipesNotifier extends StateNotifier<bool> {
  static const _key = 'hide_memoix_recipes';

  HideMemoixRecipesNotifier() : super(false) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

/// Provider for compact list view preference
final compactViewProvider = StateNotifierProvider<CompactViewNotifier, bool>((ref) {
  return CompactViewNotifier();
});

class CompactViewNotifier extends StateNotifier<bool> {
  static const _key = 'compact_view';

  CompactViewNotifier() : super(false) { // Default to OFF
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false; // Default OFF
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

/// Provider for keeping screen on while viewing recipes
final keepScreenOnProvider = StateNotifierProvider<KeepScreenOnNotifier, bool>((ref) {
  return KeepScreenOnNotifier();
});

class KeepScreenOnNotifier extends StateNotifier<bool> {
  static const _key = 'keep_screen_on';

  KeepScreenOnNotifier() : super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true; // Default to ON
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

/// Provider for side-by-side mode - independent scrolling for ingredients/directions
final useSideBySideProvider = StateNotifierProvider<UseSideBySideNotifier, bool>((ref) {
  return UseSideBySideNotifier();
});

class UseSideBySideNotifier extends StateNotifier<bool> {
  static const _key = 'use_side_by_side_view';

  UseSideBySideNotifier() : super(false) { // Default to OFF (standard layout)
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false; // Default to OFF
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

/// Provider for showing header images on recipe detail screens
final showHeaderImagesProvider = StateNotifierProvider<ShowHeaderImagesNotifier, bool>((ref) {
  return ShowHeaderImagesNotifier();
});

class ShowHeaderImagesNotifier extends StateNotifier<bool> {
  static const _key = 'show_header_images';

  ShowHeaderImagesNotifier() : super(true) { // Default to ON (show header images)
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true; // Default to ON
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

/// Provider for auto-check for updates preference
final autoCheckUpdatesProvider = StateNotifierProvider<AutoCheckUpdatesNotifier, bool>((ref) {
  return AutoCheckUpdatesNotifier();
});

class AutoCheckUpdatesNotifier extends StateNotifier<bool> {
  static const _key = 'auto_check_updates';

  AutoCheckUpdatesNotifier() : super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true; // Default to ON
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncState = ref.watch(syncNotifierProvider);
    final hideMemoixRecipes = ref.watch(hideMemoixRecipesProvider);
    final compactView = ref.watch(compactViewProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Appearance', style: theme.textTheme.labelLarge),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('System Default'),
            value: ThemeMode.system,
            groupValue: ref.watch(themeModeProvider),
            onChanged: (m) => ref.read(themeModeProvider.notifier).setMode(m ?? ThemeMode.system),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
            groupValue: ref.watch(themeModeProvider),
            onChanged: (m) => ref.read(themeModeProvider.notifier).setMode(m ?? ThemeMode.system),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
            groupValue: ref.watch(themeModeProvider),
            onChanged: (m) => ref.read(themeModeProvider.notifier).setMode(m ?? ThemeMode.system),
          ),
          const Divider(),
          // Display section
          const _SectionHeader(title: 'Display'),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off),
            title: const Text('Hide Memoix Recipes'),
            subtitle: const Text(
              'Only show your personal recipes',
            ),
            value: hideMemoixRecipes,
            onChanged: (_) => ref.read(hideMemoixRecipesProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.view_column),
            title: const Text('Side-by-Side Mode'),
            subtitle: const Text('Split view with independent scrolling for ingredients and directions'),
            value: ref.watch(useSideBySideProvider),
            onChanged: (_) => ref.read(useSideBySideProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.view_compact),
            title: const Text('Compact View'),
            subtitle: const Text('Show more recipes per screen'),
            value: compactView,
            onChanged: (_) => ref.read(compactViewProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.image),
            title: const Text('Show Header Images'),
            subtitle: const Text('Display recipe images in detail headers'),
            value: ref.watch(showHeaderImagesProvider),
            onChanged: (_) => ref.read(showHeaderImagesProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lightbulb),
            title: const Text('Keep Screen On'),
            subtitle: const Text('Prevent screen from turning off while viewing recipes'),
            value: ref.watch(keepScreenOnProvider),
            onChanged: (_) => ref.read(keepScreenOnProvider.notifier).toggle(),
          ),

          const Divider(),

          // Personal Storage section
          const _SectionHeader(title: 'Backup'),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Personal Storage'),
            subtitle: const Text('Backup to your own cloud storage account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openExternalStorage(context),
          ),
          ListTile(
            leading: const Icon(Icons.folder_shared_outlined),
            title: const Text('Shared Storage'),
            subtitle: const Text('Access shared or managed recipe collections'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => AppRoutes.toRepositoryManagement(context),
          ),

          const Divider(),

          // Sync section
          const _SectionHeader(title: 'Sync & Updates'),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Sync Memoix Collection'),
            subtitle: const Text('Download latest recipes from the cloud'),
            trailing: syncState.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: syncState.isLoading
                ? null
                : () async {
                    await ref.read(syncNotifierProvider.notifier).sync();
                    final state = ref.read(syncNotifierProvider);
                    if (state.hasError) {
                      MemoixSnackBar.showError('Sync failed: ${state.error}');
                    } else {
                      MemoixSnackBar.showSuccess('Memoix collection synced successfully');
                    }
                  },
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('Check for App Updates'),
            subtitle: const Text('Download the latest version from GitHub'),
            onTap: () => _checkForUpdates(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: const Text('Auto-check for Updates'),
            subtitle: const Text('Check for updates when app launches'),
            value: ref.watch(autoCheckUpdatesProvider),
            onChanged: (_) => ref.read(autoCheckUpdatesProvider.notifier).toggle(),
          ),
          if (syncState.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Sync failed: ${syncState.error}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),

          const Divider(),

          // Data section
          const _SectionHeader(title: 'Data'),
          _ExportMyRecipesTile(ref: ref),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Import Recipes'),
            subtitle: const Text('Load recipes from a JSON file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final service = ref.read(recipeBackupServiceProvider);
                final count = await service.importRecipes();
                if (count > 0) {
                  MemoixSnackBar.showSuccess('Imported $count recipe${count == 1 ? '' : 's'}');
                } else {
                  MemoixSnackBar.show('No recipes imported');
                }
              } catch (e) {
                MemoixSnackBar.showError('Import failed: $e');
              }
            },
          ),
          // TODO(release): Remove this menu item before public release - dev/maintenance only
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Import from Folder'),
            subtitle: const Text('Restore all cuisines from folder'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final service = ref.read(recipeBackupServiceProvider);
                final results = await service.importFromFolder();
                if (results.isNotEmpty) {
                  final total = results.values.fold(0, (a, b) => a + b);
                  final cuisines = results.keys.join(', ');
                  MemoixSnackBar.showSuccess('Imported $total items from: $cuisines');
                } else {
                  MemoixSnackBar.show('No items imported');
                }
              } catch (e) {
                MemoixSnackBar.showError('Import failed: $e');
              }
            },
          ),

          const Divider(),

          // About section
          const _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Memoix'),
            onTap: () => _showAbout(context),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Source Code'),
            subtitle: const Text('View on GitHub'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final uri = Uri.parse('https://github.com/dboiago/Memoix');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                MemoixSnackBar.showError('Could not open GitHub');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Support Development'),
            subtitle: const Text('Buy me a coffee'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final uri = Uri.parse('https://www.buymeacoffee.com/dboiago');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                MemoixSnackBar.showError('Could not open link');
              }
            },
          ),

          const Divider(),

          // Danger zone (using secondary color for visibility)
          _SectionHeader(title: 'Danger Zone', colour: theme.colorScheme.secondary),
          ListTile(
            leading: Icon(Icons.delete_forever, color: theme.colorScheme.secondary),
            title: Text(
              'Clear All Data',
              style: TextStyle(color: theme.colorScheme.secondary),
            ),
            subtitle: const Text('Delete all recipes and reset app'),
            onTap: () => _confirmClearData(context, ref),
          ),

          const SizedBox(height: 32),

          // Version info
          Center(
            child: Text(
              'Memoix v1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Made with salt.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _openExternalStorage(BuildContext context) {
    AppRoutes.toExternalStorage(context);
  }

  void _showAbout(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = '${packageInfo.version} (${packageInfo.buildNumber})';

    if (!context.mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'Memoix',
      applicationVersion: version,
      applicationIcon: ColorFiltered(
        colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.secondary,
          BlendMode.srcIn,
        ),
        child: Image.asset(
          'assets/images/Memoix-mark-black-512.png',
          width: 80,
          height: 80,
          fit: BoxFit.contain,
        ),
      ),
      applicationLegalese: '© 2024-2025 Devon Boiago\n\n'
          'Licensed under PolyForm Noncommercial 1.0.0.\n'
          'Free for personal and educational use.',
      children: [
        const SizedBox(height: 24),
        const Text(
          'A recipe and food reference app for people who cook seriously.\n\n'
          'Flexible by design. Offline by default.',
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref) async {
    // Show loading indicator
    if (!context.mounted) return;
    MemoixSnackBar.show('Checking for updates...');

    final updateService = ref.read(updateServiceProvider);
    final appVersion = await updateService.checkForUpdate();

    if (!context.mounted) return;

    if (appVersion == null) {
      MemoixSnackBar.showError('Could not check for updates. Please try again.');
      return;
    }

    if (!appVersion.hasUpdate) {
      MemoixSnackBar.showSuccess('You\'re already running the latest version!');
      return;
    }

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

  void _confirmClearData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your personal recipes and settings. '
          'This action cannot be undone.\n\n'
          'Memoix collection recipes will be re-downloaded on next sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await MemoixDatabase.clearAll();
              // Invalidate all data providers to refresh UI
              ref.invalidate(coursesProvider);
              ref.invalidate(allRecipesProvider);
              ref.invalidate(availableCuisinesProvider);
              MemoixSnackBar.show('All data cleared');
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? colour;

  const _SectionHeader({required this.title, this.colour});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colour ?? Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

/// Export My Recipes tile with hidden advanced export on long-press
class _ExportMyRecipesTile extends StatefulWidget {
  final WidgetRef ref;

  const _ExportMyRecipesTile({required this.ref});

  @override
  State<_ExportMyRecipesTile> createState() => _ExportMyRecipesTileState();
}

class _ExportMyRecipesTileState extends State<_ExportMyRecipesTile> {
  Timer? _pressTimer;
  bool _isLongPressing = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isLongPressing = true);
    
    // Start timer for 5 seconds
    _pressTimer = Timer(const Duration(milliseconds: 5000), () {
      if (mounted) {
        setState(() => _isLongPressing = false);
        _exportAdvanced();
      }
    });
  }

  void _handleTapUp(TapUpDetails details) {
    if (_pressTimer?.isActive ?? false) {
      _pressTimer?.cancel();
      setState(() => _isLongPressing = false);
      _exportStandard();
    }
  }

  void _handleTapCancel() {
    _pressTimer?.cancel();
    setState(() => _isLongPressing = false);
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  Future<void> _exportStandard() async {
    try {
      final service = widget.ref.read(recipeBackupServiceProvider);
      final result = await service.exportRecipes(includeAll: false);
      // Only show success if export actually happened (user didn't cancel)
      if (result != null) {
        MemoixSnackBar.showSuccess('Recipes exported successfully');
      }
    } catch (e) {
      MemoixSnackBar.showError('Export failed: $e');
    }
  }

  Future<void> _exportAdvanced() async {
    try {
      final service = widget.ref.read(recipeBackupServiceProvider);
      final count = await service.exportByCourse();
      if (count != null && count > 0) {
        MemoixSnackBar.showSuccess('Advanced export complete: $count files');
      }
    } catch (e) {
      MemoixSnackBar.showError('Export failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _isLongPressing
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.transparent,
        ),
        child: ListTile(
          leading: const Icon(Icons.description),
          title: const Text('Export My Recipes'),
          subtitle: const Text('Single JSON file (excludes Memoix collection)'),
          trailing: const Icon(Icons.chevron_right),
          // Prevent ListTile's own tap handling
          onTap: null,
        ),
      ),
    );
  }
}
