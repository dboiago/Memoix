import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/core/services/schema_migration_service.dart';

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
}
