import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/providers.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/services/schema_migration_service.dart';

class ClassicsReceiptScreen extends ConsumerStatefulWidget {
  const ClassicsReceiptScreen({super.key});

  @override
  ConsumerState<ClassicsReceiptScreen> createState() =>
      _ClassicsReceiptScreenState();
}

class _ClassicsReceiptScreenState extends ConsumerState<ClassicsReceiptScreen> {
  static const _stageOrder = [
    'diag_warm_ms',
    'diag_fetch_ms',
    'diag_index_ms',
    'diag_render_ms',
    'diag_asset_ms',
    'diag_stream_ms',
    'diag_paint_ms',
    'diag_flush_ms',
  ];

  bool _isLoading = true;
  Map<String, dynamic>? _receiptData;
  Map<String, Duration>? _stageDurations;
  String? _tipUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final refFinalize =
        await IntegrityService.resolveLegacyValue('legacy_ref_finalize') ?? '';
    await IntegrityService.reportEvent(
      'activity.entry_finalized',
      metadata: {'ref': refFinalize},
    );
    if (!mounted) return;
    await processIntegrityResponses(ref);
    if (mounted) {
      ref.read(classicsFinalizedProvider.notifier).state =
          IntegrityService.store.getBool('cfg_finalize_pass');
    }

    final receiptData = await IntegrityService.resolveReceiptData();
    final stageDurations = await RuntimeCalibrationService.getStageDurations();
    final tipUrl = await IntegrityService.resolveLegacyValue('receipt_tip_ref');

    if (!mounted) return;
    setState(() {
      _receiptData = receiptData;
      _stageDurations = stageDurations;
      _tipUrl = tipUrl;
      _isLoading = false;
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _saveReceipt() async {
    final doc = pw.Document();
    final stageNames = (_receiptData?['stage_names'] as Map?)
            ?.map((k, v) => MapEntry(k as String, v as String)) ??
        {};
    final header = (_receiptData?['header'] as String?) ?? 'LE GRAND MEMOIX';
    final durations = _stageDurations ?? {};
    final tipUrl = _tipUrl ?? '';

    final border = '=' * 33;
    final divider = '-' * 33;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 72, vertical: 72),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(border),
              pw.Center(
                child: pw.Text(
                  header,
                  style: pw.TextStyle(
                    font: pw.Font.courier(),
                    fontBold: pw.Font.courierBold(),
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              pw.Text(border),
              pw.SizedBox(height: 8),
              for (final key in _stageOrder) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      stageNames[key] ?? key,
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 11,
                      ),
                    ),
                    pw.Text(
                      'T ${_formatDuration(durations[key] ?? Duration.zero)}',
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Text(divider),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      font: pw.Font.courier(),
                      fontBold: pw.Font.courierBold(),
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  pw.Text(
                    'T ${_formatDuration(durations['total'] ?? Duration.zero)}',
                    style: pw.TextStyle(
                      font: pw.Font.courier(),
                      fontBold: pw.Font.courierBold(),
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              pw.Text(divider),
              pw.SizedBox(height: 8),
              if (tipUrl.isNotEmpty) pw.Text(tipUrl, style: pw.TextStyle(font: pw.Font.courier(), fontSize: 10)),
              pw.SizedBox(height: 4),
              pw.Text(border),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'receipt.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final receiptFont = GoogleFonts.courierPrime();
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.black,
          ),
        ),
      );
    }

    final stageNames = (_receiptData?['stage_names'] as Map?)
            ?.map((k, v) => MapEntry(k as String, v as String)) ??
        {};
    final header = (_receiptData?['header'] as String?) ?? 'LE GRAND MEMOIX';
    final durations = _stageDurations ?? {};
    final tipUrl = _tipUrl ?? '';

    const border = '═' * 33;
    const divider = '─' * 33;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        onPressed: _saveReceipt,
        child: const Icon(Icons.print),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                border,
                style: receiptFont.copyWith(
                  color: Colors.black,
                  fontSize: 14,
                  letterSpacing: 0,
                ),
              ),
              Text(
                header,
                textAlign: TextAlign.center,
                style: receiptFont.copyWith(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                border,
                style: receiptFont.copyWith(
                  color: Colors.black,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              for (final key in _stageOrder)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          stageNames[key] ?? key,
                          style: receiptFont.copyWith(
                            color: Colors.black,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        'T ${_formatDuration(durations[key] ?? Duration.zero)}',
                        style: receiptFont.copyWith(
                          color: Colors.black,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                divider,
                style: receiptFont.copyWith(color: Colors.black, fontSize: 14),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TOTAL',
                      style: receiptFont.copyWith(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'T ${_formatDuration(durations['total'] ?? Duration.zero)}',
                    style: receiptFont.copyWith(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                divider,
                style: receiptFont.copyWith(color: Colors.black, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Text(
                    tipUrl,
                    style: receiptFont.copyWith(
                      color: Colors.white,
                      fontSize: 2.0,
                    ),
                    maxLines: 1,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            divider,
                            style: receiptFont.copyWith(
                              color: Colors.black,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                border,
                style: receiptFont.copyWith(color: Colors.black, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
