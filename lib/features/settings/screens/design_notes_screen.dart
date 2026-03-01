import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/integrity_service.dart';

class DesignNotesScreen extends ConsumerStatefulWidget {
  const DesignNotesScreen({super.key});

  @override
  ConsumerState<DesignNotesScreen> createState() => _DesignNotesScreenState();
}

class _DesignNotesScreenState extends ConsumerState<DesignNotesScreen> {
  final List<bool> _morseInput = [];
  DateTime? _tapStart;
  Timer? _morseResetTimer;

  static const _dotThreshold = 400;
  static const _resetTimeout = 5000;

  static const List<bool> _targetSequence = [
    false, false, false,          
    false, true,                  
    false, false, false, true,    
    false, false, false, true,    
    true, true, true,             
    false, false, true,           
    false, true, false,           
    true, false, true, true,      
  ];

  late final TapGestureRecognizer _ouRecognizer;

  @override
  void initState() {
    super.initState();
    _ouRecognizer = TapGestureRecognizer()
      ..onTapDown = (_) {
        _tapStart = DateTime.now();
        _morseResetTimer?.cancel();
      }
      ..onTapUp = (_) {
        if (_tapStart == null) return;
        final duration = DateTime.now().difference(_tapStart!).inMilliseconds;
        _tapStart = null;
        _morseResetTimer?.cancel();
        _morseResetTimer = Timer(const Duration(milliseconds: _resetTimeout), () {
          if (mounted) setState(() => _morseInput.clear());
        });
        setState(() => _morseInput.add(duration >= _dotThreshold));
        if (listEquals(_morseInput, _targetSequence)) {
          _onSequenceComplete();
        }
      };
  }

  void _onSequenceComplete() {
    _morseResetTimer?.cancel();
    _morseResetTimer = null;
    setState(() => _morseInput.clear());
    IntegrityService.resolveLegacyValue('legacy_ref_design').then((refDesign) {
      IntegrityService.reportEvent(
        'activity.content_verified',
        metadata: {'ref': refDesign ?? ''},
      ).then((_) => processIntegrityResponses(ref));
    });
  }

  @override
  void dispose() {
    _morseResetTimer?.cancel();
    _ouRecognizer.dispose();
    super.dispose();
  }

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
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Center(
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  children: [
                    const TextSpan(text: 'For savv'),
                    TextSpan(
                      text: '(ou)',
                      recognizer: _ouRecognizer,
                    ),
                    const TextSpan(text: 'ry minds.'),
                  ],
                ),
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

