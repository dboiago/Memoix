import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/github_recipe_service.dart';
import '../../../core/database/database.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncState = ref.watch(syncNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Sync section
          _SectionHeader(title: 'Sync'),
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
                : () => ref.read(syncNotifierProvider.notifier).sync(),
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
          _SectionHeader(title: 'Data'),
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Export All Recipes'),
            subtitle: const Text('Save your recipes as JSON'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement export
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export coming soon!')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Import Recipes'),
            subtitle: const Text('Load recipes from a JSON file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement import
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Import coming soon!')),
              );
            },
          ),

          const Divider(),

          // About section
          _SectionHeader(title: 'About'),
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
            onTap: () {
              // Open GitHub URL
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Support Development'),
            subtitle: const Text('Buy me a coffee'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // Open donation link
            },
          ),

          const Divider(),

          // Danger zone
          _SectionHeader(title: 'Danger Zone', color: theme.colorScheme.error),
          ListTile(
            leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
            title: Text(
              'Clear All Data',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            subtitle: const Text('Delete all recipes and reset app'),
            onTap: () => _confirmClearData(context),
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
              'Made with ❤️ for home cooks',
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
      applicationLegalese: '© 2024 Memoix Contributors\nLicensed under MIT',
      children: [
        const SizedBox(height: 16),
        const Text(
          'A beautiful, open-source recipe manager for home cooks. '
          'Organize your recipes, import from photos or websites, '
          'and share with friends and family.',
        ),
      ],
    );
  }

  void _confirmClearData(BuildContext context) {
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
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionHeader({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color ?? Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
