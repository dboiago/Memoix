import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/collection_utils.dart';
import '../../../shared/widgets/memoix_empty_state.dart';
import '../../../shared/widgets/memoix_filter_chip.dart';
import '../../../shared/widgets/memoix_search_bar.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/cellar_entry.dart';
import '../repository/cellar_repository.dart';
import '../widgets/cellar_card.dart';

/// Cellar list screen - displays cellar entries
class CellarListScreen extends ConsumerStatefulWidget {
  const CellarListScreen({super.key});

  @override
  ConsumerState<CellarListScreen> createState() => _CellarListScreenState();
}

class _CellarListScreenState extends ConsumerState<CellarListScreen> {
  String? _selectedCategory;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entriesAsync = ref.watch(allCellarEntriesProvider);
    final isCompact = ref.watch(compactViewProvider);
    final hideMemoix = ref.watch(hideMemoixRecipesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Cellar',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) {
          debugPrint('CellarListScreen error: $err');
          return const Center(child: Text('Something went wrong. Please try restarting the app.'));
        },
        data: (allEntries) {
          // Apply hide memoix filter
          final visibleEntries = hideMemoix
              ? allEntries.where((e) => e.source != CellarSource.memoix.name).toList()
              : allEntries;

          // Get categories that have entries
          final availableCategories = extractUniqueStrings(visibleEntries, (e) => e.category);

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: MemoixSearchBar(
                  hintText: 'Search cellar...',
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),

              // Category filter chips
              if (availableCategories.isNotEmpty)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip(null, visibleEntries.length), // "All" chip
                      ...availableCategories.map((category) {
                        final count = visibleEntries.where((e) => e.category == category).length;
                        return _buildFilterChip(category, count);
                      }),
                    ],
                  ),
                ),

              // Entry list
              Expanded(
                child: _buildEntryList(visibleEntries, isCompact),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AppRoutes.toCellarEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _buildFilterChip(String? category, int count) {
    return MemoixFilterChip(
      value: category,
      isSelected: _selectedCategory == category,
      onSelected: (selected) {
        setState(() => _selectedCategory = selected ? category : null);
      },
    );
  }

  Widget _buildEntryList(List<CellarEntry> allEntries, bool isCompact) {
    // Filter by category
    var entries = _selectedCategory == null
        ? allEntries
        : allEntries.where((e) => e.category == _selectedCategory).toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      entries = entries.where((e) {
        final nameMatch = e.name.toLowerCase().contains(_searchQuery);
        final producerMatch = e.producer?.toLowerCase().contains(_searchQuery) ?? false;
        final categoryMatch = e.category?.toLowerCase().contains(_searchQuery) ?? false;
        return nameMatch || producerMatch || categoryMatch;
      }).toList();
    }

    // Sort alphabetically by name
    entries.sort((a, b) => a.name.compareTo(b.name));

    if (entries.isEmpty) {
      return MemoixEmptyState(
        message: _searchQuery.isNotEmpty
            ? 'No entries match your search'
            : _selectedCategory != null
                ? 'No entries in $_selectedCategory'
                : 'No cellar entries yet',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CellarCard(
            entry: entry,
            isCompact: isCompact,
            onTap: () => AppRoutes.toCellarDetail(context, entry.uuid),
          ),
        );
      },
    );
  }
}
