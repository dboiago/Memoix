import 'package:flutter/material.dart';
import '../../app/routes/router.dart';
import '../../features/home/screens/favourites_screen.dart';

/// Navigation drawer with organized sections matching Figma design
/// Sections: Navigate, Tools, Share
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
                    'Recipe Management',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // NAVIGATE Section
                  _DrawerSectionHeader(
                    title: 'Navigate',
                  ),
                  _DrawerTile(
                    icon: Icons.restaurant_menu,
                    title: 'Recipes',
                    onTap: () {
                      Navigator.pop(context);
                      // Already on home, no navigation needed
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
                  _DrawerTile(
                    icon: Icons.favorite_outline,
                    title: 'Favourites',
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to favorites screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FavouritesScreen(),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // TOOLS Section
                  _DrawerSectionHeader(
                    title: 'Tools',
                  ),
                  _DrawerTile(
                    icon: Icons.timer,
                    title: 'Kitchen Timer',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toKitchenTimer(context);
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
                    icon: Icons.straighten,
                    title: 'Measurement Converter',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toUnitConverter(context);
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
                  
                  const SizedBox(height: 16),
                  
                  // SHARE Section
                  _DrawerSectionHeader(
                    title: 'Share',
                  ),
                  _DrawerTile(
                    icon: Icons.camera_alt_outlined,
                    title: 'OCR Import',
                    onTap: () {
                      Navigator.pop(context);
                      AppRoutes.toOCRScanner(context);
                    },
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
                    icon: Icons.qr_code_scanner,
                    title: 'QR Code',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to QR scanner/generator
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('QR Code feature coming soon')),
                      );
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.ios_share,
                    title: 'Share Recipe',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Show share options
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Share feature coming soon')),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Drawer list tile
class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
