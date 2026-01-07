import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/drive_repository.dart';
import '../providers/google_drive_storage.dart';
import '../providers/google_drive_storage.dart';
import '../services/repository_manager.dart';
import '../../../core/widgets/memoix_snackbar.dart';

class ShareRepositoryScreen extends ConsumerStatefulWidget {
  final DriveRepository repository;

  const ShareRepositoryScreen({
    super.key,
    required this.repository,
  });

  @override
  ConsumerState<ShareRepositoryScreen> createState() =>
      _ShareRepositoryScreenState();
}

class _ShareRepositoryScreenState extends ConsumerState<ShareRepositoryScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isInviting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String _generateDeepLink() {
    final encodedName = Uri.encodeComponent(widget.repository.name);
    return 'memoix://share/repo?id=${widget.repository.folderId}&name=$encodedName';
  }

  Future<void> _inviteUser() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    setState(() => _isInviting = true);

    try {
      final storage = ref.read(googleDriveStorageProvider);
      await storage.addPermission(widget.repository.folderId, email);

      if (mounted) {
        MemoixSnackBar.showSuccess('Invitation sent to $email');
        _emailController.clear();
      }
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('Failed to invite: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isInviting = false);
      }
    }
  }

  Future<void> _shareLink() async {
    final link = _generateDeepLink();

    try {
      await Share.share(
        'Join my Memoix repository: ${widget.repository.name}\n\n'
        'Tap this link to add it to your Memoix app:\n$link',
        subject: 'Memoix Repository: ${widget.repository.name}',
      );
    } catch (e) {
      if (mounted) {
        MemoixSnackBar.showError('Failed to share: ${e.toString()}');
      }
    }
  }

  Future<void> _copyLink() async {
    final link = _generateDeepLink();
    await Clipboard.setData(ClipboardData(text: link));

    if (mounted) {
      MemoixSnackBar.show('Link copied to clipboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Repository'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Repository Info Card
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.repository.name,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sharing gives others Editor access to this repository',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Invite by Email Section
            Text(
              'Invite by Email',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a Google account email address to grant immediate access',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'colleague@example.com',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter an email address';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                      enabled: !_isInviting,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isInviting ? null : _inviteUser,
                    child: _isInviting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Invite'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Share Link Section
            Text(
              'Share Link',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Generate a link to share via messaging, email, or other apps',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _shareLink,
              icon: const Icon(Icons.share),
              label: const Text('Share Link'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 8),

            OutlinedButton.icon(
              onPressed: _copyLink,
              icon: const Icon(Icons.copy),
              label: const Text('Copy Link'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(12),
              ),
            ),

            const SizedBox(height: 32),

            // Info Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How Sharing Works',
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Invited users receive Editor access to your Google Drive folder\n'
                    '• They can add, edit, and delete recipes in the shared repository\n'
                    '• Links work offline - the app will verify access when online\n'
                    '• Remove access via Google Drive settings if needed',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
