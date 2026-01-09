import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/widgets/memoix_snackbar.dart';
import '../models/storage_location.dart';
import '../models/sync_mode.dart';
import '../models/sync_status.dart';
import '../providers/google_drive_storage.dart';
import '../providers/one_drive_storage.dart';
import '../services/personal_storage_service.dart';
import '../services/shared_storage_manager.dart';
import 'personal_storage_screen.dart';
import 'share_storage_screen.dart';

class SharedStorageScreen extends ConsumerStatefulWidget {
  const SharedStorageScreen({super.key});

  @override
  ConsumerState<SharedStorageScreen> createState() =>
      _SharedStorageScreenState();
}

class _SharedStorageScreenState
    extends ConsumerState<SharedStorageScreen> {
  late Future<List<StorageLocation>> _repositoriesFuture;
  final _manager = SharedStorageManager();

  @override
  void initState() {
    super.initState();
    _loadRepositories();
  }

  void _loadRepositories() {
    setState(() {
      _repositoriesFuture = _manager.loadRepositories();
    });
  }

  Future<void> _createNewRepository() async {
    // Step 1: Select provider
    final provider = await _showProviderSelectionDialog();
    if (provider == null || !mounted) return;

    // Step 2: Get repository name
    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Repository'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Repository Name',
            hintText: 'My Recipes',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    // Step 3: Create repository with selected provider
    try {
      MemoixSnackBar.show('Creating repository...');

      String folderId;
      
      switch (provider) {
        case StorageProvider.googleDrive:
          final storage = ref.read(googleDriveStorageProvider);
          
          // Ensure Google Drive is connected before attempting to create folder
          if (!storage.isConnected) {
            // Try to connect
            final connected = await storage.connect();
            if (!connected) {
              throw Exception('Please connect to Google Drive first');
            }
          }
          
          folderId = await storage.createFolder(name);
          
          // Register and switch
          await _manager.addRepository(
            name: name,
            folderId: folderId,
            setAsActive: true,
            isPendingVerification: false,
            provider: StorageProvider.googleDrive,
          );
          
          await storage.switchRepository(folderId, name);
          break;
          
        case StorageProvider.oneDrive:
          final storage = OneDriveStorage();
          await storage.init();
          
          // Check if connected, sign in if needed
          if (!storage.isConnected) {
            await storage.signIn();
          }
          
          folderId = await storage.createFolder(name);
          
          // Register and switch
          await _manager.addRepository(
            name: name,
            folderId: folderId,
            setAsActive: true,
            isPendingVerification: false,
            provider: StorageProvider.oneDrive,
          );
          
          await storage.switchRepository(folderId, name);
          break;
      }
      
      // Disconnect Personal Storage (mutual exclusivity)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('personal_storage_provider_id');
      await prefs.remove('personal_storage_path');
      
      // Sync recipes to new folder
      if (mounted) {
        MemoixSnackBar.show('Syncing recipes to "$name"...');
      }
      
      final service = ref.read(personalStorageServiceProvider);
      await service.push(silent: true);
      
      _loadRepositories();
      
      if (mounted) {
        MemoixSnackBar.showSuccess('Shared storage "$name" created and synced');
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('Failed to create shared storage: $e');
      }
    }
  }

  /// Show provider selection dialog
  Future<StorageProvider?> _showProviderSelectionDialog() async {
    final theme = Theme.of(context);
    
    return showDialog<StorageProvider>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Storage Provider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Google Drive option
            ListTile(
              leading: Icon(
                Icons.cloud_outlined,
                color: theme.colorScheme.onSurface,
              ),
              title: const Text('Google Drive'),
              subtitle: const Text('Store in your personal Drive folder'),
              onTap: () => Navigator.pop(ctx, StorageProvider.googleDrive),
            ),
            const SizedBox(height: 8),
            // OneDrive option
            ListTile(
              leading: Icon(
                Icons.grid_view,
                color: theme.colorScheme.onSurface,
              ),
              title: const Text('Microsoft OneDrive'),
              subtitle: const Text('Store in your OneDrive folder'),
              onTap: () => Navigator.pop(ctx, StorageProvider.oneDrive),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _switchRepository(StorageLocation repository) async {
    // Show loading indicator
    if (mounted) {
      MemoixSnackBar.show('Switching to "${repository.name}"...');
    }
    
    try {      
      // Update active repository in manager (handles provider initialization)
      await _manager.setActiveRepository(repository.id);
      
      // Update provider-specific storage to use the new folder
      switch (repository.provider) {
        case StorageProvider.googleDrive:
          final storage = ref.read(googleDriveStorageProvider);
          
          // Always initialize to ensure _driveApi is ready
          // This is needed when switching from another provider
          await storage.initialize();
          
          if (!storage.isConnected) {
            throw StateError('Google Drive connection could not be restored. Please reconnect.');
          }
          
          await storage.switchRepository(repository.folderId, repository.name);
          break;
        case StorageProvider.oneDrive:
          // OneDrive switch is handled in SharedStorageManager.setActiveRepository
          break;
      }
      
      _loadRepositories();
      
      if (mounted) {
        MemoixSnackBar.showSuccess('Switched to "${repository.name}"');
      }
    } catch (e) {
      // Reload repositories in case state changed
      _loadRepositories();
      
      if (mounted) {
        MemoixSnackBar.showError('Failed to switch storage: $e');
      }
    }
  }

  Future<void> _disconnectStorage(StorageLocation storage) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Storage'),
        content: Text(
          'Disconnect from "${storage.name}"?\n\n'
          'You can reconnect to it later from the storage list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Just deactivate, don't delete
      final repos = await _manager.loadRepositories();
      final updated = repos.map((r) {
        if (r.id == storage.id) {
          return r.copyWith(isActive: false);
        }
        return r;
      }).toList();
      await _manager.saveRepositories(updated);
      
      _loadRepositories();
      
      if (mounted) {
        MemoixSnackBar.show('Disconnected from "${storage.name}"');
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('Failed to disconnect: $e');
      }
    }
  }

  Future<void> _deleteStorage(StorageLocation storage) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Storage Location'),
        content: Text(
          'Remove "${storage.name}" from this device?\n\n'
          'This will not delete the ${storage.provider.displayName} folder.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.secondary,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _manager.removeRepository(storage.id);
      _loadRepositories();
      
      if (mounted) {
        MemoixSnackBar.show('Storage location removed');
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('Failed to remove storage location: $e');
      }
    }
  }

  Future<void> _verifyStorage(StorageLocation storage) async {
    try {
      final driveStorage = ref.read(googleDriveStorageProvider);
      final hasAccess = await driveStorage.verifyFolderAccess(storage.folderId);

      if (!mounted) return;

      if (hasAccess) {
        await _manager.markAsVerified(storage.id);
        _loadRepositories();
        MemoixSnackBar.showSuccess('Access verified for "${storage.name}"!');
      } else {
        await _manager.markAsAccessDenied(storage.id);
        _loadRepositories();
        MemoixSnackBar.showError('Access denied. Request permission from storage owner.');
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('Could not verify (check connection)');
      }
    }
  }

  Future<void> _shareRepository(StorageLocation repository) async {
    if (!mounted) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareStorageScreen(repository: repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Storage'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewRepository,
        icon: const Icon(Icons.add),
        label: const Text('Add Repository'),
      ),
      body: FutureBuilder<List<StorageLocation>>(
        future: _repositoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final repositories = snapshot.data ?? [];

          if (repositories.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_off,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Repositories',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a repository to get started',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: repositories.length,
            itemBuilder: (context, index) {
              final repo = repositories[index];
              return _RepositoryCard(
                storage: repo,
                onSwitch: () => _switchRepository(repo),
                onShare: () => _shareRepository(repo),
                onDelete: () => _deleteStorage(repo),
                onVerify: () => _verifyStorage(repo),
                onRefresh: _loadRepositories,
              );
            },
          );
        },
      ),
    );
  }
}

class _RepositoryCard extends ConsumerWidget {
  final StorageLocation storage;
  final VoidCallback onSwitch;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onVerify;
  final VoidCallback onRefresh;

  const _RepositoryCard({
    required this.storage,
    required this.onSwitch,
    required this.onShare,
    required this.onDelete,
    required this.onVerify,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final syncStatus = ref.watch(syncStatusProvider);

    // Active repository: Full card with sync controls
    if (storage.isActive) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Provider header
                Row(
                  children: [
                    Icon(
                      storage.provider == StorageProvider.oneDrive
                          ? Icons.grid_view
                          : Icons.cloud_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            storage.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            storage.provider.displayName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildSyncStatusIcon(theme, syncStatus),
                  ],
                ),

                const SizedBox(height: 8),

                // Last synced timestamp
                if (!storage.isPendingVerification)
                  Text(
                    _getSyncStatusText(storage),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Sync mode toggle
                _buildSyncModeSection(theme, ref, onRefresh),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Push/Pull buttons
                _buildPushPullButtons(theme, syncStatus, ref, onRefresh),

                const SizedBox(height: 16),

                // Disconnect button
                Center(
                  child: TextButton(
                    onPressed: syncStatus.isInProgress ? null : () => _disconnectStorage(storage),
                    child: Text(
                      storage.isPendingVerification ? 'Remove' : 'Disconnect',
                      style: TextStyle(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Inactive repository: Simple ListTile-like layout
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: InkWell(
          onTap: onSwitch,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  storage.provider == StorageProvider.oneDrive
                      ? Icons.grid_view
                      : Icons.cloud_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storage.name,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      if (storage.isPendingVerification) ...[
                        Text(
                          storage.accessDenied
                              ? 'Access denied'
                              : 'Pending verification',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ] else ...[
                        Text(
                          '${storage.provider.displayName} • ${_getSyncStatusText(storage)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Three-dot menu for inactive repositories
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.primary,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'activate':
                        onSwitch();
                        break;
                      case 'share':
                        onShare();
                        break;
                      case 'verify':
                        onVerify();
                        break;
                      case 'disconnect':
                        _disconnectStorage(storage);
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'activate',
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 20,
                            color: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 12),
                          const Text('Set as Active'),
                        ],
                      ),
                    ),
                    if (!repository.isPendingVerification)
                      PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(
                              Icons.share,
                              size: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            const Text('Share'),
                          ],
                        ),
                      ),
                    if (storage.isPendingVerification)
                      PopupMenuItem(
                        value: 'verify',
                        child: Row(
                          children: [
                            Icon(
                              Icons.refresh,
                              size: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            const Text('Verify Access'),
                          ],
                        ),
                      ),
                    if (!storage.isPendingVerification)
                      PopupMenuItem(
                        value: 'disconnect',
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 20,
                              color: theme.colorScheme.onSurface,
                            ),
                            const SizedBox(width: 12),
                            const Text('Disconnect'),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                              storage.isPendingVerification ? 'Remove' : 'Delete',
                            style: TextStyle(
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build sync status icon
  Widget _buildSyncStatusIcon(ThemeData theme, SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Icon(
          Icons.cloud_done_outlined,
          color: theme.colorScheme.primary,
        );
      case SyncStatus.pushing:
      case SyncStatus.pulling:
        return SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
          ),
        );
      case SyncStatus.error:
        return Icon(
          Icons.error_outline,
          color: theme.colorScheme.secondary,
        );
    }
  }

  /// Build sync mode section
  Widget _buildSyncModeSection(ThemeData theme, WidgetRef ref, VoidCallback onRefresh) {
    return FutureBuilder<SyncMode>(
      future: ref.read(personalStorageServiceProvider).syncMode,
      builder: (context, snapshot) {
        final mode = snapshot.data ?? SyncMode.manual;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sync Mode',
                  style: theme.textTheme.titleSmall,
                ),
                SegmentedButton<SyncMode>(
                  segments: const [
                    ButtonSegment(
                      value: SyncMode.manual,
                      label: Text('Manual'),
                    ),
                    ButtonSegment(
                      value: SyncMode.automatic,
                      label: Text('Automatic'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) async {
                    final service = ref.read(personalStorageServiceProvider);
                    await service.setSyncMode(selection.first);
                    onRefresh();
                  },
                  showSelectedIcon: false,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              mode.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build push/pull buttons
  Widget _buildPushPullButtons(ThemeData theme, SyncStatus syncStatus, WidgetRef ref, VoidCallback onRefresh) {
    final isDisabled = syncStatus.isInProgress;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isDisabled ? null : () async {
              final service = ref.read(personalStorageServiceProvider);
              await service.push(silent: false);
              onRefresh();
            },
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(
              syncStatus == SyncStatus.pushing ? 'Pushing...' : 'Push',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            onPressed: isDisabled ? null : () async {
              final service = ref.read(personalStorageServiceProvider);
              await service.pull(silent: false);
              onRefresh();
            },
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(
              syncStatus == SyncStatus.pulling ? 'Pulling...' : 'Pull',
            ),
          ),
        ),
      ],
    );
  }

  /// Get sync status text based on repository state
  String _getSyncStatusText(StorageLocation repo) {
    if (repo.lastSynced == null) {
      return 'New • Not synced yet';
    }
    return 'Last synced: ${_formatSyncTime(repo.lastSynced!)}';
  }

  /// Format sync time in a user-friendly way
  String _formatSyncTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    // Today
    if (difference.inDays == 0) {
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else {
        // Format as "Today at 4:30 PM"
        final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
        final minute = date.minute.toString().padLeft(2, '0');
        final period = date.hour >= 12 ? 'PM' : 'AM';
        return 'Today at $hour:$minute $period';
      }
    }
    
    // Yesterday
    if (difference.inDays == 1) {
      final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return 'Yesterday at $hour:$minute $period';
    }
    
    // This week
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    
    // Older
    return '${date.day}/${date.month}/${date.year}';
  }
}
