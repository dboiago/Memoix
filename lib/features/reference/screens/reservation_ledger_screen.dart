import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/integrity_service.dart';
import '../../../core/services/reservation_service.dart';

class ReservationLedgerScreen extends StatelessWidget {
  const ReservationLedgerScreen({super.key});

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
        title: Text(
          'Reference',
          style: GoogleFonts.playfairDisplay(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2C1810),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ReservationService.getReservations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = snapshot.data ?? [];
          final hasGuestRef =
              IntegrityService.store.getString('schema_guest_ref') != null;

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
    final headerStyle = TextStyle(
      fontFamily: GoogleFonts.inter().fontFamily,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
      color: const Color(0xFF8B7355),
    );

    final rowStyle = GoogleFonts.courierPrime(
      fontSize: 13,
      color: const Color(0xFF2C1810),
    );

    final guestRowStyle = GoogleFonts.courierPrime(
      fontSize: 13,
      color: const Color(0xFF2C1810),
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
