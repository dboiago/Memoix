import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes/router.dart';

/// Main navigation drawer for Memoix
class MemoixDrawer extends ConsumerWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const MemoixDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MEMOIX',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'For savv(ou)ry minds',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimary.withAlpha((0.8 * 255).round()),
                    ),
                  ),
                ],
              ),
            ),
            // Thin scroll hint bar so users know the drawer can scroll
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              height: 4,
              width: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withAlpha((0.08 * 255).round()),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Main navigation
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 8),
                  const _DrawerSection(title: 'Navigate'),
                  _DrawerItem(
                    icon: Icons.restaurant_menu,
                    label: 'Recipes',
                    isSelected: selectedIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      onItemSelected(0);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.calendar_month,
                    label: 'Meal Plan',
                    isSelected: selectedIndex == 1,
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toMealPlan(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.shopping_cart,
                    label: 'Shopping Lists',
                    isSelected: selectedIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toShoppingLists(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.bar_chart,
                    label: 'Statistics',
                    isSelected: selectedIndex == 3,
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toStatistics(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.favorite,
                    label: 'Favourites',
                    isSelected: selectedIndex == 4,
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toFavourites(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.edit_note,
                    label: 'Scratch Pad',
                    isSelected: selectedIndex == 5,
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toScratchPad(context);
                    },
                  ),

                  const Divider(height: 32),
                  const _DrawerSection(title: 'Tools'),
                  _DrawerItem(
                    icon: Icons.camera_alt,
                    label: 'Scan Recipe (OCR)',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toOCRScanner(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.link,
                    label: 'Import from URL',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toURLImport(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.qr_code_scanner,
                    label: 'Scan QR Code',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toQRScanner(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.share,
                    label: 'Share Recipe',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toShareRecipe(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.straighten,
                    label: 'Unit Converter',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toUnitConverter(context);
                    },
                  ),

                  const Divider(height: 32),
                  _DrawerItem(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toSettings(context);
                    },
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Made with salt.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  final String title;

  const _DrawerSection({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      onTap: onTap,
    );
  }
}
