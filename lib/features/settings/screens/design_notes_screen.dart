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
              'Interaction patterns and non-obvious features in Memoix.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),

          // Notes
          const _DesignNote(
            title: 'Text Normalization',
            description:
                'Recipe names and ingredients are automatically title-cased. '
                'Fractions (1/2, 0.333) convert to unicode symbols (½, ⅓). '
                'Units standardize (tablespoons → Tbsp, cups → C).',
          ),
          const _DesignNote(
            title: 'Split View Layout',
            description:
                'Recipe detail screens use a fixed-height split container for ingredients and directions. '
                'Each column scrolls independently. Footer content (Notes, Gallery, Nutrition) sits below and scrolls with the page.',
          ),
          const _DesignNote(
            title: 'Recipe Pairing',
            description:
                'Pairings use parent-side storage only. Detail screens display both explicit pairings and inverse relationships (recipes that link to the current recipe).',
          ),
          const _DesignNote(
            title: 'Import Pipeline',
            description:
                'All imported text (OCR, URL, QR, deep links) passes through TextNormalizer and UnitNormalizer before saving. '
                'This ensures consistent formatting across import methods.',
          ),
          const _DesignNote(
            title: 'Color System',
            description:
                'UI chrome (buttons, backgrounds, borders) uses theme colors. '
                'Data-driven indicator dots use MemoixColors (continent dots, spirit dots, pizza base dots, etc.). '
                'Error/warning states map to the secondary color, not red.',
          ),
          const _DesignNote(
            title: 'SnackBar Pattern',
            description:
                'All user feedback uses MemoixSnackBar. Simple messages show for 2s. '
                'Actions (Undo, View) extend duration. "I made this" and "Saved" patterns have specific methods.',
          ),
          const _DesignNote(
            title: 'Physical Item Fields',
            description:
                'Wood (Smoking), Glass/Garnish (Drinks), and Equipment (Modernist) use autocomplete with free-form entry. '
                'Users see existing suggestions but can add new items not in the list.',
          ),
          const _DesignNote(
            title: 'Kitchen Timer Persistence',
            description:
                'Alarms managed by TimerService persist across app restarts via SharedPreferences. '
                'Multiple timers can run simultaneously.',
          ),
          const _DesignNote(
            title: 'Compact View',
            description:
                'Compact view is ON by default for data density. Shows more recipes per screen with tighter spacing.',
          ),
          const _DesignNote(
            title: 'Side-by-Side Mode',
            description:
                'When enabled, ingredients and directions appear in fixed-height side-by-side columns with independent scrolling. '
                'Footer content (notes, gallery) sits below and scrolls with the main page.',
          ),
          const _DesignNote(
            title: 'Header Images',
            description:
                'Recipe header images are ON by default. The MemoixHeader component is model-agnostic, accepting primitive values for use across all detail screens.',
          ),
          const _DesignNote(
            title: 'Offline-First Architecture',
            description:
                'All data stored in Isar (local database). Sync and external storage are opt-in features. No user accounts or server dependencies.',
          ),
          const _DesignNote(
            title: 'Course-Based Organization',
            description:
                'Recipes organize by course (Mains, Desserts, Drinks, etc.) with optional subcategories. '
                'Different domains (Pizza, Modernist, Smoking) use specialized models.',
          ),
          const _DesignNote(
            title: 'Search Strategy',
            description:
                'Recipe search delegates use case-insensitive matching across names, ingredients, and tags. '
                'Results sort by relevance with name matches weighted higher.',
          ),
          const _DesignNote(
            title: 'External Storage',
            description:
                'Backup system is provider-agnostic internally. Currently supports Google Drive. '
                'Data never touches Memoix servers—storage is in user-controlled locations.',
          ),
          const _DesignNote(
            title: 'Meal Plan Keys',
            description:
                'Meal plan entries use property-based keys (date + course + recipeId) instead of index-based keys. '
                'This prevents issues when deleting multiple items.',
          ),
          const _DesignNote(
            title: 'Import Review Pattern',
            description:
                'URL and OCR imports show a review screen before saving. Users can edit imported data, add tags, and select destination course.',
          ),
          const _DesignNote(
            title: 'QR Code Sharing',
            description:
                'Recipes can be shared as QR codes. Data is compressed with gzip and encoded. '
                'Maximum payload: 4,096 characters. Decompression limits: input ≤ 500 KB, output ≤ 5 MB.',
          ),
          const _DesignNote(
            title: 'Deep Link Support',
            description:
                'Recipes can be shared via memoix:// deep links. Links open directly to import review screens.',
          ),
          const _DesignNote(
            title: 'HTTP Security Limits',
            description:
                'URL imports enforce a 10 MB response limit via streaming. Binary content types (PDF, images, video) are rejected immediately upon header receipt.',
          ),
          const _DesignNote(
            title: 'Hidden Advanced Export',
            description:
                'Long-press (5s) on "Export My Recipes" in Settings → Data triggers an advanced export that includes all Memoix reference data organized by course.',
          ),

          const SizedBox(height: 32),

          // Footer
          Center(
            child: Text(
              'Memoix is designed for chefs and serious hobbyists.',
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
