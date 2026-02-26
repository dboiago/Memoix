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

          for (final provider in AiProvider.values) ...[
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
            ),
            // Model selector – shown only when the provider has a key
            if (settings.configFor(provider).hasKeyStored)
              _ModelSelector(
                provider: provider,
                config: settings.configFor(provider),
                onChanged: (model) => notifier.setModel(provider, model),
              ),
          ],

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Long-press a provider to edit its API key. '
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

    final result = await showDialog<String>(
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
          if (config.hasKeyStored)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'remove'),
              child: const Text('Remove Key'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == 'save') {
      final key = controller.text.trim();
      if (key.isNotEmpty) {
        await notifier.setApiKey(provider, key);
        MemoixSnackBar.showSuccess('API key saved');
      } else if (!config.hasKeyStored) {
        MemoixSnackBar.show('No key entered');
      }
    } else if (result == 'remove') {
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

  const _ProviderTile({
    required this.provider,
    required this.config,
    required this.onToggle,
    required this.onEditKey,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onEditKey,
      child: SwitchListTile(
        secondary: const Icon(Icons.smart_toy_outlined),
        title: Text(_label(provider)),
        subtitle: Text(
          config.hasKeyStored
              ? 'API key configured'
              : 'No API key set — long-press to add',
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

/// Dropdown for selecting a model within a provider.
///
/// Displayed directly below the provider tile when a key is stored.
class _ModelSelector extends StatelessWidget {
  final AiProvider provider;
  final AiProviderConfig config;
  final ValueChanged<String?> onChanged;

  const _ModelSelector({
    required this.provider,
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final models = aiProviderModels[provider] ?? [];
    if (models.isEmpty) return const SizedBox.shrink();

    final current = config.effectiveModel;

    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
      child: DropdownButtonFormField<String>(
        value: models.contains(current) ? current : models.first,
        decoration: InputDecoration(
          labelText: 'Model',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        style: theme.textTheme.bodyMedium,
        isExpanded: true,
        items: models
            .map((m) => DropdownMenuItem(
                  value: m,
                  child: Text(m, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (value) {
          if (value == null) return;
          // If the user picks the default, store null to track "default"
          final isDefault = value == defaultModelFor(provider);
          onChanged(isDefault ? null : value);
        },
      ),
    );
  }
}
