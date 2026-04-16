import 'package:flutter/material.dart';

import '../../../core/services/integrity_service.dart';
import '../../../core/services/session_index_service.dart';

class SessionLedgerScreen extends StatelessWidget {
  const SessionLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F0E8),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C1810)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: FutureBuilder<String?>(
          future: IntegrityService.resolveLegacyValue('legacy_ref_reservations'),
          builder: (context, snap) {
            final label = snap.data ?? 'Reference';
            return Text(
              label,
              style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C1810),
              ),
            );
          },
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: SessionIndexService.getEntries(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];
          final hasGuestRef =
              IntegrityService.store.getString('cfg_session_token') != null;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: _LedgerTable(entries: entries, hasGuestRef: hasGuestRef),
            ),
          );
        },
      ),
    );
  }
}

class _LedgerTable extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final bool hasGuestRef;

  const _LedgerTable({required this.entries, required this.hasGuestRef});

  bool _isGuestRow(Map<String, dynamic> entry) =>
      hasGuestRef && entry['table_no'] == 17;

  @override
  Widget build(BuildContext context) {
    final headerStyle = const TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
      color: Color(0xFF8B7355),
    );

    const rowStyle = TextStyle(
      fontFamily: 'Courier Prime',
      fontSize: 13,
      color: Color(0xFF2C1810),
    );

    const guestRowStyle = TextStyle(
      fontFamily: 'Courier Prime',
      fontSize: 13,
      color: Color(0xFF2C1810),
      fontWeight: FontWeight.w700,
    );

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      columnWidths: const {
        0: FixedColumnWidth(60),  // Time
        1: FixedColumnWidth(180), // Name
        2: FixedColumnWidth(48),  // Party
        3: FixedColumnWidth(48),  // Table
        4: FixedColumnWidth(180), // Notes
      },
      border: TableBorder(
        horizontalInside: BorderSide(
          color: const Color(0xFF8B7355).withValues(alpha: 0.18),
          width: 0.5,
        ),
        bottom: BorderSide(
          color: const Color(0xFF8B7355).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      children: [
        // Header
        TableRow(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF8B7355), width: 1.5),
            ),
          ),
          children: [
            _headerCell('TIME', headerStyle),
            _headerCell('NAME', headerStyle),
            _headerCell('PTY', headerStyle),
            _headerCell('TBL', headerStyle),
            _headerCell('NOTES', headerStyle),
          ],
        ),
        // Data rows
        for (final entry in entries)
          TableRow(
            decoration: _isGuestRow(entry)
                ? const BoxDecoration(
                    color: Color(0x148B7355),
                  )
                : null,
            children: [
              _cell(
                entry['time']?.toString() ?? '',
                _isGuestRow(entry) ? guestRowStyle : rowStyle,
              ),
              _cell(
                entry['name']?.toString() ?? '',
                _isGuestRow(entry) ? guestRowStyle : rowStyle,
              ),
              _cell(
                entry['party_size']?.toString() ?? '',
                _isGuestRow(entry) ? guestRowStyle : rowStyle,
              ),
              _cell(
                entry['table_no']?.toString() ?? '',
                _isGuestRow(entry) ? guestRowStyle : rowStyle,
              ),
              _cell(
                entry['notes']?.toString() ?? '',
                _isGuestRow(entry) ? guestRowStyle : rowStyle,
              ),
            ],
          ),
      ],
    );
  }

  Widget _headerCell(String text, TextStyle style) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Text(text, style: style),
      );

  Widget _cell(String text, TextStyle style) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        child: Text(text, style: style),
      );
}
