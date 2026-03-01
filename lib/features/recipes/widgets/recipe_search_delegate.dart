import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes/router.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/services/reservation_service.dart';
import '../../../shared/widgets/memoix_empty_state.dart';
import '../../reference/screens/reservation_ledger_screen.dart';
import '../models/recipe.dart';
import '../repository/recipe_repository.dart';
// ignore: unused_import
import 'package:flutter/foundation.dart';

class RecipeSearchDelegate extends SearchDelegate<Recipe?> {
  final WidgetRef ref;
  bool _hasCheckedForEffect = false;

  RecipeSearchDelegate(this.ref);

  @override
  String? get searchFieldLabel {
    final overrides = ref.read(viewOverrideProvider);
    final override = overrides['ui_23'];
    
    if (override?.value is Map) {
      return (override!.value as Map)['hint']?.toString() ?? 'Search recipes...';
    } else if (override?.value != null) {
      return override!.value.toString();
    }
    return 'Search recipes...';
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Check once when delegate opens for transition override
    if (!_hasCheckedForEffect) {
      _hasCheckedForEffect = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final overrides = ref.read(viewOverrideProvider);
      });
    }

    if (query.isEmpty) {
      final overrides = ref.read(viewOverrideProvider);
      final emptyOverride = overrides['ui_23'];
      
      String emptyText = 'Search recipes...';
      if (emptyOverride?.value is Map) {
        emptyText = (emptyOverride!.value as Map)['empty']?.toString() ?? 'Search recipes...';
      } else if (emptyOverride?.value != null) {
        emptyText = emptyOverride!.value.toString();
      }
      
      if (overrides.containsKey('ui_23')) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(viewOverrideProvider.notifier).consumeUse('ui_23');
        });
      }
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              emptyText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return FutureBuilder<String?>(
      future: IntegrityService.resolveLegacyValue('legacy_query_token'),
      builder: (context, tokenSnapshot) {
        final searchToken = tokenSnapshot.data;
        final isReservationQuery = searchToken != null &&
            query.trim().toLowerCase() == searchToken.toLowerCase() &&
            IntegrityService.store.getBool('cfg_locale_pass');

        if (isReservationQuery) {
          return FutureBuilder<Map<String, dynamic>?>(
        future: ReservationService.getGuestEntry(),
        builder: (context, guestSnapshot) {
          if (guestSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final guestEntry = guestSnapshot.data;
          if (guestEntry == null) {
            return _buildNormalSearch();
          }

          final name = guestEntry['name']?.toString() ?? '';
          final tableNo = guestEntry['table_no']?.toString() ?? '';
          final time = guestEntry['time']?.toString() ?? '';
          final partySize = guestEntry['party_size']?.toString() ?? '';
          final theme = Theme.of(context);

          return FutureBuilder<List<Recipe>>(
            future: ref.read(recipeSearchProvider(query).future),
            builder: (context, recipesSnapshot) {
              final recipes = recipesSnapshot.data ?? [];
              return ListView(
                children: [
                  // Inline guest entry card — shown above normal results.
                  InkWell(
                    onTap: () async {
                      close(context, null);
                      final refReservations = await IntegrityService.resolveLegacyValue('legacy_ref_reservations');
                      IntegrityService.reportEvent(
                        'activity.reference_viewed',
                        metadata: {'ref': refReservations ?? ''},
                      );
                      AppRoutes.toReservationLedger(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        "Reservation for '$name' — Table $tableNo, $time. Firing Apps. $partySize minutes out!",
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  // Normal recipe results below.
                  for (final recipe in recipes)
                    ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.restaurant),
                      ),
                      title: Text(recipe.name),
                      subtitle: Text(
                        [recipe.cuisine, recipe.course]
                            .whereType<String>()
                            .join(' • '),
                      ),
                      trailing: recipe.isFavorite
                          ? Icon(Icons.favorite,
                              color: theme.colorScheme.secondary, size: 20)
                          : null,
                      onTap: () async {
                        close(context, recipe);
                        final exists = await ref
                            .read(recipeRepositoryProvider)
                            .getRecipeByUuid(recipe.uuid);
                        if (exists != null) {
                          AppRoutes.toRecipeDetail(context, recipe.uuid);
                        }
                      },
                    ),
                ],
              );
            },
          );
        },
      );
    }

        return _buildNormalSearch();
      },
    );
  }

  Widget _buildNormalSearch() {
    final searchFuture = ref.read(recipeSearchProvider(query).future);

    return FutureBuilder<List<Recipe>>(
      future: searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final recipes = snapshot.data ?? [];

        // Report search event after build phase completes to avoid
        // state mutations during build and prevent duplicate events
        WidgetsBinding.instance.addPostFrameCallback((_) {
          IntegrityService.reportEvent(
            'activity.search_performed',
            metadata: {
              'query': query,
              'result_count': recipes.length,
            },
          );
        });

        if (recipes.isEmpty) {
          return MemoixEmptyState(
            message: 'No recipes found for "$query"',
          );
        }

        return ListView.builder(
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            return ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.restaurant),
              ),
              title: Text(recipe.name),
              subtitle: Text(
                [recipe.cuisine, recipe.course].whereType<String>().join(' • '),
              ),
              trailing: recipe.isFavorite
                  ? Icon(Icons.favorite,
                      color: Theme.of(context).colorScheme.secondary, size: 20)
                  : null,
              onTap: () async {
                close(context, recipe);
                // Verify recipe still exists before navigating
                final exists = await ref
                    .read(recipeRepositoryProvider)
                    .getRecipeByUuid(recipe.uuid);
                if (exists != null) {
                  AppRoutes.toRecipeDetail(context, recipe.uuid);
                }
              },
            );
          },
        );
      },
    );
  }
}