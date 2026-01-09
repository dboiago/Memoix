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

    final input = _emailController.text.trim();
    // Split by semicolon and filter out empty strings
    final emails = input
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (emails.isEmpty) return;

    setState(() => _isInviting = true);

    int successCount = 0;
    int failCount = 0;
    String? lastError;

    try {
      final storage = ref.read(googleDriveStorageProvider);
      
      for (final email in emails) {
        try {
          await storage.addPermission(widget.repository.folderId, email);
          successCount++;
        } catch (e) {
          failCount++;
          lastError = e.toString();
        }
      }

      if (mounted) {
        if (successCount > 0 && failCount == 0) {
          // All succeeded
          if (successCount == 1) {
            MemoixSnackBar.showSuccess('Invitation sent to ${emails.first}');
          } else {
            MemoixSnackBar.showSuccess('Invitations sent to $successCount users');
          }
          _emailController.clear();
          setState(() {}); // Update button state
        } else if (successCount > 0 && failCount > 0) {
          // Partial success
          MemoixSnackBar.show('$successCount sent, $failCount failed');
        } else {
          // All failed
          MemoixSnackBar.showError('Failed to invite: ${lastError ?? "Unknown error"}');
        }
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
              'Add a Google account email address to grant immediate access. '
              'Separate multiple addresses with a semicolon (;)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),

            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email Address(es)',
                      hintText: 'colleague@example.com; friend@gmail.com',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: _emailController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _emailController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter at least one email address';
                      }
                      // Validate each email in the semicolon-separated list
                      final emails = value.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty);
                      for (final email in emails) {
                        if (!email.contains('@') || !email.contains('.')) {
                          return 'Invalid email: $email';
                        }
                      }
                      return null;
                    },
                    enabled: !_isInviting,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isInviting || _emailController.text.isEmpty
                        ? null
                        : _inviteUser,
                    icon: _isInviting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isInviting ? 'Sending...' : 'Send Invitation(s)'),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'How Sharing Works',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Invited users receive Editor access to your Google Drive folder\n'
                      '• They can add, edit, and delete recipes in the shared repository\n'
                      '• Links work offline - the app will verify access when online\n'
                      '• Remove access via Google Drive settings if needed',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
