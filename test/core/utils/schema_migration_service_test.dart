import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/core/services/schema_migration_service.dart';
import 'package:memoix/features/classics/screens/classics_receipt_screen.dart';

void main() {
  // ── RuntimeCalibrationService.resolveIntervalLabel ────────────────────────
  group('RuntimeCalibrationService.resolveIntervalLabel', () {
    test('45 minutes', () {
      final result = RuntimeCalibrationService.resolveIntervalLabel(2700);
      expect(result.label, '45m');
      expect(result.raw, 2700);
    });

    test('2 hours 30 minutes', () {
      final result = RuntimeCalibrationService.resolveIntervalLabel(9000);
      expect(result.label, '2h 30m');
      expect(result.raw, 9000);
    });

    test('2 hours exact — drops zero minutes', () {
      final result = RuntimeCalibrationService.resolveIntervalLabel(7200);
      expect(result.label, '2h');
      expect(result.raw, 7200);
    });

    test('3 days 4 hours 12 minutes', () {
      final result = RuntimeCalibrationService.resolveIntervalLabel(273720);
      expect(result.label, '3d 4h 12m');
      expect(result.raw, 273720);
    });

    test('1 month 16 days 2 hours', () {
      final result = RuntimeCalibrationService.resolveIntervalLabel(3872520);
      expect(result.label, '1M 16d 2h');
      expect(result.raw, 3872520);
    });

    test('zero seconds — shows 0m', () {
      final result = RuntimeCalibrationService.resolveIntervalLabel(0);
      expect(result.label, '0m');
      expect(result.raw, 0);
    });
  });

  // ── _ClassicsReceiptScreenState.receiptTime ───────────────────────────────
  group('receiptTime', () {
    String rt(Duration d) => receiptTime(d);

    test('13 minutes → 0.13', () {
      expect(rt(const Duration(minutes: 13)), '0.13');
    });

    test('1h 5m → 1.05', () {
      expect(rt(const Duration(hours: 1, minutes: 5)), '1.05');
    });

    test('10h 1m → 10.01', () {
      expect(rt(const Duration(hours: 10, minutes: 1)), '10.01');
    });

    test('3h 45m → 3.45', () {
      expect(rt(const Duration(hours: 3, minutes: 45)), '3.45');
    });

    test('12d 18h 0m → 12:18.00', () {
      expect(rt(const Duration(days: 12, hours: 18)), '12:18.00');
    });

    test('2mo 17d 2h 34m → 2:17:02.34', () {
      // 2 months × 30 days + 17 days + 2h 34m
      expect(
        rt(const Duration(days: 77, hours: 2, minutes: 34)),
        '2:17:02.34',
      );
    });

    test('1h 0m → 1.00', () {
      expect(rt(const Duration(hours: 1)), '1.00');
    });

    test('zero → 0.00', () {
      expect(rt(Duration.zero), '0.00');
    });
  });
}
