import 'package:flutter/material.dart';

/// Dialog shown when an update is available
class UpdateAvailableDialog extends StatefulWidget {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String releaseUrl;
  final Future<bool> Function() onUpdate;
  final VoidCallback onDismiss;

  const UpdateAvailableDialog({
    super.key,
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.releaseUrl,
    required this.onUpdate,
    required this.onDismiss,
  });

  @override
  State<UpdateAvailableDialog> createState() => _UpdateAvailableDialogState();
}

class _UpdateAvailableDialogState extends State<UpdateAvailableDialog> {
  bool _isInstalling = false;
  String _installStatus = '';

  Future<void> _handleUpdate() async {
    setState(() {
      _isInstalling = true;
      _installStatus = 'Downloading update...';
    });

    final success = await widget.onUpdate();

    if (!mounted) return;

    if (success) {
      setState(() {
        _installStatus = 'Update installed! Restarting app...';
      });
      // App will restart automatically after installation
      await Future.delayed(const Duration(seconds: 2));
    } else {
      setState(() {
        _installStatus = 'Installation failed. Opening download page...';
      });
      // Fallback: open browser to download manually
      // This is handled by caller
      Navigator.pop(context, 'openBrowser');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isInstalling) {
      return AlertDialog(
        icon: Icon(
          Icons.system_update,
          color: theme.colorScheme.primary,
          size: 32,
        ),
        title: const Text('Installing Update'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_installStatus),
          ],
        ),
      );
    }

    return AlertDialog(
      icon: Icon(
        Icons.system_update,
        color: theme.colorScheme.primary,
        size: 32,
      ),
      title: const Text('Update Available'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version ${widget.latestVersion} is now available (currently ${widget.currentVersion})',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'What\'s new:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                child: Text(
                  widget.releaseNotes,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onDismiss,
          child: const Text('Later'),
        ),
        FilledButton.icon(
          onPressed: _handleUpdate,
          icon: const Icon(Icons.download),
          label: const Text('Update Now'),
        ),
      ],
    );
  }
}
