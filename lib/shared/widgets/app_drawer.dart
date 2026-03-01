import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes/router.dart';
import '../../app/app_shell.dart';
import '../../core/services/integrity_service.dart';
import '../../features/ai/ai_settings_provider.dart';

/// Navigation drawer with organized sections
/// Sections: Navigate, Tools, Share
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer> {
  /// Keys for which we have already consumed one use during
  /// this drawer's lifetime (open → close).
  final Set<String> _consumedKeys = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overrides = ref.watch(viewOverrideProvider);
    
    String timerLabel = 'Kitchen Timer';
    final labelOverride = overrides['ui_07'];
    if (labelOverride?.value != null) {
      timerLabel = labelOverride!.value.toString();
    }

    if (overrides.containsKey('ui_07') &&
        !_consumedKeys.contains('ui_07')) {
      _consumedKeys.add('ui_07');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(viewOverrideProvider.notifier).consumeUse('ui_07');
        }
      });
    }
    
    @override
    void initState() {
      super.initState();
      _consumedKeys.clear();
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Memoix',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For savv(ou)ry minds',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            
            Divider(height: 1, thickness: 0.5, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  // NAVIGATE Section
                  const _DrawerSectionHeader(
                    title: 'Navigate',
                  ),
                  _DrawerTile(
                    icon: Icons.restaurant_menu,
                    title: 'Recipes',
                    onTap: () {
                      Navigator.pop(context);
                      // Pop all routes to get back to home
                      AppShellNavigator.navigatorKey.currentState?.popUntil((route) => route.isFirst);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.favorite_outline,
                    title: 'Favourites',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toFavourites(context);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.calendar_month,
                    title: 'Meal Plan',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toMealPlan(context);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Shopping Lists',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toShoppingLists(context);
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // TOOLS Section
                  const _DrawerSectionHeader(
                    title: 'Tools',
                  ),
                  _DrawerTile(
                    icon: Icons.timer,
                    title: timerLabel,
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toKitchenTimer(context);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.straighten,
                    title: 'Measurement Converter',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toUnitConverter(context);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.compare_arrows,
                    title: 'Compare Recipes',
                    onTap: () {
                      Navigator.pop(context);
                      // Force a reset when opening from the drawer
                      AppRoutes.toRecipeComparison(context, resetState: true);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.note_outlined,
                    title: 'Scratch Pad',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toScratchPad(context);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.bar_chart,
                    title: 'Statistics',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toStatistics(context);
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // IMPORT & SHARE Section
                  const _DrawerSectionHeader(
                    title: 'Import & Share',
                  ),
                  _DrawerTile(
                    icon: Icons.link,
                    title: 'URL Import',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toURLImport(context);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.camera_alt_outlined,
                    title: 'OCR Import',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toOCRScanner(context);
                    },
                  ),
                  if (ref.watch(aiSettingsProvider).activeProviders.isNotEmpty)
                    _DrawerTile(
                      icon: Icons.smart_toy_outlined,
                      title: 'AI Import',
                      onTap: () {
                        Navigator.pop(context);
                        AppRoutes.toAiImport(context);
                      },
                    ),
                  _DrawerTile(
                    icon: Icons.qr_code_scanner,
                    title: 'Scan QR Code',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toQRScanner(context);
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.ios_share,
                    title: 'Share Recipe',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toShareRecipe(context);
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Design Notes section (separate from Share)
                  const _DrawerSectionHeader(
                    title: 'Reference',
                  ),
                  _DrawerTile(
                    icon: Icons.lightbulb_outline,
                    title: 'Design Notes',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toDesignNotes(context);
                    },
                  ),
                ],
              ),
            ),
            
            Divider(height: 1, thickness: 0.5, color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            
            // Settings at bottom
            _DrawerTile(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () {
                Navigator.pop(context);
                AppRoutes.toSettings(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header in drawer
class _DrawerSectionHeader extends StatelessWidget {
  final String title;

  const _DrawerSectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// Drawer list tile with rounded hover effect
class _DrawerTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  State<_DrawerTile> createState() => _DrawerTileState();
}

class _DrawerTileState extends State<_DrawerTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (h) => setState(() => _hovered = h),
          borderRadius: BorderRadius.circular(8),
          hoverColor: theme.colorScheme.surfaceContainerHighest,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(widget.icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
