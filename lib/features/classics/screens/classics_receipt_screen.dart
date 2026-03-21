import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/providers.dart';
import '../../../core/services/integrity_service.dart';
import '../../../core/services/schema_migration_service.dart';
import '../../../core/services/session_index_service.dart';

/// Formats a Duration as a decimal-aligned receipt time string.
///
/// Uses 30-day months and 12-month years.
/// Returns segments separated by ':' with minutes after '.'.
String receiptTime(Duration d) {
  var totalMinutes = d.inMinutes;
  if (totalMinutes <= 0) return '0.00';

  final mm = totalMinutes % 60;
  totalMinutes ~/= 60;
  final hh = totalMinutes % 24;
  totalMinutes ~/= 24;
  final dd = totalMinutes % 30;
  totalMinutes ~/= 30;
  final mo = totalMinutes % 12;
  final yy = totalMinutes ~/ 12;

  final buf = StringBuffer();
  var started = false;

  if (yy > 0) {
    buf.write(yy.toString().padLeft(2, '0'));
    started = true;
  }
  if (started || mo > 0) {
    if (started) buf.write(':');
    buf.write(started ? mo.toString().padLeft(2, '0') : mo.toString());
    started = true;
  }
  if (started || dd > 0) {
    if (started) buf.write(':');
    buf.write(started ? dd.toString().padLeft(2, '0') : dd.toString());
    started = true;
  }
  if (started || hh > 0) {
    if (started) buf.write(':');
    buf.write(started ? hh.toString().padLeft(2, '0') : hh.toString());
    started = true;
  }
  if (!started) {
    buf.write('0');
  }
  buf.write('.${mm.toString().padLeft(2, '0')}');
  return buf.toString();
}

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
  String? _exportRef;

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
    final tipRef = receiptData?['tip_ref'] as String? ?? '';

    String? exportRef;
    final diagWarmMs = IntegrityService.store.getInt('diag_warm_ms');
    if (diagWarmMs > 0) {
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - diagWarmMs) ~/ 1000;
      final interval = RuntimeCalibrationService.resolveIntervalLabel(elapsed);
      final guest = await SessionIndexService.getLocalEntry();
      final nodeSeed = guest?['party_size'] as int? ?? 0;
      final indexRef = guest?['table_no'] as int? ?? 0;
      exportRef = RuntimeCalibrationService.resolveExportUri(
        nodeSeed: nodeSeed,
        indexRef: indexRef,
        intervalLabel: interval.label,
        intervalRaw: interval.raw,
      );
    }

    if (!mounted) return;
    setState(() {
      _receiptData = receiptData;
      _stageDurations = stageDurations;
      _tipUrl = tipRef;
      _exportRef = exportRef;
      _isLoading = false;
    });
  }

  String _stageLabel(Duration d) =>
      RuntimeCalibrationService.resolveIntervalLabel(d.inSeconds).label;

  Widget _timeCell(String time, TextStyle style) {
    final dotIndex = time.indexOf('.');
    final left = 'T ${time.substring(0, dotIndex)}';
    final right = time.substring(dotIndex);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.max,
      children: [
        SizedBox(
          width: 120,
          child: Text(left, textAlign: TextAlign.right, style: style),
        ),
        SizedBox(
          width: 46,
          child: Text(right, textAlign: TextAlign.left, style: style),
        ),
      ],
    );
  }

  Future<void> _saveReceipt() async {
    final doc = pw.Document();
    final stageNames = (_receiptData?['stage_names'] as Map?)
            ?.map((k, v) => MapEntry(k as String, v as String)) ??
        {};
    final header = (_receiptData?['header'] as String?) ?? 'LE GRAND MEMOIX';
    final durations = _stageDurations ?? {};
    final tipUrl = _tipUrl ?? '';

    final divider = '─' * 51;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 72, vertical: 72),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(divider),
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
              pw.Text(divider),
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
                      'T ${_stageLabel(durations[key] ?? Duration.zero)}',
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
                    'T ${_stageLabel(durations['total'] ?? Duration.zero)}',
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
              pw.SizedBox(height: 4),
              if (_exportRef != null)
                pw.Row(
                  children: [
                    pw.Text(
                      'TIP  ',
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 11,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        _exportRef!,
                        style: pw.TextStyle(
                          font: pw.Font.courier(),
                          fontSize: 5.0,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              pw.Row(
                children: [
                  pw.Text(
                    'TIP',
                    style: pw.TextStyle(
                      font: pw.Font.courier(),
                      fontBold: pw.Font.courierBold(),
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      '  _______________',
                      style: pw.TextStyle(
                        font: pw.Font.courier(),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Center(
                child: pw.Text(
                  '>> PRINT GUEST COPY <<',
                  style: pw.TextStyle(
                    font: pw.Font.courier(),
                    fontSize: 11,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'THANK YOU FOR DINING WITH US',
                  style: pw.TextStyle(
                    font: pw.Font.courier(),
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(divider),
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

    const receiptDivider = Divider(
      color: Colors.black,
      thickness: 1,
      height: 16,
    );

    final bodyStyle = receiptFont.copyWith(
      color: Colors.black,
      fontSize: 13,
    );
    final boldStyle = receiptFont.copyWith(
      color: Colors.black,
      fontSize: 13,
      fontWeight: FontWeight.bold,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
              child: Center(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      receiptDivider,
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
                      receiptDivider,
                      const SizedBox(height: 8),
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FixedColumnWidth(200),
                        },
                        children: [
                          for (final key in _stageOrder)
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    stageNames[key] ?? key,
                                    textAlign: TextAlign.left,
                                    style: bodyStyle,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: _timeCell(
                                    receiptTime(durations[key] ?? Duration.zero),
                                    bodyStyle,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      receiptDivider,
                      Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FixedColumnWidth(200),
                        },
                        children: [
                          TableRow(
                            children: [
                              Text('TOTAL', textAlign: TextAlign.left, style: boldStyle),
                              _timeCell(
                                receiptTime(durations['total'] ?? Duration.zero),
                                boldStyle,
                              ),
                            ],
                          ),
                        ],
                      ),
                      receiptDivider,
                      const SizedBox(height: 4),
                      if (_exportRef != null)
                        Row(
                          children: [
                            Text('TIP  ', style: bodyStyle),
                            Expanded(
                              child: SelectableText(
                                _exportRef!,
                                style: receiptFont.copyWith(
                                  color: Colors.black87,
                                  fontSize: 5.0,
                                  letterSpacing: 0,
                                  height: 1.0,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      Row(
                        children: [
                          Text('TIP', style: boldStyle),
                          Expanded(
                            child: Text('  _______________', style: bodyStyle),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _saveReceipt,
                        child: Text(
                          '>> PRINT GUEST COPY <<',
                          textAlign: TextAlign.center,
                          style: bodyStyle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'THANK YOU FOR DINING WITH US',
                        textAlign: TextAlign.center,
                        style: receiptFont.copyWith(
                          color: Colors.black,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      receiptDivider,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text(
                  'X',
                  style: receiptFont.copyWith(
                    color: Colors.black,
                    fontSize: 12,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
