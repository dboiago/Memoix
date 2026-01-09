import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/memoix_snackbar.dart';
import '../models/merge_result.dart';
import '../models/sync_mode.dart';
import '../models/sync_status.dart';
import '../providers/google_drive_storage.dart';
import '../providers/one_drive_storage.dart';
import '../services/personal_storage_service.dart';

/// Personal Storage settings screen
///
/// Shows provider connection status, push/pull buttons, and sync mode toggle.
/// Allows users to backup to their own cloud storage account.
/// See EXTERNAL_STORAGE.md Section 5 for UX requirements.
class PersonalStorageScreen extends ConsumerStatefulWidget {
  const PersonalStorageScreen({super.key});

  @override
  ConsumerState<PersonalStorageScreen> createState() =>
      _PersonalStorageScreenState();
}

class _PersonalStorageScreenState extends ConsumerState<PersonalStorageScreen> {
  /// Google Drive provider instance
  GoogleDriveStorage? _googleDrive;
  
  /// OneDrive provider instance
  OneDriveStorage? _oneDrive;

  /// Loading state for connection operations
  bool _isConnecting = false;

  /// Current sync mode
  SyncMode _syncMode = SyncMode.manual;

  /// Last sync time for display
  DateTime? _lastSyncTime;

  /// Whether the provider is connected
  bool get _isConnected => _googleDrive?.isConnected ?? false;

  @override
  void initState() {
    super.initState();
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    // Initialize Google Drive provider
    _googleDrive = GoogleDriveStorage();
    await _googleDrive!.initialize();

    // Load sync mode and last sync time
    final service = ref.read(personalStorageServiceProvider);
    _syncMode = await service.syncMode;
    _lastSyncTime = await service.lastSyncTime;

    // If connected, set the provider on the service
    if (_googleDrive!.isConnected) {
      await service.setProvider(_googleDrive!);
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Storage'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 16),
        children: [
          // Header explanation (only when not connected)
          if (!_isConnected) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Store your recipes in a location you control. '
                'Your data never touches Memoix servers.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(),
          ],

          // Provider cards
          if (_isConnected)
            _buildConnectedCard(theme, syncStatus)
          else
            _buildProviderSelector(theme),

          // Footer info (only when not connected)
          if (!_isConnected) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Only one storage location can be connected at a time.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build the provider selector when disconnected
  Widget _buildProviderSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Connect a Provider'),
        _buildProviderTile(
          theme: theme,
          icon: Icons.cloud_outlined,
          name: 'Google Drive',
          description: 'Store in your personal Drive folder',
          onConnect: _connectGoogleDrive,
        ),
        _buildProviderTile(
          theme: theme,
          icon: Icons.grid_view,
          name: 'Microsoft OneDrive',
          description: 'Store in your OneDrive folder',
          onConnect: _connectOneDrive,
        ),
        // NOTE: Other providers (GitHub, iCloud) hidden until implemented
        // Implementation remains provider-agnostic internally
      ],
    );
  }

  /// Build a single provider connection tile
  Widget _buildProviderTile({
    required ThemeData theme,
    required IconData icon,
    required String name,
    required String description,
    bool isAdvanced = false,
    bool isDisabled = false,
    VoidCallback? onConnect,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDisabled
            ? theme.colorScheme.outline
            : theme.colorScheme.onSurface,
      ),
      title: Row(
        children: [
          Text(
            name,
            style: TextStyle(
              color: isDisabled
                  ? theme.colorScheme.outline
                  : theme.colorScheme.onSurface,
            ),
          ),
          if (isAdvanced) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Advanced',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        description,
        style: TextStyle(
          color: isDisabled
              ? theme.colorScheme.outline
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _isConnecting
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isDisabled
              ? null
              : TextButton(
                  onPressed: onConnect,
                  child: const Text('Connect'),
                ),
      enabled: !isDisabled && !_isConnecting,
    );
  }

  /// Build the connected state card with push/pull buttons
  Widget _buildConnectedCard(ThemeData theme, SyncStatus syncStatus) {
    final provider = _googleDrive!;

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
                    Icons.cloud_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.name,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          provider.connectedPath ?? '/My Drive/Memoix',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sync status indicator
                  _buildSyncStatusIndicator(theme, syncStatus),
                ],
              ),

              const SizedBox(height: 8),

              // Last synced timestamp
              if (_lastSyncTime != null)
                Text(
                  'Last synced: ${_formatTimeAgo(_lastSyncTime!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Sync mode toggle
              _buildSyncModeSection(theme),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Push/Pull buttons
              _buildPushPullButtons(theme, syncStatus),

              const SizedBox(height: 16),

              // Disconnect button
              Center(
                child: TextButton(
                  onPressed: syncStatus.isInProgress ? null : _disconnect,
                  child: Text(
                    'Disconnect',
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

  /// Build sync status indicator icon
  Widget _buildSyncStatusIndicator(ThemeData theme, SyncStatus status) {
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
            color: theme.colorScheme.primary,
          ),
        );
      case SyncStatus.error:
        return Icon(
          Icons.cloud_off_outlined,
          color: theme.colorScheme.secondary,
        );
    }
  }

  /// Build sync mode toggle section
  Widget _buildSyncModeSection(ThemeData theme) {
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
              selected: {_syncMode},
              onSelectionChanged: (selection) {
                _setSyncMode(selection.first);
              },
              showSelectedIcon: false,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _syncMode.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // Additional explanation for automatic mode
        if (_syncMode == SyncMode.automatic) ...[
          const SizedBox(height: 4),
          Text(
            'When the same recipe is edited on multiple devices, '
            'the most recently saved version is kept.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  /// Build push and pull buttons
  Widget _buildPushPullButtons(ThemeData theme, SyncStatus syncStatus) {
    final isDisabled = syncStatus.isInProgress;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isDisabled ? null : _push,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(
              syncStatus == SyncStatus.pushing ? 'Pushing...' : 'Push',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            onPressed: isDisabled ? null : _pull,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(
              syncStatus == SyncStatus.pulling ? 'Pulling...' : 'Pull',
            ),
          ),
        ),
      ],
    );
  }

  // ============ ACTIONS ============

  /// Connect to Google Drive
  Future<void> _connectGoogleDrive() async {
    setState(() => _isConnecting = true);

    try {
      final success = await _googleDrive!.connect();

      if (success) {
        // Set provider on service
        final service = ref.read(personalStorageServiceProvider);
        await service.setProvider(_googleDrive!);

        // Check if user has ever synced before
        final hasEverSynced = await service.lastSyncTime != null;
        
        if (mounted) {
          if (hasEverSynced) {
            // User has synced before - just silently pull to sync any changes
            MemoixSnackBar.showSuccess('Connected to Google Drive');
            _executeDirectPull(showFullSummary: false);
          } else {
            // First-time connection - check if remote has existing data
            final hasData = await _googleDrive!.hasExistingData();
            if (hasData) {
              // Show initial sync prompt only on first connection
              _showInitialSyncDialog();
            } else {
              MemoixSnackBar.showSuccess('Connected to Google Drive');
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('Connection failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  /// Connect to Microsoft OneDrive
  Future<void> _connectOneDrive() async {
    setState(() => _isConnecting = true);

    try {
      // Initialize OneDrive storage
      _oneDrive = OneDriveStorage();
      await _oneDrive!.init();
      
      // Attempt sign in
      await _oneDrive!.signIn();

      if (_oneDrive!.isConnected) {
        // Note: OneDrive integration is in progress
        // Full PersonalStorageService integration will be completed in a future update
        if (mounted) {
          MemoixSnackBar.showSuccess('Connected to Microsoft OneDrive');
        }
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('OneDrive connection failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  /// Show dialog when connecting to folder with existing data
  void _showInitialSyncDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Existing Data Found'),
        content: const Text(
          'This storage location contains existing recipes. '
          'What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Execute pull directly (no confirmation needed - user just connected)
              _executeDirectPull();
            },
            child: const Text('Pull: Import these recipes'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showPushConfirmation();
            },
            child: const Text('Push: Overwrite with local'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              MemoixSnackBar.showSuccess('Connected to Google Drive');
            },
            child: const Text('Skip: Sync later'),
          ),
        ],
      ),
    );
  }

  /// Execute pull directly without confirmation (used during initial sync and auto-sync on reconnect)
  Future<void> _executeDirectPull({bool showFullSummary = true}) async {
    final service = ref.read(personalStorageServiceProvider);
    final result = await service.pull(silent: true);

    // Refresh last sync time
    _lastSyncTime = await service.lastSyncTime;
    if (mounted) setState(() {});

    // Show appropriate feedback
    if (!mounted) return;
    
    if (result.hasFailed) {
      MemoixSnackBar.showError('Pull failed: ${result.error}');
    } else if (result.wasSkipped) {
      // Silent - no message needed
    } else {
      if (showFullSummary) {
        // First-time sync: show detailed dialog
        _showPullSummaryDialog(result);
      } else {
        // Auto-sync on reconnect: just show simple toast if changes detected
        if (result.hasChanges) {
          final parts = <String>[];
          if (result.added > 0) parts.add('${result.added} new');
          if (result.updated > 0) parts.add('${result.updated} updated');
          MemoixSnackBar.show('Synced: ${parts.join(', ')}');
        }
        // No message if no changes
      }\n    }\n  }

  /// Show confirmation dialog before pushing
  void _showPushConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Push to Google Drive?'),
        content: Text(
          'This will upload your local recipes to:\n'
          '${_googleDrive?.connectedPath ?? "/My Drive/Memoix"}\n\n'
          'This will overwrite any existing recipes in that location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _push();
            },
            child: const Text('Push Now'),
          ),
        ],
      ),
    );
  }

  /// Execute push operation
  Future<void> _push() async {
    final service = ref.read(personalStorageServiceProvider);
    await service.push();

    // Refresh last sync time
    _lastSyncTime = await service.lastSyncTime;
    if (mounted) setState(() {});
  }

  /// Execute pull operation with confirmation dialog
  /// 
  /// Shows pre-pull confirmation and post-pull summary per EXTERNAL_STORAGE.md Section 6.2.
  Future<void> _pull() async {
    final service = ref.read(personalStorageServiceProvider);
    
    // First, check if pull is needed by doing a silent comparison
    // This uses the smart meta check to avoid downloading data unnecessarily
    final result = await service.pull(silent: true);
    
    // Refresh last sync time
    _lastSyncTime = await service.lastSyncTime;
    if (mounted) setState(() {});

    if (!mounted) return;
    
    // Handle different scenarios
    if (result.hasFailed) {
      MemoixSnackBar.showError('Pull failed: ${result.error}');
      return;
    }
    
    if (result.wasSkipped || !result.hasChanges) {
      // No changes detected - silent sync complete
      MemoixSnackBar.show('Already up to date');
      return;
    }
    
    // Changes were found and applied - show summary
    _showPullSummaryDialog(result);
  }

  /// Show confirmation dialog before pulling
  /// 
  /// Per EXTERNAL_STORAGE.md Section 6.2 "Manual Confirmation Dialog"
  Future<bool?> _showPullConfirmation() async {
    // First, get remote recipe count for the dialog
    final remoteCount = await _googleDrive?.getRemoteRecipeCount();
    
    if (!mounted) return false;
    
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pull from Google Drive?'),
        content: Text(
          'Found ${remoteCount ?? 'recipes'} recipes in:\n'
          '${_googleDrive?.connectedPath ?? "/My Drive/Memoix"}\n\n'
          'New recipes will be added.\n'
          'Conflicts resolved by newest wins.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pull Now'),
          ),
        ],
      ),
    );
  }

  /// Show summary dialog after successful pull
  /// 
  /// Per EXTERNAL_STORAGE.md Section 6.2 "Post-Pull Summary (Manual)"
  void _showPullSummaryDialog(PullResult result) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        
        return AlertDialog(
          title: const Text('Pull Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.added > 0)
                _buildSummaryRow(
                  theme,
                  icon: Icons.check_circle_outline,
                  text: '${result.added} new recipe${result.added == 1 ? '' : 's'} added',
                  isHighlight: true,
                ),
              if (result.updated > 0)
                _buildSummaryRow(
                  theme,
                  icon: Icons.check_circle_outline,
                  text: '${result.updated} recipe${result.updated == 1 ? '' : 's'} updated',
                  isHighlight: true,
                ),
              if (result.unchanged > 0)
                _buildSummaryRow(
                  theme,
                  icon: Icons.radio_button_unchecked,
                  text: '${result.unchanged} recipe${result.unchanged == 1 ? '' : 's'} unchanged',
                  isHighlight: false,
                ),
              if (!result.hasChanges)
                _buildSummaryRow(
                  theme,
                  icon: Icons.check_circle_outline,
                  text: 'Everything up to date',
                  isHighlight: true,
                ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  /// Build a single row in the pull summary dialog
  Widget _buildSummaryRow(
    ThemeData theme, {
    required IconData icon,
    required String text,
    required bool isHighlight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isHighlight
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isHighlight
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Set sync mode
  Future<void> _setSyncMode(SyncMode mode) async {
    try {
      final service = ref.read(personalStorageServiceProvider);
      await service.setSyncMode(mode);
      setState(() => _syncMode = mode);
    } catch (e) {
      MemoixSnackBar.showError('$e');
    }
  }

  /// Disconnect from current provider
  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect?'),
        content: const Text(
          'Disconnecting will not delete your recipes from Google Drive. '
          'You can reconnect anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final service = ref.read(personalStorageServiceProvider);
      await service.disconnect();
      _googleDrive = GoogleDriveStorage();
      _lastSyncTime = null;
      if (mounted) setState(() {});
      MemoixSnackBar.show('Disconnected from Google Drive');
    }
  }

  /// Show placeholder for GitHub (not yet implemented)
  void _showGitHubNotImplemented() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('GitHub Storage'),
        content: const Text(
          'GitHub storage is for advanced users and requires a personal '
          'access token with repository access.\n\n'
          'This feature is coming soon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Format timestamp as human-readable "time ago"
  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else {
      return '${time.month}/${time.day}/${time.year}';
    }
  }
}

/// Section header widget (matches settings screen pattern)
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
