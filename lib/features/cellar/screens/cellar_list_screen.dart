import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
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
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (allEntries) {
          // Get categories that have entries
          final availableCategories = _getAvailableCategories(allEntries);

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search cellar...',
                    hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
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
                      _buildFilterChip(null, allEntries.length), // "All" chip
                      ...availableCategories.map((category) {
                        final count = allEntries.where((e) => e.category == category).length;
                        return _buildFilterChip(category, count);
                      }),
                    ],
                  ),
                ),

              // Entry list
              Expanded(
                child: _buildEntryList(allEntries, isCompact),
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
    final isSelected = _selectedCategory == category;
    final theme = Theme.of(context);
    final label = category ?? 'All';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedCategory = selected ? category : null);
        },
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        selectedColor: theme.colorScheme.secondary.withOpacity(0.15),
        showCheckmark: false,
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.secondary
              : theme.colorScheme.outline.withOpacity(0.2),
          width: isSelected ? 1.5 : 1.0,
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          color: isSelected
              ? theme.colorScheme.secondary
              : theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  List<String> _getAvailableCategories(List<CellarEntry> entries) {
    final categories = <String>{};
    for (final entry in entries) {
      if (entry.category != null && entry.category!.isNotEmpty) {
        categories.add(entry.category!);
      }
    }
    final sorted = categories.toList()..sort();
    return sorted;
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No entries match your search'
                  : _selectedCategory != null
                      ? 'No entries in $_selectedCategory'
                      : 'No cellar entries yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
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
