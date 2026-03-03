import 'package:flutter_test/flutter_test.dart';
import 'package:memoix/core/utils/timer_duration_extractor.dart';

void main() {
  group('extractTimerDuration', () {
    // ------------------------------------------------------------------
    // Single unit — minutes
    // ------------------------------------------------------------------
    group('minutes', () {
      test('full word "minutes"', () {
        expect(extractTimerDuration('Simmer for 25 minutes'), Duration(minutes: 25));
      });

      test('abbreviated "min"', () {
        expect(extractTimerDuration('Cook for 10 min'), Duration(minutes: 10));
      });

      test('abbreviated "mins"', () {
        expect(extractTimerDuration('Bake 30 mins'), Duration(minutes: 30));
      });

      test('bare "m" suffix without space', () {
        expect(extractTimerDuration('Fry for 5m'), Duration(minutes: 5));
      });

      test('hyphenated adjective "25-minute"', () {
        expect(extractTimerDuration('A 25-minute rest'), Duration(minutes: 25));
      });

      test('range — lower value used', () {
        expect(extractTimerDuration('Cook 20-25 minutes'), Duration(minutes: 20));
      });

      test('range with en-dash', () {
        expect(extractTimerDuration('Rest 15–20 min'), Duration(minutes: 15));
      });
    });

    // ------------------------------------------------------------------
    // Single unit — hours
    // ------------------------------------------------------------------
    group('hours', () {
      test('full word "hour"', () {
        expect(extractTimerDuration('Roast for 1 hour'), Duration(hours: 1));
      });

      test('full word "hours"', () {
        expect(extractTimerDuration('Braise for 3 hours'), Duration(hours: 3));
      });

      test('abbreviated "hr"', () {
        expect(extractTimerDuration('Cook 2 hr'), Duration(hours: 2));
      });

      test('abbreviated "hrs"', () {
        expect(extractTimerDuration('Rest 2 hrs'), Duration(hours: 2));
      });

      test('bare "h" suffix without space', () {
        expect(extractTimerDuration('Marinate 4h'), Duration(hours: 4));
      });

      test('hyphenated adjective "1-hour"', () {
        expect(extractTimerDuration('A 1-hour brine'), Duration(hours: 1));
      });

      test('range — lower value used', () {
        expect(extractTimerDuration('Slow cook 1-2 hours'), Duration(hours: 1));
      });
    });

    // ------------------------------------------------------------------
    // Single unit — seconds
    // ------------------------------------------------------------------
    group('seconds', () {
      test('full word "seconds"', () {
        expect(extractTimerDuration('Blanch for 30 seconds'), Duration(seconds: 30));
      });

      test('abbreviated "sec"', () {
        expect(extractTimerDuration('Flash fry 45 sec'), Duration(seconds: 45));
      });

      test('abbreviated "secs"', () {
        expect(extractTimerDuration('Hold 10 secs'), Duration(seconds: 10));
      });

      test('bare "s" suffix', () {
        expect(extractTimerDuration('Rest 90s'), Duration(seconds: 90));
      });
    });

    // ------------------------------------------------------------------
    // Combined h + m formats
    // ------------------------------------------------------------------
    group('combined hours + minutes', () {
      test('"1 hr 30 min"', () {
        expect(extractTimerDuration('Braise for 1 hr 30 min'), Duration(hours: 1, minutes: 30));
      });

      test('"1 hour 30 minutes"', () {
        expect(extractTimerDuration('Cook 1 hour 30 minutes'), Duration(hours: 1, minutes: 30));
      });

      test('"1h30m" (no spaces)', () {
        expect(extractTimerDuration('Set timer for 1h30m'), Duration(hours: 1, minutes: 30));
      });

      test('"1h 30m" (space between)', () {
        expect(extractTimerDuration('1h 30m total'), Duration(hours: 1, minutes: 30));
      });

      test('"2 hrs 15 mins"', () {
        expect(extractTimerDuration('Total time 2 hrs 15 mins'), Duration(hours: 2, minutes: 15));
      });
    });

    // ------------------------------------------------------------------
    // Ranges in combined formats
    // ------------------------------------------------------------------
    group('ranges', () {
      test('"20-25 minutes" → 20 min', () {
        expect(extractTimerDuration('Simmer 20-25 minutes'), Duration(minutes: 20));
      });

      test('"1-2 hours" → 1 hr', () {
        expect(extractTimerDuration('Slow cook for 1-2 hours'), Duration(hours: 1));
      });
    });

    // ------------------------------------------------------------------
    // Multiple time mentions — last one wins
    // ------------------------------------------------------------------
    group('multiple time values', () {
      test('last mention is larger', () {
        // "5 min" then "30 min" — last (30 min) wins
        expect(
          extractTimerDuration('Prep takes 5 min, then cook for 30 min'),
          Duration(minutes: 30),
        );
      });

      test('last mention is smaller', () {
        // "1 hour" then "20 min" — last (20 min) wins
        expect(
          extractTimerDuration('Marinate for 1 hour, then rest 20 min'),
          Duration(minutes: 20),
        );
      });

      test('combined followed by standalone — last wins', () {
        // "1h30m" then "45 min" — last (45 min) wins
        expect(
          extractTimerDuration('Cook 1h30m initially, then reduce for 45 min'),
          Duration(minutes: 45),
        );
      });
    });

    // ------------------------------------------------------------------
    // No time found
    // ------------------------------------------------------------------
    group('no time', () {
      test('plain text with no time', () {
        expect(extractTimerDuration('Add salt and stir well'), isNull);
      });

      test('empty string', () {
        expect(extractTimerDuration(''), isNull);
      });

      test('section header [Prep] returns null', () {
        expect(extractTimerDuration('[Prep]'), isNull);
      });

      test('section header [Sauce] returns null', () {
        expect(extractTimerDuration('[Sauce]'), isNull);
      });

      test('section header with spaces returns null', () {
        expect(extractTimerDuration('[Finishing Steps]'), isNull);
      });

      test('zero duration returns null', () {
        expect(extractTimerDuration('Wait 0 minutes'), isNull);
      });
    });

    // ------------------------------------------------------------------
    // Case insensitivity
    // ------------------------------------------------------------------
    group('case variations', () {
      test('uppercase MINUTES', () {
        expect(extractTimerDuration('Cook for 15 MINUTES'), Duration(minutes: 15));
      });

      test('mixed case "MinUtes"', () {
        expect(extractTimerDuration('Simmer 10 MinUtes'), Duration(minutes: 10));
      });

      test('uppercase HR', () {
        expect(extractTimerDuration('Rest 1 HR'), Duration(hours: 1));
      });

      test('uppercase HOURS', () {
        expect(extractTimerDuration('Bake 2 HOURS'), Duration(hours: 2));
      });
    });

    // ------------------------------------------------------------------
    // Edge cases
    // ------------------------------------------------------------------
    group('edge cases', () {
      test('time embedded in longer sentence', () {
        expect(
          extractTimerDuration('Bring to a boil, then reduce heat and simmer for 20 minutes until thickened'),
          Duration(minutes: 20),
        );
      });

      test('step with decimal hours (treated as truncated)', () {
        expect(extractTimerDuration('Cook 1.5h'), Duration(hours: 1));
      });

      test('numeric only (no unit) returns null', () {
        expect(extractTimerDuration('Add 2 eggs'), isNull);
      });
    });
  });
}
