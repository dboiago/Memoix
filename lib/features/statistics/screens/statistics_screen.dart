import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cooking_stats.dart';
import '../../recipes/models/cuisine.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(cookingStatsProvider);

    return Scaffold(
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
        // Overview cards
        _StatsOverviewRow(stats: stats),
        const SizedBox(height: 24),

        // Top recipes
        Text(
          'Most Cooked Recipes',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (stats.topRecipes.isEmpty)
          const _EmptySection(message: 'Start cooking to see your favourites!')
        else
          ...stats.topRecipes.take(5).map((recipe) => _TopRecipeCard(
                recipe: recipe,
                rank: stats.topRecipes.indexOf(recipe) + 1,
              )),
        const SizedBox(height: 24),

        // By cuisine
        Text(
          'Cooking by Cuisine',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (stats.cooksByCuisine.isEmpty)
          const _EmptySection(message: 'No cuisine data yet')
        else
          _CuisineChart(data: stats.cooksByCuisine),
        const SizedBox(height: 24),

        // By course
        Text(
          'Cooking by Course',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (stats.cooksByCourse.isEmpty)
          const _EmptySection(message: 'No course data yet')
        else
          _CourseChart(data: stats.cooksByCourse),
        const SizedBox(height: 24),

        // Recent activity
        Text(
          'Recent Activity',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (stats.recentCooks.isEmpty)
          const _EmptySection(message: 'No recent cooking activity')
        else
          ...stats.recentCooks.map((log) => _RecentCookTile(log: log)),
      ],
    );
  }
}

class _StatsOverviewRow extends StatelessWidget {
  final CookingStats stats;

  const _StatsOverviewRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.restaurant,
            label: 'Total Cooks',
            value: stats.totalCooks.toString(),
            colour: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.menu_book,
            label: 'Recipes Tried',
            value: stats.uniqueRecipes.toString(),
            colour: Colors.green,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color colour;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.colour,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: colour),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colour,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRecipeCard extends StatelessWidget {
  final TopRecipe recipe;
  final int rank;

  const _TopRecipeCard({required this.recipe, required this.rank});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRankColour(rank),
          child: Text(
            '#$rank',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(recipe.recipeName),
        subtitle: Text('Last made: ${_formatDate(recipe.lastCooked)}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${recipe.cookCount}×',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        onTap: () {
          // Navigate to recipe
        },
      ),
    );
  }

  Color _getRankColour(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey.shade400;
      case 3:
        return Colors.brown.shade400;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _CuisineChart extends StatelessWidget {
  final Map<String, int> data;

  const _CuisineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = sorted.isNotEmpty ? sorted.first.value : 1;

    return Column(
      children: sorted.take(6).map((entry) {
        final cuisine = Cuisine.byCode(entry.key);
        final percentage = entry.value / maxValue;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Row(
                  children: [
                    Text(cuisine?.flag ?? '🍽️'),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        cuisine?.name ?? entry.key,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: percentage,
                      child: Container(
                        height: 24,
                        decoration: BoxDecoration(
                          color: cuisine?.colour ?? theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          entry.value.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
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

class _CourseChart extends StatelessWidget {
  final Map<String, int> data;

  const _CourseChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = data.values.fold<int>(0, (a, b) => a + b);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: data.entries.map((entry) {
        final percentage = total > 0 ? (entry.value / total * 100).round() : 0;
        return Chip(
          label: Text('${entry.key}: ${entry.value} ($percentage%)'),
        );
      }).toList(),
    );
  }
}

class _RecentCookTile extends StatelessWidget {
  final CookingLog log;

  const _RecentCookTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cuisine = log.recipeCuisine != null
        ? Cuisine.byCode(log.recipeCuisine!)
        : null;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cuisine?.colour.withOpacity(0.2) ??
            theme.colorScheme.surfaceContainerHighest,
        child: Text(cuisine?.flag ?? '🍽️'),
      ),
      title: Text(log.recipeName),
      subtitle: Text(_formatDateTime(log.cookedAt)),
      dense: true,
    );
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inHours < 24) {
      if (diff.inHours == 0) return '${diff.inMinutes} minutes ago';
      return '${diff.inHours} hours ago';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
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
