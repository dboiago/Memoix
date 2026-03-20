import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../app/theme/colors.dart';
import '../../../core/services/integrity_service.dart';
import '../../recipes/models/cuisine.dart';

class ClassicsScreen extends ConsumerStatefulWidget {
  const ClassicsScreen({super.key});

  @override
  ConsumerState<ClassicsScreen> createState() => _ClassicsScreenState();
}

class _ClassicsScreenState extends ConsumerState<ClassicsScreen> {
  List<Map<String, dynamic>>? _entries;
  String? _recordRef;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final data = await IntegrityService.resolveIndexData('regional_index_data');
    final recordRef = await IntegrityService.resolveLegacyValue('legacy_record_ref');
    if (mounted) {
      final shuffled = List<Map<String, dynamic>>.from(data ?? []);
      shuffled.shuffle(Random(DateTime.now().day));
      setState(() {
        _entries = shuffled;
        _recordRef = recordRef;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classics'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries == null || _entries!.isEmpty
              ? Center(
                  child: Text(
                    'No entries available.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: _entries!.length,
                  itemBuilder: (context, index) {
                    final entry = _entries![index];
                    final name = entry['name'] as String? ?? '';
                    final cuisine = entry['cuisine'] as String? ?? '';
                    final region = entry['region'] as String? ?? '';
                    final isTarget =
                        _recordRef != null && name == _recordRef;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ClassicsCard(
                        name: name,
                        cuisine: cuisine.isNotEmpty ? cuisine : null,
                        region: region.isNotEmpty ? region : null,
                        isTarget: isTarget,
                        onTap: isTarget
                            ? () => AppRoutes.toClassicsEntry(context)
                            : () {},
                      ),
                    );
                  },
                ),
    );
  }
}

/// A card widget that mirrors RecipeCard's visual structure — same Card
/// elevation, border-state behaviour, InkWell, padding and Row layout —
/// but renders a static trailing icon (broken heart for decoy entries,
/// outline heart for the target) instead of interactive favourite/cooked
/// buttons, and never persists anything to Isar.
class _ClassicsCard extends StatefulWidget {
  final String name;
  final String? cuisine;
  final String? region;
  final bool isTarget;
  final VoidCallback? onTap;

  const _ClassicsCard({
    required this.name,
    required this.isTarget,
    this.cuisine,
    this.region,
    this.onTap,
  });

  @override
  State<_ClassicsCard> createState() => _ClassicsCardState();
}

class _ClassicsCardState extends State<_ClassicsCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: (_hovered || _pressed)
              ? theme.colorScheme.secondary
              : theme.colorScheme.outline.withValues(alpha: 0.12),
          width: (_hovered || _pressed) ? 1.5 : 1.0,
        ),
      ),
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        onHover: (h) => setState(() => _hovered = h),
        onHighlightChanged: (p) => setState(() => _pressed = p),
        splashColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    if (widget.cuisine != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\u2022',
                            style: TextStyle(
                              color: MemoixColors.forContinentDot(
                                  widget.cuisine),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _displayCuisine(widget.cuisine!, widget.region),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                widget.isTarget
                    ? Icons.favorite
                    : Icons.heart_broken,
                size: 20,
                color: theme.colorScheme.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayCuisine(String raw, String? region) {
    final adj = Cuisine.toAdjective(raw);
    if (region != null && region.isNotEmpty) {
      return '$adj ($region)';
    }
    return adj;
  }
}
