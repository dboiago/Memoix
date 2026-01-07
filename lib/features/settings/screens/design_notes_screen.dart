import 'package:flutter/material.dart';

/// Design Notes screen - factual descriptions of interaction patterns and features
///
/// Presents important UI behaviors and non-obvious features without instructional language.
/// Tone is matter-of-fact, not promotional or tutorial-like.
class DesignNotesScreen extends StatelessWidget {
  const DesignNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Design Notes'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Non-obvious behaviours and interactions in Memoix.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),

          // Notes
          const _DesignNote(
            title: 'Recipe Step Progress',
            description:
                'Tap any recipe step to mark it as completed. '
                'Completed steps appear crossed out, helping you track your place while cooking.',
          ),
          const _DesignNote(
            title: 'Side-by-Side Mode',
            description:
                'Designed for cooking on your phone, Side-by-Side Mode keeps ingredients and directions visible together. '
                'Each column scrolls independently, reducing the need to jump around while cooking.',
          ),
          const _DesignNote(
            title: 'Recipe Pairing',
            description:
                'Recipes can be paired with others (like a main dish with a side). '
                'Detail screens show both recipes you linked to, and recipes that link back to the current one.',
          ),
          const _DesignNote(
            title: 'Recipe Images',
            description:
                'Additional images can be added to a recipe and appear in a gallery at the bottom of the screen.',
            ),
            const _DesignNote(
            title: 'Step Images',
            description:
                'Images in the gallery can be linked to specific recipe steps. '
                'Linked steps show an image icon that opens the photo without scrolling, useful for visual checks while cooking.',
            ),
          const _DesignNote(
            title: 'Import Review',
            description:
                'Recipes imported from URLs or photos show a review screen before saving. '
                'Review and edit the imported data, add tags, and choose where to save it.',
          ),
          const _DesignNote(
            title: 'Physical Items',
            description:
                'Fields like Wood (Smoking), Glass (Drinks), and Equipment (Modernist) show suggestions as you type. '
                'You can also enter custom items not in the list.',
          ),
        const _DesignNote(
            title: 'Text Formatting',
            description:
                'Recipe names and ingredients are automatically title-cased. '
                'Fractions (1/2, 0.333) convert to symbols (½, ⅓). '
                'Measurement units are standardised (tablespoons → Tbsp, cups → C).',
          ),
          const _DesignNote(
            title: 'Compact View',
            description:
                'Enable Compact View in Settings to show more recipes per screen with tighter spacing.',
          ),
          const _DesignNote(
            title: 'Meal Planning',
            description:
                'Recipes in the meal plan can be dragged between days or courses to quickly adjust your schedule.',
            ),
          const _DesignNote(
            title: 'Kitchen Timers',
            description:
                'Timers continue running if you close the app. '
                'Multiple timers can run at the same time.',
          ),
          const _DesignNote(
            title: 'Scratch Pad',
            description:
                'Notes written in the scratch pad are saved automatically and remain available the next time you open the app.',
            ),
            const _DesignNote(
            title: 'Favourites',
            description:
                'Favourited recipes appear in a dedicated list for quick access, separate from your main recipe collection.',
            ),
          const _DesignNote(
            title: 'Offline Operation',
            description:
                'All recipes are stored locally on your device. '
                'Sync and external backup are optional features.',
          ),
          const _DesignNote(
            title: 'Course Organisation',
            description:
                'Recipes organise by course (Mains, Desserts, Drinks, etc.). '
                'Some categories (Pizza, Modernist, Smoking) use specialised layouts for their unique requirements.',
          ),
          const _DesignNote(
            title: 'Search Behaviour',
            description:
                'Search looks through recipe names, ingredients, and tags. '
                'Results with matching names appear before those with matching ingredients.',
          ),
          const _DesignNote(
            title: 'QR Code Sharing',
            description:
                'Share recipes as QR codes to transfer them between devices without internet. '
                'Scan the code in Memoix to import the recipe directly.',
          ),

          const SizedBox(height: 32),

          // Footer
          Center(
            child: Text(
              'For savv(or)y minds.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// A single design note item
class _DesignNote extends StatelessWidget {
  final String title;
  final String description;

  const _DesignNote({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

