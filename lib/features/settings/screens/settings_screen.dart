import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/memoix_recipe_service.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/services/supabase_auth_service.dart';
import '../../../core/services/supabase_sync_service.dart';
import '../../../core/services/supabase_secure_storage.dart';
import '../../../config/app_config.dart';
import '../../../core/services/update_service.dart';
import '../../../core/database/database.dart';
import '../../../core/widgets/memoix_snackbar.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/update_available_dialog.dart';
import '../../../core/services/rag_telemetry_service.dart';
import '../services/recipe_backup_service.dart';
import '../../recipes/repository/recipe_repository.dart';
import '../../pizzas/repository/pizza_repository.dart';
import '../../sandwiches/repository/sandwich_repository.dart';
import '../../smoking/repository/smoking_repository.dart';
import '../../modernist/repository/modernist_repository.dart';
import '../../cheese/repository/cheese_repository.dart';
import '../../cellar/repository/cellar_repository.dart';
import '../../ai/ai_settings_provider.dart';
import '../../ai/services/ai_key_storage.dart';
import '../../statistics/models/cooking_stats.dart';
import '../../../app/routes/router.dart';

/// Provider for app preferences
final preferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Provider for package info (app version)
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

/// Provider for hiding Memoix collection recipes (show only personal)
final hideMemoixRecipesProvider = StateNotifierProvider<HideMemoixRecipesNotifier, bool>((ref) {
  return HideMemoixRecipesNotifier();
});


// Arrange from me what's been arranged for you - a life's work distilled
// Knowledge wrest from fire and oil - contained between A and Z
// Decorative made way for the declarative - only bringing what can be consumed
// My name no longer found but remembered - not in the recipe but the rule
const _legacy = 'XBLCNBLPAQNUNWBW';

class HideMemoixRecipesNotifier extends StateNotifier<bool> {
  static const _key = 'hide_memoix_recipes';

  HideMemoixRecipesNotifier() : super(false) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
    IntegrityService.reportEvent('activity.setting_changed', metadata: {'key': _key, 'value': state});
  }
}

class ContributeRecipesInfoScreen extends StatelessWidget {
  const ContributeRecipesInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Contributions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              title: 'Overview',
              body:
                  'Memoix is developing a system to understand recipes semantically - '
                  'moving beyond text search toward a tool that understands cooking as '
                  'a domain. The long-term goal is cross-cuisine discovery: surfacing '
                  'relevant recipes across languages and culinary traditions, with the '
                  'AI handling translation, unit conversion, and contextual adaptation '
                  'automatically.\n\n'
                  'To build this, the system needs to learn from real, human-tested '
                  'recipes rather than raw internet scrapes. This feature is strictly '
                  'opt-in and has no effect unless explicitly enabled.',
            ),
            _BulletSection(
              title: 'How It Works',
              intro:
                  'When enabled, Memoix transmits your recipes to a secure backend to '
                  'build a proprietary culinary dataset. Your recipes contribute to a '
                  'shared understanding of ingredient relationships, regional cuisines, '
                  'dish structure, and recipe evolution over time.\n\n'
                  'Submitted recipes are processed server-side to generate semantic '
                  'representations used for search and model training. This processing '
                  'happens on Cloudflare\'s infrastructure. No recipe content is used '
                  'to train third-party commercial models.\n\n'
                  'Your data helps the system learn things like:',
              bullets: const [
                'Which ingredient ratios are characteristic of a dish',
                'How recipes are naturally categorized and tagged by real cooks',
                'Which modifications are consistently made to improve a dish',
                'How dishes relate to and complement one another across cuisines',
              ],
            ),
            _BulletSection(
              title: 'What Is Collected',
              intro:
                  'If you opt in, the following is transmitted when you save, '
                  'update, cook, or favourite a recipe:',
              bullets: const [
                'Recipe content (ingredients, instructions, and notes)',
                'Original source text or URL (if the recipe was imported)',
                'Culinary statistics (cook count, favourite status, ratings)',
                'Recipe pairing relationships (the name and course of any linked recipes)',
                'A derived lineage identifier and content hash, used to track recipe '
                    'refinement over time without transmitting any device or user identifier',
                'Basic metadata (app version and system language)',
              ],
            ),
            _BulletSection(
              title: 'What Is NEVER Collected',
              bullets: const [
                'No personal identifiers - no name, email, account, or device ID',
                'No location data',
                'No behavioural tracking - no screen time, session data, or usage patterns',
                'No hidden recipes - recipes marked as Hidden are unconditionally excluded '
                    'from transmission, regardless of your global setting',
              ],
            ),
            _Section(
              title: 'A Note on Privacy and Submitted Data',
              body:
                  'Submitted recipes are stored without any user or device identifier. The '
                  'dataset has no client read access and cannot be queried by users or the app.\n\n'
                  'Because no user or device identifier is attached to any submission, it is '
                  'not possible to withdraw previously submitted data - there is no link '
                  'between the dataset and you. Disabling this setting stops all future '
                  'transmissions immediately.',
            ),
            _Section(
              title: 'Control',
              body:
                  '**Global Setting**\n'
                  'Enable or disable this feature at any time in Settings > Data > '
                  'Contribute to Culinary Intelligence. Disabling stops all future '
                  'transmissions immediately.\n\n'
                  '**Per-Recipe Privacy**\n'
                  'If you want to contribute but have specific recipes you want to keep '
                  'private, open the menu on any recipe and set its visibility to Hidden. '
                  'Hidden recipes are never transmitted, even when the global setting is enabled.',
            ),
          ],
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Built for cooking, not tracking.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          )),
        ],
      ),
    );
  }
}

class _BulletSection extends StatelessWidget {
  const _BulletSection({
    required this.title,
    required this.bullets,
    this.intro,
  });

  final String title;
  final String? intro;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          if (intro != null) ...[
            Text(intro!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
          ],
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('· ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  Expanded(
                    child: Text(b, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Provider for compact list view preference
final compactViewProvider = StateNotifierProvider<CompactViewNotifier, bool>((ref) {
  return CompactViewNotifier();
});

class CompactViewNotifier extends StateNotifier<bool> {
  static const _key = 'compact_view';

  CompactViewNotifier() : super(false) { // Default to OFF
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false; // Default OFF
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
    IntegrityService.reportEvent('activity.setting_changed', metadata: {'key': _key, 'value': state});
  }
}

/// Provider for keeping screen on while viewing recipes
final keepScreenOnProvider = StateNotifierProvider<KeepScreenOnNotifier, bool>((ref) {
  return KeepScreenOnNotifier();
});

class KeepScreenOnNotifier extends StateNotifier<bool> {
  static const _key = 'keep_screen_on';

  KeepScreenOnNotifier() : super(true) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true; // Default to ON
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
    IntegrityService.reportEvent('activity.setting_changed', metadata: {'key': _key, 'value': state});
  }
}

/// Provider for side-by-side mode - independent scrolling for ingredients/directions
final useSideBySideProvider = StateNotifierProvider<UseSideBySideNotifier, bool>((ref) {
  return UseSideBySideNotifier();
});

class UseSideBySideNotifier extends StateNotifier<bool> {
  static const _key = 'use_side_by_side_view';

  UseSideBySideNotifier() : super(false) { // Default to OFF (standard layout)
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false; // Default to OFF
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
    IntegrityService.reportEvent('activity.setting_changed', metadata: {'key': _key, 'value': state});
  }
}

/// Provider for showing header images on recipe detail screens
final showHeaderImagesProvider = StateNotifierProvider<ShowHeaderImagesNotifier, bool>((ref) {
  return ShowHeaderImagesNotifier();
});

class ShowHeaderImagesNotifier extends StateNotifier<bool> {
  static const _key = 'show_header_images';

  ShowHeaderImagesNotifier() : super(true) { // Default to ON (show header images)
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true; // Default to ON
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
    IntegrityService.reportEvent('activity.setting_changed', metadata: {'key': _key, 'value': state});
  }
}

/// Provider for auto-check for updates preference
final autoCheckUpdatesProvider = StateNotifierProvider<AutoCheckUpdatesNotifier, bool>((ref) {
  return AutoCheckUpdatesNotifier();
});

class AutoCheckUpdatesNotifier extends StateNotifier<bool> {
  static const _key = 'auto_check_updates';

  AutoCheckUpdatesNotifier() : super(false) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false; // Default to OFF
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
    IntegrityService.reportEvent('activity.setting_changed', metadata: {'key': _key, 'value': state});
  }
}

/// Master opt-in switch for the Culinary Intelligence RAG pipeline.
/// Defaults to OFF - this app is strictly opt-in and privacy-focused.
/// When OFF, no recipe data is ever queued for export regardless of per-recipe flags.
final contributeToIntelligenceProvider =
    StateNotifierProvider<ContributeToIntelligenceNotifier, bool>((ref) {
  return ContributeToIntelligenceNotifier(ref);
});

class ContributeToIntelligenceNotifier extends StateNotifier<bool> {
  static const _key = 'contribute_to_culinary_intelligence';
  final Ref _ref;

  ContributeToIntelligenceNotifier(this._ref) : super(false) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false; // Must default to OFF - opt-in only
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
    if (state) {
      // Just transitioned OFF→ON: queue all existing entries for the
      // backfill. Fire-and-forget — failures are silently dropped inside
      // the service. Runs once per deliberate opt-in action, not on launch.
      unawaited(
        _ref.read(ragTelemetryServiceProvider).backfillOnOptIn(
          recipeFetcher: () => _ref
              .read(recipeRepositoryProvider)
              .watchAllRecipes()
              .first
              .then(
                (all) => all
                    .where((r) => r.recipeType == 'standard')
                    .toList(),
              ),
          modernistFetcher: () =>
              _ref.read(modernistRepositoryProvider).getAll(),
          smokingFetcher: () =>
              _ref.read(smokingRepositoryProvider).getAllRecipes(),
          pizzaFetcher: () =>
              _ref.read(pizzaRepositoryProvider).getAllPizzas(),
          sandwichFetcher: () =>
              _ref.read(sandwichRepositoryProvider).getAllSandwiches(),
          cellarFetcher: () =>
              _ref.read(cellarRepositoryProvider).getAllEntries(),
          cheeseFetcher: () =>
              _ref.read(cheeseRepositoryProvider).getAllEntries(),
        ),
      );
    }
  }
}

/// Whether the user has already been shown the Culinary Intelligence opt-in prompt.
/// Defaults to false. Flipped to true by the prompt regardless of the user's choice.
final hasSeenIntelligenceOptInProvider =
    StateNotifierProvider<HasSeenIntelligenceOptInNotifier, bool>((ref) {
  return HasSeenIntelligenceOptInNotifier();
});

class HasSeenIntelligenceOptInNotifier extends StateNotifier<bool> {
  static const _key = 'has_seen_intelligence_opt_in';

  HasSeenIntelligenceOptInNotifier() : super(false) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> markSeen() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

/// Whether the user has enough engagement to be shown the intelligence opt-in prompt.
///
/// Evaluates: `recipeCount >= 3 || madeCount >= 1 || favouriteCount >= 2`.
/// Only personal recipes and all cooking logs / recipe favourites are counted.
/// This is a one-shot read - it is not reactive to later DB changes.
final intelligencePromptEligibilityProvider = FutureProvider<bool>((ref) async {
  final db = ref.read(databaseProvider);
  final recipeCount = (await db.recipeDao.getPersonalRecipes()).length;
  final madeCount = (await db.cookingLogDao.getStats()).length;
  final favouriteCount = (await db.recipeDao.getFavouriteRecipes()).length;
  return recipeCount >= 3 || madeCount >= 1 || favouriteCount >= 2;
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hideMemoixRecipes = ref.watch(hideMemoixRecipesProvider);
    final compactView = ref.watch(compactViewProvider);
    final packageInfo = ref.watch(packageInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Appearance', style: theme.textTheme.labelLarge),
          ),
          RadioGroup<ThemeMode>(
            groupValue: ref.watch(themeModeProvider),
            onChanged: (m) => ref.read(themeModeProvider.notifier).setMode(m ?? ThemeMode.system),
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(title: Text('System Default'), value: ThemeMode.system),
                RadioListTile<ThemeMode>(title: Text('Light'), value: ThemeMode.light),
                RadioListTile<ThemeMode>(title: Text('Dark'), value: ThemeMode.dark),
              ],
            ),
          ),
          const Divider(),
          // Display section
          const _SectionHeader(title: 'Display'),
          const _HideMemoixRecipesTile(),
          SwitchListTile(
            secondary: const Icon(Icons.view_column),
            title: const Text('Side-by-Side Mode'),
            subtitle: const Text('Split view with independent scrolling for ingredients and directions'),
            value: ref.watch(useSideBySideProvider),
            onChanged: (_) => ref.read(useSideBySideProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.view_compact),
            title: const Text('Compact View'),
            subtitle: const Text('Show more recipes per screen'),
            value: compactView,
            onChanged: (_) => ref.read(compactViewProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.image),
            title: const Text('Show Header Images'),
            subtitle: const Text('Display recipe images in detail headers'),
            value: ref.watch(showHeaderImagesProvider),
            onChanged: (_) => ref.read(showHeaderImagesProvider.notifier).toggle(),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lightbulb),
            title: const Text('Keep Screen On'),
            subtitle: const Text('Prevent screen from turning off while viewing recipes'),
            value: ref.watch(keepScreenOnProvider),
            onChanged: (_) => ref.read(keepScreenOnProvider.notifier).toggle(),
          ),

          const Divider(),

          // Personal Storage section
          const _SectionHeader(title: 'Backup'),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const Text('Personal Storage'),
            subtitle: const Text('Backup to your own cloud storage account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openExternalStorage(context),
          ),
          _SupabaseConnectTile(context: context),

          const Divider(),
          
          // Agents section
          const _SectionHeader(title: 'Agents'),
          ListTile(
            leading: const Icon(Icons.smart_toy_outlined),
            title: const Text('AI Agents'),
            subtitle: const Text('Manage AI providers and preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => AppRoutes.toAgentsSettings(context),
          ),

          if (!isPlayStore) ...[  
            const Divider(),

            // Updates section
            const _SectionHeader(title: 'Updates'),
            ListTile(
              leading: const Icon(Icons.system_update),
              title: const Text('Check for App Updates'),
              subtitle: const Text('Download the latest version from GitHub'),
              onTap: () => _checkForUpdates(context, ref),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.auto_awesome),
              title: const Text('Auto-check for Updates'),
              subtitle: const Text('Check for updates when app launches'),
              value: ref.watch(autoCheckUpdatesProvider),
              onChanged: (_) => ref.read(autoCheckUpdatesProvider.notifier).toggle(),
            ),
          ],

          const Divider(),

          // Data section
          const _SectionHeader(title: 'Data'),
          _ExportMyRecipesTile(ref: ref),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Import Recipes'),
            subtitle: const Text('Load recipes from a JSON file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final service = ref.read(recipeBackupServiceProvider);
                final count = await service.importRecipes();
                if (count > 0) {
                  MemoixSnackBar.showSuccess('Imported $count recipe${count == 1 ? '' : 's'}');
                } else {
                  MemoixSnackBar.show('No recipes imported');
                }
              } catch (e) {
                MemoixSnackBar.showError('Import failed: $e');
              }
            },
          ),
          // Import recipes from folder (advanced, includes all cuisines and metadata)
          ListTile(
            leading: const Icon(Icons.folder_open),
            title: const Text('Import from Folder'),
            subtitle: const Text('Restore all cuisines from folder'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              try {
                final service = ref.read(recipeBackupServiceProvider);
                final results = await service.importFromFolder();
                if (results.isNotEmpty) {
                  final total = results.values.fold(0, (a, b) => a + b);
                  final cuisines = results.keys.join(', ');
                  MemoixSnackBar.showSuccess('Imported $total items from: $cuisines');
                } else {
                  MemoixSnackBar.show('No items imported');
                }
              } catch (e) {
                MemoixSnackBar.showError('Import failed: $e');
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.tune),
            title: const Text('Contribute Recipes'),
            subtitle: const Text(
              'Help build a culinary dataset from real, tested recipes.\n'
              'No account, no tracking - your recipe content only.',
            ),
            value: ref.watch(contributeToIntelligenceProvider),
            onChanged: (_) =>
                ref.read(contributeToIntelligenceProvider.notifier).toggle(),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 53),
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ContributeRecipesInfoScreen(),
                  ),
                ),
                child: const Text('Learn more'),
              ),
            ),
          ),

          const Divider(),

          // About section
          const _SectionHeader(title: 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Memoix'),
            onTap: () => _showAbout(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Source Code'),
            subtitle: const Text('View on GitHub'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final uri = Uri.parse('https://github.com/dboiago/Memoix');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                MemoixSnackBar.showError('Could not open GitHub');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.shop_outlined),
            title: const Text('Play Store'),
            subtitle: const Text('View Memoix on Google Play'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final uri = Uri.parse(
                'https://play.google.com/store/apps/details?id=io.github.dboiago.memoix',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final uri = Uri.parse('https://dboiago.github.io/Memoix/privacy/');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),

          const Divider(),

          // Danger zone (using secondary color for visibility)
          _SectionHeader(title: 'Danger Zone', colour: theme.colorScheme.secondary),
          _ClearAllDataTile(
            onTap: () => _confirmClearData(context, ref),
          ),

          const SizedBox(height: 32),

          // Version info
          Center(
            child: Text(
              packageInfo.whenOrNull(
                data: (info) => 'Memoix v${info.version}',
              ) ?? 'Memoix',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Built with salt.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _openExternalStorage(BuildContext context) {
    AppRoutes.toPersonalStorage(context);
  }

  void _showAbout(BuildContext context, WidgetRef ref) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final baseVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    
    // Check for version suffix override
    final overrides = ref.read(viewOverrideProvider);
    final suffixOverride = overrides['ui_89'];
    final version = suffixOverride != null 
        ? '$baseVersion${suffixOverride.value}'
        : baseVersion;
    
    // Consume if present
    if (suffixOverride != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(viewOverrideProvider.notifier).consumeUse('ui_89');
      });
    }

    if (!context.mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'Memoix',
      applicationVersion: version,
      applicationIcon: SvgPicture.asset(
        'assets/images/memoix_logo.svg',
        width: 80,
        height: 80,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          Theme.of(context).colorScheme.secondary,
          BlendMode.srcIn,
        ),
      ),
      applicationLegalese: '© 2024-2026 Devon Boiago\n\n'
          'Licensed under PolyForm Noncommercial 1.0.0.\n'
          'Free for personal and educational use.',
      children: [
        const SizedBox(height: 24),
        const Text(
          'An offline-first recipe and culinary reference app built for real cooking.\n\n'
          'For sav(vour)y minds.',
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref) async {
    // Show loading indicator
    if (!context.mounted) return;
    MemoixSnackBar.show('Checking for updates...');

    final updateService = ref.read(updateServiceProvider);
    final AppVersion? appVersion;
    try {
      appVersion = await updateService.checkForUpdate();
    } catch (e) {
      if (!context.mounted) return;
      MemoixSnackBar.showError('Unable to check for updates.');
      return;
    }

    if (!context.mounted) return;

    if (appVersion == null) {
      MemoixSnackBar.showError('Could not check for updates. Please try again.');
      return;
    }

    if (!appVersion.hasUpdate) {
      MemoixSnackBar.showSuccess('You\'re already running the latest version!');
      return;
    }
    final validVersion = appVersion!;

    // Show update dialog
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
            // Fallback: open browser if auto-install failed
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

  void _confirmClearData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will permanently delete all your personal recipes and settings. '
          'This action cannot be undone.\n\n'
          'Memoix collection recipes will be re-downloaded on next sync.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await MemoixDatabase.clearAll();

              // Delete on-disk image directories (recreated on demand via create(recursive: true))
              final appDir = await getApplicationDocumentsDirectory();
              for (final dirName in const [
                'recipe_images',
                'cellar_images',
                'cheese_images',
                'pizza_images',
                'sandwich_images',
                'smoking_images',
                'modernist_images',
              ]) {
                final dir = Directory('${appDir.path}/$dirName');
                if (await dir.exists()) await dir.delete(recursive: true);
              }

              // Clear AI provider API keys and Supabase auth session from secure storage
              await AiKeyStorage.clearAll();
              await const SupabaseSecureStorage().removePersistedSession();

              // Clear cloud and sync SharedPreferences keys
              final prefs = await SharedPreferences.getInstance();
              for (final key in const [
                'personal_storage_provider_id',
                'personal_storage_path',
                'drive_repositories',
                'google_drive_connected',
                'google_drive_folder_id',
                'google_drive_folder_path',
                'google_drive_access_token',
                'google_drive_refresh_token',
                'google_drive_token_expiry',
                'supabase_sync_recipes',
                'supabase_sync_ingredients',
                'supabase_sync_pizzas',
                'supabase_sync_sandwiches',
                'supabase_sync_cellar_entries',
                'supabase_sync_cheese_entries',
                'supabase_sync_smoking_recipes',
                'supabase_sync_courses',
                'supabase_sync_scratch_pads',
                'supabase_sync_user_entity_prefs',
                'supabase_sync_meal_plans',
                'supabase_sync_shopping_lists',
                'supabase_sync_recipe_drafts',
                'supabase_sync_cooking_logs',
                'supabase_sync_recipe_images',
              ]) {
                await prefs.remove(key);
              }

              // Invalidate all domain providers to reflect the empty DB
              ref.invalidate(coursesProvider);
              ref.invalidate(allRecipesProvider);
              ref.invalidate(availableCuisinesProvider);
              ref.invalidate(allPizzasProvider);
              ref.invalidate(allSandwichesProvider);
              ref.invalidate(allSmokingRecipesProvider);
              ref.invalidate(allModernistRecipesProvider);
              ref.invalidate(allCheeseEntriesProvider);
              ref.invalidate(allCellarEntriesProvider);
              ref.invalidate(shoppingListsProvider);
              ref.invalidate(shoppingItemsProvider);
              ref.invalidate(mealPlanServiceProvider);
              ref.invalidate(aiSettingsProvider);
              ref.invalidate(cookingStatsProvider);

              MemoixSnackBar.show('All data cleared');
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _ClearAllDataTile extends StatefulWidget {
  final VoidCallback onTap;

  const _ClearAllDataTile({required this.onTap});

  @override
  State<_ClearAllDataTile> createState() => _ClearAllDataTileState();
}

class _ClearAllDataTileState extends State<_ClearAllDataTile> {
  Timer? _pressTimer;

  void _handleTapDown(TapDownDetails details) {
    _pressTimer = Timer(const Duration(milliseconds: 8000), () {
      if (mounted) _showConfirm();
    });
  }

  void _handleTapUp(TapUpDetails details) {
    if (_pressTimer?.isActive ?? false) {
      _pressTimer?.cancel();
      widget.onTap();
    }
  }

  void _handleTapCancel() {
    _pressTimer?.cancel();
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  void _showConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _clearStore();
              MemoixSnackBar.show('Done.');
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearStore() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith('runtime_')).toList()) {
      await prefs.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ListTile(
        leading: Icon(Icons.delete_forever, color: theme.colorScheme.secondary),
        title: Text(
          'Clear All Data',
          style: TextStyle(color: theme.colorScheme.secondary),
        ),
        subtitle: const Text('Delete all recipes and reset app'),
        onTap: null,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? colour;

  const _SectionHeader({required this.title, this.colour});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colour ?? Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _HideMemoixRecipesTile extends ConsumerStatefulWidget {
  const _HideMemoixRecipesTile();

  @override
  ConsumerState<_HideMemoixRecipesTile> createState() =>
      _HideMemoixRecipesTileState();
}

class _HideMemoixRecipesTileState
    extends ConsumerState<_HideMemoixRecipesTile> {
  final List<DateTime> _toggleTimestamps = [];
  Timer? _patternResetTimer;

  int _patternPause = 800;
  int _patternWindow = 6000;
  List<int> _patternSchema = const [];

  @override
  void initState() {
    super.initState();
    _loadPatternSchema();
  }

  Future<void> _loadPatternSchema() async {
    final schema = await IntegrityService.resolveValidationIntList('legacy_pattern_schema');
    final pause = await IntegrityService.resolveLegacyInt('legacy_pattern_pause');
    final window = await IntegrityService.resolveLegacyInt('legacy_pattern_window');
    if (!mounted) return;
    setState(() {
      if (schema != null) _patternSchema = schema;
      if (pause != null) _patternPause = pause;
      if (window != null) _patternWindow = window;
    });
  }

  @override
  void dispose() {
    _patternResetTimer?.cancel();
    super.dispose();
  }

  void _onToggle() {
    _patternResetTimer?.cancel();
    _toggleTimestamps.add(DateTime.now());
    _patternResetTimer = Timer(Duration(milliseconds: _patternWindow), () {
      _toggleTimestamps.clear();
    });
    final expectedTotal = _patternSchema.fold(0, (a, b) => a + b);
    if (expectedTotal > 0 && _toggleTimestamps.length == expectedTotal) {
      final valid = _validatePattern(List.of(_toggleTimestamps));
      _toggleTimestamps.clear();
      if (valid) _onPatternComplete();
    }
    ref.read(hideMemoixRecipesProvider.notifier).toggle();
  }

  bool _validatePattern(List<DateTime> ts) {
    if (_patternSchema.isEmpty) return false;
    final expectedTotal = _patternSchema.fold(0, (a, b) => a + b);
    if (ts.length != expectedTotal) return false;
    final groups = <int>[];
    int size = 1;
    for (int i = 1; i < ts.length; i++) {
      final gap = ts[i].difference(ts[i - 1]).inMilliseconds;
      if (gap > _patternWindow) return false;
      if (gap >= _patternPause) {
        groups.add(size);
        size = 1;
      } else {
        size++;
      }
    }
    groups.add(size);
    if (groups.length != _patternSchema.length) return false;
    for (int i = 0; i < groups.length; i++) {
      if (groups[i] != _patternSchema[i]) return false;
    }
    return true;
  }

  Future<void> _onPatternComplete() async {
    if (!IntegrityService.store.getBool('cfg_render_pass')) return;
    if (IntegrityService.store.getBool('cfg_display_pass')) return;
    final player = AudioPlayer();
    await player.play(AssetSource('audio/service_bell.wav'));
    final refIndex = await IntegrityService.resolveLegacyValue('legacy_ref_index');
    await IntegrityService.reportEvent(
      'activity.display_calibrated',
      metadata: {'ref': refIndex ?? ''},
    );
    if (mounted) await processIntegrityResponses(ref);
  }

  @override
  Widget build(BuildContext context) {
    final hideMemoixRecipes = ref.watch(hideMemoixRecipesProvider);
    return SwitchListTile(
      secondary: const Icon(Icons.visibility_off),
      title: const Text('Hide Memoix Recipes'),
      subtitle: const Text('Only show your personal recipes'),
      value: hideMemoixRecipes,
      onChanged: (_) => _onToggle(),
    );
  }
}

/// Export My Recipes tile with hidden advanced export on long-press
class _ExportMyRecipesTile extends StatefulWidget {
  final WidgetRef ref;

  const _ExportMyRecipesTile({required this.ref});

  @override
  State<_ExportMyRecipesTile> createState() => _ExportMyRecipesTileState();
}

class _ExportMyRecipesTileState extends State<_ExportMyRecipesTile> {
  Timer? _pressTimer;
  bool _isLongPressing = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isLongPressing = true);
    
    // Start timer for 5 seconds
    _pressTimer = Timer(const Duration(milliseconds: 5000), () {
      if (mounted) {
        setState(() => _isLongPressing = false);
        _exportAdvanced();
      }
    });
  }

  void _handleTapUp(TapUpDetails details) {
    if (_pressTimer?.isActive ?? false) {
      _pressTimer?.cancel();
      setState(() => _isLongPressing = false);
      _exportStandard();
    }
  }

  void _handleTapCancel() {
    _pressTimer?.cancel();
    setState(() => _isLongPressing = false);
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  Future<void> _exportStandard() async {
    try {
      final service = widget.ref.read(recipeBackupServiceProvider);
      final result = await service.exportRecipes(includeAll: false);
      // Only show success if export actually happened (user didn't cancel)
      if (result != null) {
        MemoixSnackBar.showSuccess('Recipes exported successfully');
      }
    } catch (e) {
      MemoixSnackBar.showError('Export failed: $e');
    }
  }

  Future<void> _exportAdvanced() async {
    try {
      final service = widget.ref.read(recipeBackupServiceProvider);
      final count = await service.exportByCourse();
      if (count != null && count > 0) {
        MemoixSnackBar.showSuccess('Advanced export complete: $count files');
      }
    } catch (e) {
      MemoixSnackBar.showError('Export failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _isLongPressing
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.transparent,
        ),
        child: const ListTile(
          leading: Icon(Icons.description),
          title: Text('Export My Recipes'),
          subtitle: Text('Single JSON file (excludes Memoix collection)'),
          trailing: Icon(Icons.chevron_right),
          // Prevent ListTile's own tap handling
          onTap: null,
        ),
      ),
    );
  }
}

/// Hidden Supabase connect/disconnect entry point.
///
/// Appears as the standard "Shared Storage" row. A normal tap navigates to
/// Shared Storage as usual. Holding for 8 seconds reveals the connect /
/// disconnect bottom sheet.
class _SupabaseConnectTile extends StatefulWidget {
  final BuildContext context;

  const _SupabaseConnectTile({required this.context});

  @override
  State<_SupabaseConnectTile> createState() => _SupabaseConnectTileState();
}

class _SupabaseConnectTileState extends State<_SupabaseConnectTile> {
  Timer? _pressTimer;
  bool _isLongPressing = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isLongPressing = true);
    _pressTimer = Timer(const Duration(milliseconds: 8000), () {
      if (mounted) {
        setState(() => _isLongPressing = false);
        _showConnectSheet();
      }
    });
  }

  void _handleTapUp(TapUpDetails details) {
    if (_pressTimer?.isActive ?? false) {
      _pressTimer?.cancel();
      setState(() => _isLongPressing = false);
      AppRoutes.toSharedStorage(widget.context);
    }
  }

  void _handleTapCancel() {
    _pressTimer?.cancel();
    setState(() => _isLongPressing = false);
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    super.dispose();
  }

  void _showConnectSheet() {
    if (SupabaseAuthService.isSignedIn) {
      _showDisconnectSheet();
    } else {
      _showSignInSheet();
    }
  }

  void _showSignInSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SignInSheet(),
    );
  }

  void _showDisconnectSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await SupabaseAuthService.signOut();
                    MemoixSnackBar.show('Disconnected');
                  },
                  child: const Text('Disconnect'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _isLongPressing
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.transparent,
        ),
        child: const ListTile(
          leading: Icon(Icons.folder_shared_outlined),
          title: Text('Shared Storage'),
          subtitle: Text('Access shared or managed recipe collections'),
          trailing: Icon(Icons.chevron_right),
          onTap: null,
        ),
      ),
    );
  }
}

/// Sign-in bottom sheet for [_SupabaseConnectTile].
class _SignInSheet extends StatefulWidget {
  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _loading = true);
    final success = await SupabaseAuthService.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      SupabaseSyncService.sync().then((_) {});
      MemoixSnackBar.show('Connected');
    } else {
      setState(() => _loading = false);
      MemoixSnackBar.showError('Connection failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              enabled: !_loading,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              enabled: !_loading,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _connect,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
