import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../sharing/services/share_service.dart';
import '../../recipes/screens/recipe_edit_screen.dart';
import '../../../core/widgets/memoix_snackbar.dart';

/// QR Code scanner screen for importing shared recipes
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  String? _errorMessage;
  bool _torchEnabled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Recipe QR'),
        actions: [
          // Torch toggle
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() => _torchEnabled = !_torchEnabled);
              _controller.toggleTorch();
            },
          ),
          // Camera flip
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Overlay with scanning frame
          _buildScanOverlay(theme),

          // Error message
          if (_errorMessage != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: theme.colorScheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),
            ),

          // Processing indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Importing recipe...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Point your camera at a Memoix recipe QR code',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _enterManually,
                icon: const Icon(Icons.edit),
                label: const Text('Enter Link Manually'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanOverlay(ThemeData theme) {
    return CustomPaint(
      painter: _ScanOverlayPainter(
        borderColor: theme.colorScheme.primary,
        overlayColor: Colors.black54,
      ),
      child: const SizedBox.expand(),
    );
  }

  // SECURITY: Maximum allowed QR code data length
  // Standard QR codes max out around 4,000 characters
  static const _maxQrDataLength = 4096;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null) continue;

      // SECURITY: Reject oversized QR data to prevent OOM/freeze attacks
      if (value.length > _maxQrDataLength) {
        setState(() {
          _errorMessage = 'QR code too large/complex (${value.length} characters). '
              'Maximum allowed: $_maxQrDataLength characters.';
        });
        return;
      }

      // Check if this is a Memoix link
      if (value.startsWith('memoix://recipe/')) {
        await _importRecipe(value);
        return;
      }
    }
  }

  Future<void> _importRecipe(String link) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final shareService = ref.read(shareServiceProvider);
      final recipe = shareService.parseShareLink(link);

      if (recipe == null) {
        setState(() {
          _errorMessage = 'Invalid recipe QR code';
          _isProcessing = false;
        });
        return;
      }

      if (mounted) {
        // Navigate to edit screen so user can review before saving
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RecipeEditScreen(importedRecipe: recipe),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to import: $e';
        _isProcessing = false;
      });
    }
  }

  void _enterManually() {
    showDialog(
      context: context,
      builder: (ctx) => _ManualLinkDialog(
        onSubmit: (link) {
          Navigator.pop(ctx);
          _importRecipe(link);
        },
      ),
    );
  }
}

/// Custom painter for the scanning overlay
class _ScanOverlayPainter extends CustomPainter {
  final Color borderColor;
  final Color overlayColor;

  _ScanOverlayPainter({
    required this.borderColor,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scanAreaSize = size.width * 0.7;
    final scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 50),
      width: scanAreaSize,
      height: scanAreaSize,
    );

    // Draw semi-transparent overlay
    final overlayPaint = Paint()..color = overlayColor;
    
    // Top
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, scanArea.top),
      overlayPaint,
    );
    // Bottom
    canvas.drawRect(
      Rect.fromLTRB(0, scanArea.bottom, size.width, size.height),
      overlayPaint,
    );
    // Left
    canvas.drawRect(
      Rect.fromLTRB(0, scanArea.top, scanArea.left, scanArea.bottom),
      overlayPaint,
    );
    // Right
    canvas.drawRect(
      Rect.fromLTRB(scanArea.right, scanArea.top, size.width, scanArea.bottom),
      overlayPaint,
    );

    // Draw corner brackets
    final bracketPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const bracketLength = 30.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(scanArea.left, scanArea.top + bracketLength)
        ..lineTo(scanArea.left, scanArea.top)
        ..lineTo(scanArea.left + bracketLength, scanArea.top),
      bracketPaint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(scanArea.right - bracketLength, scanArea.top)
        ..lineTo(scanArea.right, scanArea.top)
        ..lineTo(scanArea.right, scanArea.top + bracketLength),
      bracketPaint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(scanArea.left, scanArea.bottom - bracketLength)
        ..lineTo(scanArea.left, scanArea.bottom)
        ..lineTo(scanArea.left + bracketLength, scanArea.bottom),
      bracketPaint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(scanArea.right - bracketLength, scanArea.bottom)
        ..lineTo(scanArea.right, scanArea.bottom)
        ..lineTo(scanArea.right, scanArea.bottom - bracketLength),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dialog for manually entering a share link
class _ManualLinkDialog extends StatefulWidget {
  final void Function(String link) onSubmit;

  const _ManualLinkDialog({required this.onSubmit});

  @override
  State<_ManualLinkDialog> createState() => _ManualLinkDialogState();
}

class _ManualLinkDialogState extends State<_ManualLinkDialog> {
  final _controller = TextEditingController();
  bool _isValid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // SECURITY: Maximum allowed link length (same as QR limit)
  static const _maxLinkLength = 4096;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Recipe Link'),
      content: TextField(
        controller: _controller,
        maxLength: _maxLinkLength,
        decoration: const InputDecoration(
          hintText: 'memoix://recipe/...',
          helperText: 'Paste the recipe share link',
          counterText: '', // Hide character counter for cleaner UI
        ),
        onChanged: (value) {
          setState(() {
            _isValid = value.startsWith('memoix://recipe/') && 
                       value.length > 17 && 
                       value.length <= _maxLinkLength;
          });
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isValid ? () => widget.onSubmit(_controller.text) : null,
          child: const Text('Import'),
        ),
      ],
    );
  }
}
