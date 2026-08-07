/// Canonical yyyy-MM-dd key used everywhere a "calendar day" needs to be
/// compared — independent of time-of-day, so the same key can be reused for
/// the daily bolt, the sleep streak and the evening/morning ritual entries.
String dayKeyFor(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Small, fully deterministic string hash (independent of Dart's built-in
/// [String.hashCode], which is not guaranteed to be stable across platforms
/// or SDK versions). Used to pick "content of the day" so every device shows
/// the same word/quote on the same date, forever.
int stableHash(String input) {
  var hash = 0;
  for (final unit in input.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}
