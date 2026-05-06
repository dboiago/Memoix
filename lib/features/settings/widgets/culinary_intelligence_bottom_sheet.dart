import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/settings_screen.dart';

/// One-time opt-in prompt for the Culinary Intelligence RAG pipeline.
///
/// Shown automatically when the user has meaningful usage and has not yet
/// been presented with this choice. Displayed via [showContributeRecipesSheet].
///
/// Privacy rules enforced by the sheet:
/// - Tapping 'Enable' sets the master switch and marks the prompt as seen.
/// - Tapping 'Not now' only marks the prompt as seen (no data is ever shared).
/// - Tapping 'Learn more' opens the details screen and does NOT dismiss the sheet
///   or modify any preference.
class ContributeRecipesBottomSheet extends ConsumerWidget {
  const ContributeRecipesBottomSheet({super.key});

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
              'Contribute to the recipe dataset',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'I\'m building a culinary reference system trained on real recipes rather '
              'than internet scrapes. If you enable this, recipes you save and refine '
              'will be sent to a private dataset - ingredients, instructions, notes '
              'and basic stats like cook count. \n\n'
              'No account is created. No device identifier is attached. Recipes marked '
              'as Hidden are never transmitted regardless of this setting.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Built for cooking, not tracking.',
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ContributeRecipesInfoScreen(),
                  ),
                ),
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

/// Shows [ContributeRecipesBottomSheet] as a modal bottom sheet.
///
/// Marks the prompt as seen via [hasSeenIntelligenceOptInProvider] when the
/// sheet is dismissed, regardless of how the user closes it (button tap,
/// background tap, or swipe-down).
Future<void> showContributeRecipesSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ContributeRecipesBottomSheet(),
  ).whenComplete(() async {
    await ref.read(hasSeenIntelligenceOptInProvider.notifier).markSeen();
  });
}
