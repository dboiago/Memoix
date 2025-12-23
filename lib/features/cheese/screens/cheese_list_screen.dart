import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../shared/widgets/memoix_empty_state.dart';
import '../../settings/screens/settings_screen.dart';
import '../models/cheese_entry.dart';
import '../repository/cheese_repository.dart';
import '../widgets/cheese_card.dart';

/// Cheese list screen - displays cheese entries
class CheeseListScreen extends ConsumerStatefulWidget {
  const CheeseListScreen({super.key});

  @override
  ConsumerState<CheeseListScreen> createState() => _CheeseListScreenState();
}

class _CheeseListScreenState extends ConsumerState<CheeseListScreen> {
  String? _selectedMilk;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entriesAsync = ref.watch(allCheeseEntriesProvider);
    final isCompact = ref.watch(compactViewProvider);
    final hideMemoix = ref.watch(hideMemoixRecipesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Cheese',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (allEntries) {
          // Apply hide memoix filter
          final visibleEntries = hideMemoix
              ? allEntries.where((e) => e.source != CheeseSource.memoix).toList()
              : allEntries;

          // Get milk types that have entries
          final availableMilks = _getAvailableMilks(visibleEntries);

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search cheese...',
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

              // Milk filter chips
              if (availableMilks.isNotEmpty)
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip(null, visibleEntries.length), // "All" chip
                      ...availableMilks.map((milk) {
                        final count = visibleEntries.where((e) => e.milk == milk).length;
                        return _buildFilterChip(milk, count);
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
        onPressed: () => AppRoutes.toCheeseEdit(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _buildFilterChip(String? milk, int count) {
    final isSelected = _selectedMilk == milk;
    final theme = Theme.of(context);
    final label = milk ?? 'All';

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedMilk = selected ? milk : null);
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

  List<String> _getAvailableMilks(List<CheeseEntry> entries) {
    final milks = <String>{};
    for (final entry in entries) {
      if (entry.milk != null && entry.milk!.isNotEmpty) {
        milks.add(entry.milk!);
      }
    }
    final sorted = milks.toList()..sort();
    return sorted;
  }

  Widget _buildEntryList(List<CheeseEntry> allEntries, bool isCompact) {
    // Filter by milk
    var entries = _selectedMilk == null
        ? allEntries
        : allEntries.where((e) => e.milk == _selectedMilk).toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      entries = entries.where((e) {
        final nameMatch = e.name.toLowerCase().contains(_searchQuery);
        final countryMatch = e.country?.toLowerCase().contains(_searchQuery) ?? false;
        final typeMatch = e.type?.toLowerCase().contains(_searchQuery) ?? false;
        final milkMatch = e.milk?.toLowerCase().contains(_searchQuery) ?? false;
        return nameMatch || countryMatch || typeMatch || milkMatch;
      }).toList();
    }

    // Sort alphabetically by name
    entries.sort((a, b) => a.name.compareTo(b.name));

    if (entries.isEmpty) {
      return MemoixEmptyState(
        message: _searchQuery.isNotEmpty
            ? 'No entries match your search'
            : _selectedMilk != null
                ? 'No entries with $_selectedMilk milk'
                : 'No cheese entries yet',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CheeseCard(
            entry: entry,
            isCompact: isCompact,
            onTap: () => AppRoutes.toCheeseDetail(context, entry.uuid),
          ),
        );
      },
    );
  }
}
