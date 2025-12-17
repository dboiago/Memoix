import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/github_recipe_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/database/database.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/update_available_dialog.dart';
import '../services/recipe_backup_service.dart';
import '../../recipes/repository/recipe_repository.dart';

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

  CompactViewNotifier() : super(true) { // Default to ON for data density
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true; // Default ON
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

/// Provider for showing images on recipe cards in lists
final showListImagesProvider = StateNotifierProvider<ShowListImagesNotifier, bool>((ref) {
  return ShowListImagesNotifier();
});

class ShowListImagesNotifier extends StateNotifier<bool> {
  static const _key = 'show_list_images';

  ShowListImagesNotifier() : super(false) { // Default to OFF (no images in lists)
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
            secondary: const Icon(Icons.view_compact),
            title: const Text('Compact View'),
            subtitle: const Text('Show more recipes per screen'),
            value: compactView,
            onChanged: (_) => ref.read(compactViewProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lightbulb),
            title: const Text('Keep Screen On'),
            subtitle: const Text('Prevent screen from turning off while viewing recipes'),
            value: ref.watch(keepScreenOnProvider),
            onChanged: (_) => ref.read(keepScreenOnProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.image),
            title: const Text('Show Images in Lists'),
            subtitle: const Text('Display recipe images on list cards'),
            value: ref.watch(showListImagesProvider),
            onChanged: (_) => ref.read(showListImagesProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.view_column),
            title: const Text('Side-by-Side Mode'),
            subtitle: const Text('Split view with independent scrolling for ingredients and directions'),
            value: ref.watch(useSideBySideProvider),
            onChanged: (_) => ref.read(useSideBySideProvider.notifier).toggle(),
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
                    if (context.mounted) {
                      final state = ref.read(syncNotifierProvider);
                      if (state.hasError) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sync failed: ${state.error}')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✓ Memoix collection synced successfully!')),
                        );
                      }
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
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Export All Recipes'),
            subtitle: const Text('Save your recipes as JSON'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final service = ref.read(recipeBackupServiceProvider);
                await service.exportRecipes(includeAll: false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Recipes exported successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Import Recipes'),
            subtitle: const Text('Load recipes from a JSON file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final service = ref.read(recipeBackupServiceProvider);
                final count = await service.importRecipes();
                if (context.mounted) {
                  if (count > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✓ Imported $count recipe${count == 1 ? '' : 's'}!')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No recipes imported')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Import failed: $e')),
                  );
                }
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open GitHub')),
                );
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open link')),
                );
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
              'Made with ❤️ for cooks',
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

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Memoix',
      applicationVersion: '1.0.0',
      applicationIcon: const FlutterLogo(size: 64),
      applicationLegalese: '© 2024-2025 Devon Boiago\nPolyForm Noncommercial License',
      children: [
        const SizedBox(height: 16),
        const Text(
          'A beautiful, open-source recipe manager for cooks. '
          'Organize your recipes, import from photos or websites, '
          'and share with friends and family.',
        ),
      ],
    );
  }

  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref) async {
    // Show loading indicator
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Checking for updates...'),
        duration: Duration(seconds: 3),
      ),
    );

    final updateService = ref.read(updateServiceProvider);
    final appVersion = await updateService.checkForUpdate();

    if (!context.mounted) return;

    if (appVersion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not check for updates. Please try again.'),
        ),
      );
      return;
    }

    if (!appVersion.hasUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You\'re already running the latest version!'),
        ),
      );
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
              ref.invalidate(categoriesProvider);
              ref.invalidate(allRecipesProvider);
              ref.invalidate(availableCuisinesProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              }
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
