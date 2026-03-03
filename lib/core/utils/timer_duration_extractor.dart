/// Extracts a [Duration] from a step description string by scanning for
/// time-related patterns (minutes, hours, seconds, combined, ranges).
///
/// Rules:
/// - If multiple time values are found, the **last** one is used.
/// - If a range is found (e.g. "20-25 minutes"), the **lower/first** value is used.
/// - Returns `null` when no time pattern is detected.
Duration? extractTimerDuration(String stepText) {
  // Strip section headers — [bracket] strings have no time meaning here.
  final trimmed = stepText.trim();
  if (trimmed.startsWith('[') && trimmed.endsWith(']')) return null;

  // -----------------------------------------------------------------------
  // Regex components
  // -----------------------------------------------------------------------

  // A numeric value, optionally followed by a range upper bound:
  //   "25", "1", "20-25", "1-2"
  const _num = r'(\d+(?:\.\d+)?)(?:\s*[-–]\s*\d+(?:\.\d+)?)?';

  // Hour tokens: hour, hours, hr, hrs, h  (with optional hyphen prefix for "1-hour")
  const _hourToken = r'(?:hours?|hrs?|h)';

  // Minute tokens: minute, minutes, min, mins, m
  const _minToken = r'(?:minutes?|mins?|m)';

  // Second tokens: second, seconds, sec, secs, s
  const _secToken = r'(?:seconds?|secs?|s)';

  // Combined pattern: "1h30m", "1h 30m", "1 hr 30 min", "1 hour 30 minutes"
  // Must capture hours part AND minutes part together.
  final combinedRe = RegExp(
    r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\s*(?:and\s+)?(\d+(?:\.\d+)?)\s*(?:minutes?|mins?|m)\b',
    caseSensitive: false,
  );

  // Standalone hours: "1 hour", "2 hrs", "1-hour", "2h"
  // The hyphen-adjective form "1-hour" needs special treatment.
  final hoursRe = RegExp(
    r'(\d+(?:\.\d+)?)(?:\s*[-–]\s*\d+(?:\.\d+)?)?\s*[-–]?\s*(?:hours?|hrs?|h)\b',
    caseSensitive: false,
  );

  // Standalone minutes: "25 minutes", "25 min", "25-minute", "25m"
  final minutesRe = RegExp(
    r'(\d+(?:\.\d+)?)(?:\s*[-–]\s*\d+(?:\.\d+)?)?\s*[-–]?\s*(?:minutes?|mins?|m)\b',
    caseSensitive: false,
  );

  // Standalone seconds: "30 seconds", "30 sec", "30s"
  final secondsRe = RegExp(
    r'(\d+(?:\.\d+)?)(?:\s*[-–]\s*\d+(?:\.\d+)?)?\s*[-–]?\s*(?:seconds?|secs?|s)\b',
    caseSensitive: false,
  );

  // -----------------------------------------------------------------------
  // Collect all matches with their end-position so we can pick the last one.
  // -----------------------------------------------------------------------

  final candidates = <_TimerCandidate>[];

  // Combined h+m matches — scan first so they are not double-counted
  for (final m in combinedRe.allMatches(stepText)) {
    final h = double.tryParse(m.group(1)!) ?? 0;
    final min = double.tryParse(m.group(2)!) ?? 0;
    candidates.add(_TimerCandidate(
      end: m.end,
      duration: Duration(
        hours: h.truncate(),
        minutes: min.truncate(),
      ),
    ));
  }

  // Build a set of character ranges covered by combined matches so standalone
  // patterns don't re-match the same text.
  final combinedRanges = combinedRe.allMatches(stepText).map((m) => (m.start, m.end)).toList();

  bool _inCombined(RegExpMatch m) =>
      combinedRanges.any((r) => m.start >= r.$1 && m.end <= r.$2);

  // Standalone hours
  for (final m in hoursRe.allMatches(stepText)) {
    if (_inCombined(m)) continue;
    final raw = m.group(1)!;
    final h = (double.tryParse(raw) ?? 0).truncate();
    candidates.add(_TimerCandidate(end: m.end, duration: Duration(hours: h)));
  }

  // Standalone minutes
  for (final m in minutesRe.allMatches(stepText)) {
    if (_inCombined(m)) continue;
    final raw = m.group(1)!;
    final min = (double.tryParse(raw) ?? 0).truncate();
    candidates.add(_TimerCandidate(end: m.end, duration: Duration(minutes: min)));
  }

  // Standalone seconds
  for (final m in secondsRe.allMatches(stepText)) {
    if (_inCombined(m)) continue;
    final raw = m.group(1)!;
    final sec = (double.tryParse(raw) ?? 0).truncate();
    candidates.add(_TimerCandidate(end: m.end, duration: Duration(seconds: sec)));
  }

  if (candidates.isEmpty) return null;

  // Return the candidate whose match ends latest in the string.
  candidates.sort((a, b) => a.end.compareTo(b.end));
  final result = candidates.last.duration;

  // Guard: don't return a zero duration.
  if (result == Duration.zero) return null;
  return result;
}

class _TimerCandidate {
  final int end;
  final Duration duration;
  const _TimerCandidate({required this.end, required this.duration});
}
