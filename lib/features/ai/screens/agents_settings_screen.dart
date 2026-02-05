import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai_settings_provider.dart';
import '../ai_provider.dart';
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
            value: settings.autoSelect,
            onChanged: notifier.setAutoSelect,
          ),

          if (!settings.autoSelect)
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('Preferred Provider'),
              subtitle: Text(
                _providerLabel(settings.preferredProvider),
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

          for (final entry in settings.providers.entries)
            _ProviderTile(
              provider: entry.key,
              config: entry.value,
              onToggle: (enabled) =>
                  notifier.setProviderEnabled(entry.key, enabled),
              onEditKey: () => _editApiKey(
                context,
                entry.key,
                entry.value,
                notifier,
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
    notifier,
  ) async {
    final controller = TextEditingController(text: config.apiKey);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_providerLabel(provider)} API Key'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'API Key',
          ),
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
      notifier.updateProviderConfig(
        provider,
        config.copyWith(apiKey: controller.text),
      );
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
    return SwitchListTile(
      secondary: const Icon(Icons.smart_toy_outlined),
      title: Text(_label(provider)),
      subtitle: Text(
        config.apiKey == null || config.apiKey!.isEmpty
            ? 'No API key set'
            : 'API key configured',
      ),
      value: config.enabled,
      onChanged: onToggle,
      onLongPress: onEditKey,
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
