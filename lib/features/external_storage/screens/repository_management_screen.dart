import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drive_repository.dart';
import '../services/repository_manager.dart';
import '../services/external_storage_service.dart';
import '../providers/google_drive_storage.dart';
import '../providers/one_drive_storage.dart';
import 'share_repository_screen.dart';
import '../../../core/widgets/memoix_snackbar.dart';

class RepositoryManagementScreen extends ConsumerStatefulWidget {
  const RepositoryManagementScreen({super.key});

  @override
  ConsumerState<RepositoryManagementScreen> createState() =>
      _RepositoryManagementScreenState();
}

class _RepositoryManagementScreenState
    extends ConsumerState<RepositoryManagementScreen> {
  late Future<List<DriveRepository>> _repositoriesFuture;
  final _manager = RepositoryManager();

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
      
      // Sync recipes to new folder
      if (mounted) {
        MemoixSnackBar.show('Syncing recipes to "$name"...');
      }
      
      final service = ref.read(externalStorageServiceProvider);
      await service.push(silent: true);
      
      _loadRepositories();
      
      if (mounted) {
        MemoixSnackBar.showSuccess('Repository "$name" created and synced');
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('Failed to create repository: $e');
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

  Future<void> _switchRepository(DriveRepository repository) async {
    try {
      // Update active repository in manager
      await _manager.setActiveRepository(repository.id);
      
      // Update GoogleDriveStorage to use the new folder
      final storage = ref.read(googleDriveStorageProvider);
      await storage.switchRepository(repository.folderId, repository.name);
      
      _loadRepositories();
      
      if (mounted) {
        MemoixSnackBar.showSuccess('Switched to "${repository.name}"');
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('Failed to switch repository: $e');
      }
    }
  }

  Future<void> _deleteRepository(DriveRepository repository) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Repository'),
        content: Text(
          'Remove "${repository.name}" from this device?\n\n'
          'This will not delete the ${repository.provider.displayName} folder.',
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
      await _manager.removeRepository(repository.id);
      _loadRepositories();
      
      if (mounted) {
        MemoixSnackBar.show('Repository removed');
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('Failed to remove repository: $e');
      }
    }
  }

  Future<void> _verifyRepository(DriveRepository repository) async {
    try {
      final storage = ref.read(googleDriveStorageProvider);
      final hasAccess = await storage.verifyFolderAccess(repository.folderId);

      if (!mounted) return;

      if (hasAccess) {
        await _manager.markAsVerified(repository.id);
        _loadRepositories();
        MemoixSnackBar.showSuccess('Access verified for "${repository.name}"!');
      } else {
        await _manager.markAsAccessDenied(repository.id);
        _loadRepositories();
        MemoixSnackBar.showError('Access denied. Request permission from repository owner.');
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('Could not verify (check connection)');
      }
    }
  }

  Future<void> _shareRepository(DriveRepository repository) async {
    if (!mounted) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShareRepositoryScreen(repository: repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repositories'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewRepository,
        icon: const Icon(Icons.add),
        label: const Text('Add Repository'),
      ),
      body: FutureBuilder<List<DriveRepository>>(
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
                repository: repo,
                onSwitch: () => _switchRepository(repo),
                onShare: () => _shareRepository(repo),
                onDelete: () => _deleteRepository(repo),
                onVerify: () => _verifyRepository(repo),
              );
            },
          );
        },
      ),
    );
  }
}

class _RepositoryCard extends StatelessWidget {
  final DriveRepository repository;
  final VoidCallback onSwitch;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onVerify;

  const _RepositoryCard({
    required this.repository,
    required this.onSwitch,
    required this.onShare,
    required this.onDelete,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Active repository: prominent UI with direct access
    if (repository.isActive) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: theme.colorScheme.secondary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                repository.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.secondary,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                'Active',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (repository.isPendingVerification) ...[
                          Row(
                            children: [
                              Icon(
                                repository.accessDenied
                                    ? Icons.block
                                    : Icons.schedule,
                                size: 16,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  repository.accessDenied
                                      ? 'Access denied - Tap to resolve'
                                      : 'Waiting for connection',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Icon(
                                Icons.cloud_done,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getSyncStatusText(repository),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Settings icon for active repository
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.settings,
                        color: theme.colorScheme.onSurface,
                      ),
                      tooltip: 'Repository Settings',
                      itemBuilder: (context) => [
                        if (!repository.isPendingVerification)
                          const PopupMenuItem(
                            value: 'share',
                            child: ListTile(
                              leading: Icon(Icons.share),
                              title: Text('Share'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        if (repository.isPendingVerification)
                          const PopupMenuItem(
                            value: 'verify',
                            child: ListTile(
                              leading: Icon(Icons.refresh),
                              title: Text('Verify Access'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'disconnect',
                          child: ListTile(
                            leading: Icon(
                              Icons.link_off,
                              color: theme.colorScheme.secondary,
                            ),
                            title: Text(
                              'Disconnect',
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        switch (value) {
                          case 'share':
                            onShare();
                            break;
                          case 'verify':
                            onVerify();
                            break;
                          case 'disconnect':
                            onDelete();
                            break;
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Inactive repository: minimal clean UI
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onSwitch,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repository.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    if (repository.isPendingVerification) ...[
                      Row(
                        children: [
                          Icon(
                            repository.accessDenied
                                ? Icons.block
                                : Icons.schedule,
                            size: 14,
                            color: theme.colorScheme.secondary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              repository.accessDenied
                                  ? 'Access denied'
                                  : 'Pending verification',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        _getSyncStatusText(repository),
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
                icon: const Icon(Icons.more_vert),
                tooltip: 'More options',
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'activate',
                    child: ListTile(
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('Set as Active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (!repository.isPendingVerification)
                    const PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                        leading: Icon(Icons.share),
                        title: Text('Share'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (repository.isPendingVerification)
                    const PopupMenuItem(
                      value: 'verify',
                      child: ListTile(
                        leading: Icon(Icons.refresh),
                        title: Text('Verify Access'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'remove',
                    child: ListTile(
                      leading: Icon(
                        repository.isPendingVerification
                            ? Icons.link_off
                            : Icons.delete_outline,
                        color: theme.colorScheme.secondary,
                      ),
                      title: Text(
                        repository.isPendingVerification ? 'Disconnect' : 'Remove',
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
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
                    case 'remove':
                      onDelete();
                      break;
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get sync status text based on repository state
  String _getSyncStatusText(DriveRepository repo) {
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
