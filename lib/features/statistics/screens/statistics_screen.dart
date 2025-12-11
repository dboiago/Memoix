import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cooking_stats.dart';
import '../../recipes/models/cuisine.dart';
import '../../../shared/widgets/app_drawer.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(cookingStatsProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (stats) => _StatsContent(stats: stats),
      ),
    );
  }
}

class _StatsContent extends StatelessWidget {
  final CookingStats stats;

  const _StatsContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                value: '78', // TODO: Get from actual data
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Countries',
                value: '12', // TODO: Get from actual data
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
                value: '35m', // TODO: Calculate from recipes
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'Favorites',
                value: stats.totalCooks.toString(),
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
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _CourseBarChart(data: stats.cooksByCourse),
        const SizedBox(height: 32),

        // Top Countries
        Text(
          'Top Countries',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _CountryList(data: stats.cooksByCuisine),
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
              fontWeight: FontWeight.bold,
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
                      entry.key,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
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
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.secondary.withValues(alpha: 0.4),
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: sorted.take(5).toList().asMap().entries.map((mapEntry) {
          final index = mapEntry.key;
          final entry = mapEntry.value;
          final cuisine = Cuisine.byCode(entry.key);
          final rank = index + 1;
          
          return ListTile(
            leading: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _getRankColor(rank).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Text(
                rank.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getRankColor(rank),
                ),
              ),
            ),
            title: Row(
              children: [
                if (cuisine != null) ...[
                  Text(cuisine.flag),
                  const SizedBox(width: 8),
                ],
                Text(
                  cuisine?.name ?? entry.key,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: Text(
              '${entry.value} recipes',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Color _getRankColor(int rank) {
    // Use a consistent, muted accent for rankings
    return Theme.of(context).colorScheme.secondary;
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
