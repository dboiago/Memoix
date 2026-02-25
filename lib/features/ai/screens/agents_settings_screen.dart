import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/memoix_snackbar.dart';
import '../ai_settings_provider.dart';
import '../../import/ai/ai_provider.dart';
import '../ai_provider_config.dart';

class AgentsSettingsScreen extends ConsumerWidget {
  const AgentsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiSettingsProvider);
    final notifier = ref.read(aiSettingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agents'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // Auto-select section
          _SectionHeader(title: 'Behavior'),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: const Text('Auto-select Provider'),
            subtitle: const Text(
              'Choose the best AI automatically based on input type',
            ),
            value: settings.autoSelectProvider,
            onChanged: notifier.setAutoSelectProvider,
          ),

          if (!settings.autoSelectProvider)
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('Preferred Provider'),
              subtitle: Text(
                settings.preferredProvider != null
                    ? _providerLabel(settings.preferredProvider!)
                    : 'Not set',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickPreferredProvider(
                context,
                settings,
                notifier,
              ),
            ),

          const Divider(),

          // Providers section
          _SectionHeader(title: 'Providers'),

          for (final provider in AiProvider.values)
            _ProviderTile(
              provider: provider,
              config: settings.configFor(provider),
              onToggle: (enabled) =>
                  notifier.setProviderEnabled(provider, enabled),
              onEditKey: () => _editApiKey(
                context,
                provider,
                settings.configFor(provider),
                notifier,
              ),
              onClearKey: () => _clearApiKey(
                context,
                provider,
                notifier,
              ),
            ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tap a provider to edit its API key. '
              'Keys are stored securely on your device and never sent anywhere except the provider\'s own API.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static String _providerLabel(AiProvider provider) {
    switch (provider) {
      case AiProvider.openai:
        return 'ChatGPT (OpenAI)';
      case AiProvider.claude:
        return 'Claude (Anthropic)';
      case AiProvider.gemini:
        return 'Gemini (Google)';
    }
  }

  Future<void> _pickPreferredProvider(
    BuildContext context,
    settings,
    notifier,
  ) async {
    final selected = await showDialog<AiProvider>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Preferred Provider'),
        children: AiProvider.values.map((p) {
          return RadioListTile<AiProvider>(
            title: Text(_providerLabel(p)),
            value: p,
            groupValue: settings.preferredProvider,
            onChanged: (v) => Navigator.pop(ctx, v),
          );
        }).toList(),
      ),
    );

    if (selected != null) {
      notifier.setPreferredProvider(selected);
    }
  }

  Future<void> _editApiKey(
    BuildContext context,
    AiProvider provider,
    AiProviderConfig config,
    AiSettingsNotifier notifier,
  ) async {
    final controller = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_providerLabel(provider)} API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(
                labelText: config.hasKeyStored
                    ? 'Enter new key (leave blank to keep current)'
                    : 'API Key',
              ),
            ),
            if (config.hasKeyStored) ...[
              const SizedBox(height: 8),
              Text(
                'A key is already stored.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final key = controller.text.trim();
      if (key.isNotEmpty) {
        await notifier.setApiKey(provider, key);
        MemoixSnackBar.showSuccess('API key saved');
      } else if (!config.hasKeyStored) {
        MemoixSnackBar.show('No key entered');
      }
      // If key is empty but one was already stored, keep the existing key
    }
  }

  Future<void> _clearApiKey(
    BuildContext context,
    AiProvider provider,
    AiSettingsNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove API Key?'),
        content: Text(
          'This will remove the stored key for ${_providerLabel(provider)} '
          'and disable the provider.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await notifier.clearApiKey(provider);
      MemoixSnackBar.show('API key removed');
    }
  }
}

class _ProviderTile extends StatelessWidget {
  final AiProvider provider;
  final AiProviderConfig config;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditKey;
  final VoidCallback onClearKey;

  const _ProviderTile({
    required this.provider,
    required this.config,
    required this.onToggle,
    required this.onEditKey,
    required this.onClearKey,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEditKey,
      onLongPress: config.hasKeyStored ? onClearKey : null,
      child: SwitchListTile(
        secondary: const Icon(Icons.smart_toy_outlined),
        title: Text(_label(provider)),
        subtitle: Text(
          config.hasKeyStored
              ? 'API key configured'
              : 'No API key set',
        ),
        value: config.enabled,
        onChanged: onToggle,
      ),
    );
  }

  static String _label(AiProvider provider) {
    switch (provider) {
      case AiProvider.openai:
        return 'ChatGPT (OpenAI)';
      case AiProvider.claude:
        return 'Claude';
      case AiProvider.gemini:
        return 'Gemini';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
