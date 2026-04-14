import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/memoix_snackbar.dart';
import '../models/storage_location.dart';
import '../models/sync_mode.dart';
import '../models/sync_status.dart';
import '../providers/google_drive_storage.dart';
import '../providers/one_drive_storage.dart';
import '../services/personal_storage_service.dart';
import '../services/shared_storage_manager.dart';
import '../services/storage_provider_manager.dart';
import 'share_storage_screen.dart';
import '../../../core/services/deep_link_service.dart';

enum _RepositoryAction { googleDrive, oneDrive, joinByLink }

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
    // Step 1: Select action
    final action = await _showProviderSelectionDialog();
    if (action == null || !mounted) return;

    // Handle join by link separately
    if (action == _RepositoryAction.joinByLink) {
      await _showJoinByLinkDialog();
      return;
    }

    final provider = action == _RepositoryAction.googleDrive
        ? StorageProvider.googleDrive
        : StorageProvider.oneDrive;

    // Step 2: Get storage location name
    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Shared Storage'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Storage Name',
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

    // Step 3: Create storage location with selected provider
    try {
      MemoixSnackBar.show('Creating shared storage...');

      String folderId;
      
      switch (provider) {
        case StorageProvider.googleDrive:
          final storage = ref.read(googleDriveStorageProvider);
          
          // Ensure Google Drive is connected before attempting to create folder
          if (!storage.isConnected) {
            // Try to connect with 60 second timeout
            final connected = await storage.connect().timeout(
              const Duration(seconds: 60),
              onTimeout: () {
                throw TimeoutException('Connection timed out. Please try again.');
              },
            );
            if (!connected) {
              throw Exception('Connection cancelled or failed');
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
          // Register with service so the subsequent push() uses this instance.
          await ref.read(personalStorageServiceProvider).setProvider(storage);
          break;
          
        case StorageProvider.oneDrive:
          final storage = OneDriveStorage();
          await storage.init();
          
          // Check if connected, sign in if needed
          if (!storage.isConnected) {
            await storage.signIn().timeout(
              const Duration(seconds: 60),
              onTimeout: () {
                throw TimeoutException('Connection timed out. Please try again.');
              },
            );
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
          // Register with service so the subsequent push() uses this instance
          await ref.read(personalStorageServiceProvider).setProvider(storage);
          break;
      }
      await StorageProviderManager.disconnectAllExcept(ref, exceptProvider: provider);
      
      // Sync recipes to new folder
      if (mounted) {
        MemoixSnackBar.show('Syncing recipes to "$name"...');
      }
      
      final service = ref.read(personalStorageServiceProvider);
      await service.push(silent: true);
      
      // Wait a moment for SharedPreferences to persist the updated lastSynced time
      await Future.delayed(const Duration(milliseconds: 100));
      
      _loadRepositories();
      
      if (mounted) {
        MemoixSnackBar.showSuccess('Shared storage "$name" created and synced');
      }
    } on TimeoutException catch (e) {
      if (mounted) {
        MemoixSnackBar.showError(e.message ?? 'Connection timed out');
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showPersistentWithCopy('Failed to create shared storage: $e');
      }
    }
  }

  /// Show options dialog for adding a repository
  Future<_RepositoryAction?> _showProviderSelectionDialog() async {
    final theme = Theme.of(context);

    return showDialog<_RepositoryAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Repository'),
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
              onTap: () => Navigator.pop(ctx, _RepositoryAction.googleDrive),
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
              onTap: () => Navigator.pop(ctx, _RepositoryAction.oneDrive),
            ),
            const SizedBox(height: 8),
            // Join by link option
            ListTile(
              leading: Icon(
                Icons.link,
                color: theme.colorScheme.onSurface,
              ),
              title: const Text('Join by link'),
              subtitle: const Text('Join a shared repository using a share link'),
              onTap: () => Navigator.pop(ctx, _RepositoryAction.joinByLink),
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

  Future<void> _showJoinByLinkDialog() async {
    final uri = await showDialog<Uri>(
      context: context,
      builder: (_) => const _JoinByLinkDialog(),
    );

    if (uri == null || !mounted) return;

    final service = ref.read(deepLinkServiceProvider);
    await service.handleRepositoryShare(context, uri);
    _loadRepositories();
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
            // No saved session — trigger interactive sign-in
            final connected = await storage.connect().timeout(
              const Duration(seconds: 60),
              onTimeout: () {
                throw TimeoutException('Connection timed out. Please try again.');
              },
            );
            if (!connected) {
              throw Exception('Sign-in cancelled or failed');
            }
          }
          
          await storage.switchRepository(repository.folderId, repository.name);
          await ref.read(personalStorageServiceProvider).setProvider(storage);
          break;
        case StorageProvider.oneDrive:
          // OneDrive: sign in if needed, switch folder, and register with service
          final oneDriveStorage = OneDriveStorage();
          await oneDriveStorage.init();
          if (!oneDriveStorage.isConnected) {
            await oneDriveStorage.signIn().timeout(
              const Duration(seconds: 60),
              onTimeout: () {
                throw TimeoutException('Connection timed out. Please try again.');
              },
            );
            if (!oneDriveStorage.isConnected) {
              throw StateError('OneDrive sign-in cancelled. Please try again.');
            }
          }
          await oneDriveStorage.switchRepository(repository.folderId, repository.name);
          await ref.read(personalStorageServiceProvider).setProvider(oneDriveStorage);
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
        MemoixSnackBar.showPersistentWithCopy('Failed to switch storage: $e');
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
        MemoixSnackBar.showPersistentWithCopy('Failed to disconnect: $e');
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
      bool hasAccess;
      switch (storage.provider) {
        case StorageProvider.googleDrive:
          final driveStorage = ref.read(googleDriveStorageProvider);
          hasAccess = await driveStorage.verifyFolderAccess(storage.folderId);
          break;
        case StorageProvider.oneDrive:
          final service = ref.read(personalStorageServiceProvider);
          final provider = service.provider;
          if (provider is! OneDriveStorage || !provider.isConnected) {
            throw Exception('OneDrive is not connected. Switch to this repository first.');
          }
          hasAccess = await provider.verifyFolderAccess(storage.folderId);
          break;
      }

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
              return _StorageCard(
                storage: repo,
                onSwitch: () => _switchRepository(repo),
                onShare: () => _shareRepository(repo),
                onDelete: () => _deleteStorage(repo),
                onDisconnect: () => _disconnectStorage(repo),
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

class _JoinByLinkDialog extends StatefulWidget {
  const _JoinByLinkDialog();

  @override
  State<_JoinByLinkDialog> createState() => _JoinByLinkDialogState();
}

class _JoinByLinkDialogState extends State<_JoinByLinkDialog> {
  final _linkController = TextEditingController();
  final _nameController = TextEditingController();
  String? _linkError;
  String? _nameError;

  @override
  void dispose() {
    _linkController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final input = _linkController.text.trim();
    final name = _nameController.text.trim();

    if (input.isEmpty) {
      setState(() => _linkError = 'Enter a share link or folder ID');
      return;
    }

    Uri? result;

    if (input.startsWith('memoix://')) {
      result = Uri.tryParse(input);
      if (result == null ||
          result.host != 'share' ||
          !result.pathSegments.contains('repo') ||
          (result.queryParameters['id']?.isEmpty ?? true) ||
          (result.queryParameters['name']?.isEmpty ?? true)) {
        setState(() => _linkError = 'Invalid share link');
        return;
      }
    } else {
      // Raw folder ID — name required, provider defaults to Google Drive
      if (name.isEmpty) {
        setState(() => _nameError = 'Name is required for a folder ID');
        return;
      }
      result = Uri(
        scheme: 'memoix',
        host: 'share',
        pathSegments: ['repo'],
        queryParameters: {'id': input, 'name': name},
      );
    }

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join Repository'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                labelText: 'Share link or Folder ID',
                hintText: 'memoix://share/repo?id=... or folder ID',
                errorText: _linkError,
              ),
              autofocus: true,
              onChanged: (_) {
                if (_linkError != null) setState(() => _linkError = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name (required for raw folder ID)',
                hintText: 'My Recipes',
                errorText: _nameError,
              ),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Join'),
        ),
      ],
    );
  }
}

class _StorageCard extends ConsumerWidget {
  final StorageLocation storage;
  final VoidCallback onSwitch;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onDisconnect;
  final VoidCallback onVerify;
  final VoidCallback onRefresh;

  const _StorageCard({
    required this.storage,
    required this.onSwitch,
    required this.onShare,
    required this.onDelete,
    required this.onDisconnect,
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
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        color: theme.colorScheme.primary,
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'share':
                            onShare();
                            break;
                          case 'verify':
                            onVerify();
                            break;
                          case 'disconnect':
                            onDisconnect();
                            break;
                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (!storage.isPendingVerification)
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
                    onPressed: syncStatus.isInProgress ? null : onDisconnect,
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
                        onDisconnect();
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
                    if (!storage.isPendingVerification)
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
