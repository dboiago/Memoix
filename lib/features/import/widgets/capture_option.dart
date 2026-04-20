import 'package:flutter/material.dart';

/// Reusable photo-capture card used by [OCRScannerScreen] and [AiImportScreen].
class CaptureOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const CaptureOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(label, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}
