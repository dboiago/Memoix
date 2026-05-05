import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/routes/router.dart';
import '../../../config/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/services/update_service.dart';
import '../../../core/widgets/update_available_dialog.dart';
import '../../settings/screens/settings_screen.dart';
import '../../settings/widgets/culinary_intelligence_bottom_sheet.dart';
import '../../../shared/widgets/course_card.dart';
import '../../recipes/models/course.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../recipes/widgets/recipe_search_delegate.dart';
import '../../pizzas/repository/pizza_repository.dart';
import '../../pizzas/models/pizza.dart';
import '../../sandwiches/repository/sandwich_repository.dart';
import '../../sandwiches/models/sandwich.dart';
import '../../smoking/repository/smoking_repository.dart';
import '../../smoking/models/smoking_recipe.dart';
import '../../modernist/repository/modernist_repository.dart';
import '../../modernist/models/modernist_recipe.dart';
import '../../cheese/repository/cheese_repository.dart';
import '../../cheese/models/cheese_entry.dart';
import '../../cellar/repository/cellar_repository.dart';
import '../../cellar/models/cellar_entry.dart';
import '../../notes/repository/scratch_pad_repository.dart';
import '../../settings/screens/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(coursesProvider);
    return coursesAsync.when(
      // appInitProvider awaits coursesProvider.future before resolving, so
      // this branch is only reached if the provider is invalidated mid-session
      // (e.g., after a settings reset). A bare scaffold keeps the background
      // colour consistent without causing a logo-position jump.
      loading: () => const Scaffold(backgroundColor: Color(0xFF242424)),
      error: (err, _) {
        debugPrint('HomeScreen error: $err');
        return const Scaffold(
          backgroundColor: Color(0xFF242424),
          body: Center(child: Text('Something went wrong. Please try restarting the app.', style: TextStyle(color: Color(0xFFA88FA8)))),
        );
      },
      data: (courses) => _CourseGridView(courses: courses),
    );
  }
}

/// View showing courses as a grid of cards
class _CourseGridView extends ConsumerStatefulWidget {
  final List<Course> courses;

  const _CourseGridView({required this.courses});

  @override
  ConsumerState<_CourseGridView> createState() => _CourseGridViewState();
}

class _CourseGridViewState extends ConsumerState<_CourseGridView> {
  dynamic _lastConsumedHintValue;
  dynamic _lastConsumedIconValue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isPlayStore) _checkForUpdatesOnLaunch();
      _checkIntelligenceOptIn();
    });
  }

  /// Shows the Culinary Intelligence opt-in sheet if the user is eligible
  /// and has not previously been shown the prompt.
  ///
  /// Reads SharedPreferences directly (bypassing the notifier's async load)
  /// to guarantee the check is accurate immediately after app start.
  Future<void> _checkIntelligenceOptIn() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_intelligence_opt_in') ?? false;
    if (hasSeen) return;

    // Skip if the user has already opted in via the Settings toggle.
    if (ref.read(contributeToIntelligenceProvider)) return;

    final isEligible =
        await ref.read(intelligencePromptEligibilityProvider.future);
    if (!isEligible) return;

    if (!mounted) return;
    await showCulinaryIntelligenceSheet(context);
  }

  Future<void> _checkForUpdatesOnLaunch() async {
    final autoCheck = ref.read(autoCheckUpdatesProvider);
    if (!autoCheck) return;

    final updateService = ref.read(updateServiceProvider);
    final AppVersion? appVersion;
    try {
      appVersion = await updateService.checkForUpdate();
    } catch (e) {
      debugPrint('Update check on launch failed: $e');
      return;
    }

    if (!mounted || appVersion == null || !appVersion.hasUpdate) return;
    final validVersion = appVersion;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateAvailableDialog(
        currentVersion: validVersion.currentVersion,
        latestVersion: validVersion.latestVersion,
        releaseNotes: validVersion.releaseNotes,
        releaseUrl: validVersion.downloadUrl,
        onUpdate: () async {
          final success = await updateService.installUpdate(validVersion.downloadUrl);
          if (!success && ctx.mounted) {
            Navigator.pop(ctx);
            await updateService.openReleaseUrl(validVersion.downloadUrl);
          }
          return success;
        },
        onDismiss: () {
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courses = widget.courses;
    if (courses.isEmpty) {
      return const Center(
        child: Text('No courses found'),
      );
    }

    final classicsFinalized = ref.watch(classicsFinalizedProvider);
    final showClassicsCard = IntegrityService.store.getBool('cfg_display_pass') &&
        !classicsFinalized;
    // Hoist to the top of build — one subscription each rather than one per
    // course card inside the SliverChildBuilderDelegate (M-4).
    final hideMemoix = ref.watch(hideMemoixRecipesProvider);
    final groupedAsync = ref.watch(recipesGroupedByCourseProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - 32;
        int targetColumns;
        if (width >= 1400) {
          targetColumns = 9;
        } else if (width >= 1100) {
          targetColumns = 7;
        } else if (width >= 800) {
          targetColumns = 5;
        } else if (width >= 600) {
          targetColumns = 4;
        } else if (width >= 400) {
          targetColumns = 3;
        } else {
          targetColumns = 2; // Phone portrait - 2 columns for legibility
        }
        // Calculate extent so cards fill the row (minus spacing)
        final spacing = 6.0 * (targetColumns - 1);
        final maxExtent = (width - spacing) / targetColumns;

        return CustomScrollView(
          slivers: [
            // Search bar at top
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    final overrides = ref.watch(viewOverrideProvider);
                    final hintOverride = overrides['ui_23'];
                    String searchHint = 'Search recipes...';
                    if (hintOverride?.value != null) {
                      if (hintOverride!.value is Map) {
                        searchHint = (hintOverride.value as Map)['hint']?.toString() ?? 'Search recipes...';
                      } else {
                        searchHint = hintOverride.value.toString();
                      }
                    }

                    final searchIcon = overrides.containsKey('ui_41')
                        ? _resolveIcon(overrides['ui_41']!.value)
                        : Icons.search;

                    if (hintOverride != null && hintOverride.value != _lastConsumedHintValue) {
                      _lastConsumedHintValue = hintOverride.value;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          ref.read(viewOverrideProvider.notifier).consumeUse('ui_23');
                        }
                      });
                    }

                    final iconOverride = overrides['ui_41'];
                    if (iconOverride != null && iconOverride.value != _lastConsumedIconValue) {
                      _lastConsumedIconValue = iconOverride.value;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          ref.read(viewOverrideProvider.notifier).consumeUse('ui_41');
                        }
                      });
                    }

                    return TextField(
                      decoration: InputDecoration(
                        hintText: searchHint,
                        hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        prefixIcon: Icon(searchIcon, color: theme.colorScheme.onSurfaceVariant),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                      readOnly: true,
                      onTap: () {
                        showSearch(
                          context: context,
                          delegate: RecipeSearchDelegate(ref),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            
            // Course cards grid - uses maxCrossAxisExtent for auto column count
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.3, // slightly wider than tall
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (showClassicsCard && index == courses.length) {
                      final classicsCourse = Course.create(
                        slug: 'classics',
                        name: 'Classics',
                        iconName: 'restaurant',
                        sortOrder: 99,
                        colorValue: 0xFFFFB74D,
                      );
                      return CourseCard(
                        course: classicsCourse,
                        recipeCount: 0,
                        onTap: () => AppRoutes.toClassics(context),
                      );
                    }

                    final course = courses[index];
                    
                    // Special handling for pizzas, sandwiches, smoking, cheese, cellar - use their own counts
                    final bool isPizza = course.slug == 'pizzas';
                    final bool isSandwich = course.slug == 'sandwiches';
                    final bool isSmoking = course.slug == 'smoking';
                    final bool isModernist = course.slug == 'modernist';
                    final bool isCheese = course.slug == 'cheese';
                    final bool isCellar = course.slug == 'cellar';
                    final bool isScratch = course.slug == 'scratch';
                    
                    // Get count for this category (respecting hideMemoix setting)
                    final int itemCount;
                    if (isScratch) {
                      // For Scratch Pad, show draft count
                      final draftsAsync = ref.watch(recipeDraftsProvider);
                      itemCount = draftsAsync.maybeWhen(
                        data: (drafts) => drafts.length,
                        orElse: () => 0,
                      );
                    } else if (isPizza) {
                      final pizzasAsync = ref.watch(allPizzasProvider);
                      itemCount = pizzasAsync.maybeWhen(
                        data: (pizzas) => hideMemoix
                            ? pizzas.where((p) => p.source != PizzaSource.memoix.name).length
                            : pizzas.length,
                        orElse: () => 0,
                      );
                    } else if (isSandwich) {
                      final sandwichesAsync = ref.watch(allSandwichesProvider);
                      itemCount = sandwichesAsync.maybeWhen(
                        data: (sandwiches) => hideMemoix
                            ? sandwiches.where((s) => s.source != SandwichSource.memoix.name).length
                            : sandwiches.length,
                        orElse: () => 0,
                      );
                    } else if (isSmoking) {
                      final smokingAsync = ref.watch(allSmokingRecipesProvider);
                      itemCount = smokingAsync.maybeWhen(
                        data: (recipes) => hideMemoix
                            ? recipes.where((r) => r.source != SmokingSource.memoix.name).length
                            : recipes.length,
                        orElse: () => 0,
                      );
                    } else if (isModernist) {
                      final modernistAsync = ref.watch(allModernistRecipesProvider);
                      itemCount = modernistAsync.maybeWhen(
                        data: (recipes) => hideMemoix
                            ? recipes.where((r) => r.source != ModernistSource.memoix).length
                            : recipes.length,
                        orElse: () => 0,
                      );
                    } else if (isCheese) {
                      final cheeseAsync = ref.watch(allCheeseEntriesProvider);
                      itemCount = cheeseAsync.maybeWhen(
                        data: (entries) => hideMemoix
                            ? entries.where((e) => e.source != CheeseSource.memoix.name).length
                            : entries.length,
                        orElse: () => 0,
                      );
                    } else if (isCellar) {
                      final cellarAsync = ref.watch(allCellarEntriesProvider);
                      itemCount = cellarAsync.maybeWhen(
                        data: (entries) => hideMemoix
                            ? entries.where((e) => e.source != CellarSource.memoix.name).length
                            : entries.length,
                        orElse: () => 0,
                      );
                    } else {
                      // Single grouped subscription replaces N per-course
                      // SQLite stream subscriptions (M-4).
                      itemCount = groupedAsync.maybeWhen(
                        data: (grouped) {
                          final courseRecipes =
                              grouped[course.slug.toLowerCase()] ?? [];
                          return hideMemoix
                              ? courseRecipes
                                  .where((r) => r.source != RecipeSource.memoix)
                                  .length
                              : courseRecipes.length;
                        },
                        orElse: () => 0,
                      );
                    }

                    return CourseCard(
                      course: course,
                      recipeCount: itemCount,
                      onTap: () {
                        // Special course routing
                        if (course.slug == 'scratch') {
                          AppRoutes.toScratchPad(context);
                        } else if (course.slug == 'pizzas') {
                          AppRoutes.toPizzaList(context);
                        } else if (course.slug == 'sandwiches') {
                          AppRoutes.toSandwichList(context);
                        } else if (course.slug == 'smoking') {
                          AppRoutes.toSmokingList(context);
                        } else if (course.slug == 'modernist') {
                          AppRoutes.toModernistList(context);
                        } else if (course.slug == 'cheese') {
                          AppRoutes.toCheeseList(context);
                        } else if (course.slug == 'cellar') {
                          AppRoutes.toCellarList(context);
                        } else {
                          AppRoutes.toRecipeList(context, course.slug);
                        }
                      },
                    );
                  },
                  childCount: courses.length + (showClassicsCard ? 1 : 0),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Resolve an icon name string to an IconData.
/// Used by the view override system to swap icons dynamically.
IconData _resolveIcon(String name) {
  const map = <String, IconData>{
    'search': Icons.search,
    'set_meal': Icons.set_meal,
    'restaurant': Icons.restaurant,
    'kitchen': Icons.kitchen,
    'eco': Icons.eco,
  };
  return map[name] ?? Icons.search;
}