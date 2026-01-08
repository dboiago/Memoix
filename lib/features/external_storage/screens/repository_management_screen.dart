import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/drive_repository.dart';
import '../services/repository_manager.dart';
import '../providers/google_drive_storage.dart';
import '../providers/google_drive_storage.dart';
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

    try {
      MemoixSnackBar.show('Creating repository...');
      
      final storage = ref.read(googleDriveStorageProvider);
      
      // Create a new folder in Google Drive
      final folderId = await storage.createFolder(name);
      
      // Register in RepositoryManager
      await _manager.addRepository(
        name: name,
        folderId: folderId,
        isPendingVerification: false,
      );
      
      _loadRepositories();
      
      if (mounted) {
        MemoixSnackBar.showSuccess('Repository "$name" created');
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('Failed to create repository: $e');
      }
    }
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
          'This will not delete the Google Drive folder.',
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          if (repository.isActive) ...[
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
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (repository.isPendingVerification) ...[
                        Row(
                          children: [
                            Icon(
                              repository.accessDenied
                                  ? Icons.block
                                  : Icons.warning_amber,
                              size: 16,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                repository.accessDenied
                                    ? 'Access denied - Request permission from owner'
                                    : 'Pending verification - Tap to retry',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Text(
                          'Last verified: ${_formatDate(repository.lastVerified)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!repository.isActive)
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.swap_horiz),
                                title: const Text('Switch to This'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onSwitch();
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.share),
                                title: const Text('Share'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onShare();
                                },
                              ),
                              if (repository.isPendingVerification)
                                ListTile(
                                  leading: const Icon(Icons.refresh),
                                  title: const Text('Verify Access'),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    onVerify();
                                  },
                                ),
                              ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.secondary,
                                ),
                                title: Text(
                                  'Remove',
                                  style: TextStyle(
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  onDelete();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            if (repository.isActive) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                  if (repository.isPendingVerification) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onVerify,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Verify'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Never';
    
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
