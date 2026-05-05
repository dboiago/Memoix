import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/settings_screen.dart';

/// One-time opt-in prompt for the Culinary Intelligence RAG pipeline.
///
/// Shown automatically when the user has meaningful usage and has not yet
/// been presented with this choice. Displayed via [showCulinaryIntelligenceSheet].
///
/// Privacy rules enforced by the sheet:
/// - Tapping 'Enable' sets the master switch and marks the prompt as seen.
/// - Tapping 'Not now' only marks the prompt as seen (no data is ever shared).
/// - Tapping 'Learn more' opens the project URL and does NOT dismiss the sheet
///   or modify any preference.
class CulinaryIntelligenceBottomSheet extends ConsumerWidget {
  const CulinaryIntelligenceBottomSheet({super.key});

  static const _learnMoreUrl = 'https://github.com/dboiago/Memoix';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Improve recipe understanding',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'I\'m working on a privacy-focused system for recipe adaptation, '
              'substitutions, and scaling.\n\n'
              'If enabled, selected recipes and basic recipe data (such as '
              'favourites or made status) may be used to support this work over time.\n\n'
              'Nothing is shared unless you turn it on. No data unrelated to your '
              'recipes is collected.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Built for better recipes, not usage tracking.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await ref
                      .read(contributeToIntelligenceProvider.notifier)
                      .toggle();
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Enable'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Not now'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  final uri = Uri.parse(_learnMoreUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Text(
                  'Learn more',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [CulinaryIntelligenceBottomSheet] as a modal bottom sheet.
///
/// Marks the prompt as seen via [hasSeenIntelligenceOptInProvider] when the
/// sheet is dismissed, regardless of how the user closes it (button tap,
/// background tap, or swipe-down).
Future<void> showCulinaryIntelligenceSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const CulinaryIntelligenceBottomSheet(),
  ).whenComplete(() async {
    await ref.read(hasSeenIntelligenceOptInProvider.notifier).markSeen();
  });
}
