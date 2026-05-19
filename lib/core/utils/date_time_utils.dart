extension DateTimeExtension on DateTime {
  /// Returns a new DateTime with the time component stripped (midnight, local time).
  /// Use this whenever a DateTime is passed as a FutureProvider.family key so that
  /// time-of-day differences never produce key mismatches.
  DateTime toMidnight() => DateTime(year, month, day);
}
