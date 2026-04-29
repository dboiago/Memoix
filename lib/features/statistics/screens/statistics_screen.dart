import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cooking_stats.dart';
import '../../../app/theme/colours.dart';
import '../../../core/database/app_database.dart' hide Course;
import '../../recipes/models/course.dart';
import '../../recipes/models/cuisine.dart';

String _formatCookTime(int? minutes) {
  if (minutes == null) return '\u2014';
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

// ── Cook Map constants ────────────────────────────────────────────────────────
const Duration _cmThresholdSession = Duration(hours: 3);
const Duration _cmThresholdDay    = Duration(hours: 18);
const Duration _cmThresholdWeek   = Duration(days: 7);

const double _cmOpacityFull = 1.00;
const double _cmOpacityHigh = 0.70;
const double _cmOpacityMid  = 0.42;
const double _cmOpacityDim  = 0.18;

const double _cmChipSize    = 11.0;
const double _cmChipSpacing = 3.0;
const double _cmChipRadius  = 2.0;
// ─────────────────────────────────────────────────────────────────────────────

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(cookingStatsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Statistics'),
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          debugPrint('StatisticsScreen error: $err');
          return const Center(child: Text('Something went wrong. Please try restarting the app.'));
        },
        data: (stats) => _StatsContent(stats: stats),
      ),
    );
  }
}

class _StatsContent extends ConsumerWidget {
  final CookingStats stats;

  const _StatsContent({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final favouriteCount = ref.watch(totalFavouriteCountProvider)
        .maybeWhen(data: (n) => n.toString(), orElse: () => '—');

    if (stats.totalCooks == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No cooking data yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Made It" on recipes you cook\nto start tracking your stats!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overview cards in grid
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total Recipes',
                value: stats.totalRecipes.toString(),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Countries',
                value: stats.distinctCuisineCount.toString(),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Avg Cook Time',
                value: _formatCookTime(stats.avgCookTimeMinutes),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Favourites',
                value: favouriteCount,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Recipes by Course
        Text(
          'Recipes by Course',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        _CourseBarChart(data: stats.cooksByCourse),
        const SizedBox(height: 32),

        // Top Countries
        Text(
          'Top Countries',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        _CountryList(data: stats.cooksByCuisine),
        const SizedBox(height: 32),

        // Cook Map
        Text(
          'Cook Map',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        _CookMap(logs: stats.cookMapLogs),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseBarChart extends StatelessWidget {
  final Map<String, int> data;

  const _CourseBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    if (sorted.isEmpty) {
      return const _EmptySection(message: 'No course data yet');
    }

    final maxValue = sorted.first.value;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: sorted.map((entry) {
          final percentage = maxValue > 0 ? (entry.value / maxValue).toDouble() : 0.0;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      Course.displayNameFromSlug(entry.key),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      entry.value.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 4, // thinner bar
                    backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary, // warm color bar
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CountryList extends StatelessWidget {
  final Map<String, int> data;

  const _CountryList({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    if (sorted.isEmpty) {
      return const _EmptySection(message: 'No country data yet');
    }

    final maxValue = sorted.first.value;

    return Column(
      children: sorted.take(5).toList().asMap().entries.map((mapEntry) {
        final index = mapEntry.key;
        final entry = mapEntry.value;
        final cuisine = Cuisine.byCode(entry.key);
        final rank = index + 1;
        final percentage = maxValue > 0 ? (entry.value / maxValue).toDouble() : 0.0;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Rank circle
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.secondary,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Country name and bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cuisine?.name ?? entry.key,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          '${entry.value} recipes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: percentage,
                        minHeight: 4,
                        backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _CookMap extends StatelessWidget {
  final List<CookingLog> logs;

  const _CookMap({required this.logs});

  /// Returns the resolved base colour for [log], or null if the entry should
  /// be excluded (i.e. the fields required for colour resolution are absent).
  ///
  /// Food recipes: colour from continent-dot logic driven by [recipeCuisine],
  /// exactly as used in RecipeCard.
  /// Drinks: colour needs [subcategory] which is not stored in CookingLog
  /// → excluded silently.
  static Color? _resolveColour(CookingLog log) {
    final course = log.recipeCourse?.toLowerCase().trim();
    if (course == null) return null;
    final cuisine = log.recipeCuisine;
    switch (course) {
      case 'drinks':
        // subcategory (spirit) is not stored in CookingLog; use cuisine as the
        // continent-dot fallback, mirroring the card's own fallback behaviour.
        if (cuisine == null || cuisine.trim().isEmpty) return null;
        return MemoixColors.forContinentDot(cuisine);
      case 'modernist':
        if (cuisine == null) return null;
        return MemoixColors.forModernistType(cuisine);
      case 'sandwiches':
        if (cuisine == null) return null;
        if (cuisine == 'cheese') return MemoixColors.cheese;
        return MemoixColors.forProteinDot(cuisine);
      case 'pizzas':
        if (cuisine == null || cuisine.trim().isEmpty) return null;
        return MemoixColors.forPizzaBaseDot(cuisine);
      case 'smoking':
        if (cuisine == null) return null;
        return MemoixColors.forSmokedItemDot(cuisine);
      default:
        if (cuisine == null || cuisine.trim().isEmpty) return null;
        return MemoixColors.forContinentDot(cuisine);
    }
  }

  /// Opacity level based on time delta to the nearest neighbouring chip.
  static double _brightness(List<CookingLog> filtered, int index) {
    final t = filtered[index].cookedAt;
    final prev = index > 0
        ? t.difference(filtered[index - 1].cookedAt).abs()
        : null;
    final next = index < filtered.length - 1
        ? t.difference(filtered[index + 1].cookedAt).abs()
        : null;

    final Duration minDelta;
    if (prev != null && next != null) {
      minDelta = prev < next ? prev : next;
    } else {
      minDelta = prev ?? next ?? const Duration(days: 9999);
    }

    if (minDelta <= _cmThresholdSession) return _cmOpacityFull;
    if (minDelta <= _cmThresholdDay)     return _cmOpacityHigh;
    if (minDelta <= _cmThresholdWeek)    return _cmOpacityMid;
    return _cmOpacityDim;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pairs = <(CookingLog, Color)>[];
    for (final log in logs) {
      final colour = _resolveColour(log);
      if (colour != null) pairs.add((log, colour));
    }

    if (pairs.isEmpty) return const SizedBox.shrink();

    final filteredLogs = pairs.map((p) => p.$1).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = ((constraints.maxWidth + _cmChipSpacing) ~/
                  (_cmChipSize + _cmChipSpacing))
              .clamp(6, 999);

          // Build rows of exactly [cols] chips; final row has only remaining chips.
          final rows = <Widget>[];
          for (var start = 0; start < pairs.length; start += cols) {
            final end = (start + cols).clamp(0, pairs.length);
            rows.add(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(end - start, (j) {
                  final i       = start + j;
                  final base    = pairs[i].$2;
                  final opacity = _brightness(filteredLogs, i);
                  return Padding(
                    padding: EdgeInsets.only(
                      right: j < end - start - 1 ? _cmChipSpacing : 0,
                    ),
                    child: Container(
                      width: _cmChipSize,
                      height: _cmChipSize,
                      decoration: BoxDecoration(
                        color: base.withValues(alpha: opacity),
                        borderRadius: BorderRadius.circular(_cmChipRadius),
                      ),
                    ),
                  );
                }),
              ),
            );
            if (end < pairs.length) rows.add(SizedBox(height: _cmChipSpacing));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...rows,
              const SizedBox(height: 10),
              const _CookMapLegend(),
            ],
          );
        },
      ),
    );
  }
}

class _CookMapLegend extends StatelessWidget {
  const _CookMapLegend();

  static const _labels   = ['Same meal', 'Same day', 'Same week', 'Older'];
  static const _opacities = [_cmOpacityFull, _cmOpacityHigh, _cmOpacityMid, _cmOpacityDim];

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final neutral = theme.colorScheme.secondary;
    // Use a slightly smaller font on narrow screens so the legend fits in one line.
    final legendFontSize = MediaQuery.sizeOf(context).width < 400 ? 10.0 : 12.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: List.generate(_labels.length, (i) {
        return Padding(
          padding: EdgeInsets.only(left: i > 0 ? 8 : 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: neutral.withValues(alpha: _opacities[i]),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                i < _labels.length - 1 ? '${_labels[i]} ·' : _labels[i],
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: legendFontSize,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;

  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}
