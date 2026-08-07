import 'package:flutter/material.dart';

import 'date_keys.dart';

/// Purely-manual sleep math: the app never reads real sleep data from the
/// device, it only does arithmetic on the two times the user typed in.
///
/// If [wakeTime] is at or before [bedTime] the night is assumed to cross
/// midnight, so a whole day is added before subtracting — that is what lets
/// "22:30 -> 06:15" come out as roughly 7h 45m instead of a negative span.
Duration sleepDurationBetween(TimeOfDay bedTime, TimeOfDay wakeTime) {
  final bedMinutes = bedTime.hour * 60 + bedTime.minute;
  var wakeMinutes = wakeTime.hour * 60 + wakeTime.minute;
  if (wakeMinutes <= bedMinutes) wakeMinutes += 24 * 60;
  return Duration(minutes: wakeMinutes - bedMinutes);
}

/// "7h 30m", or just "8h" when the minutes happen to land on the hour.
String formatSleepDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
}

/// Counts back from [today] while every day is present in
/// [completedDayKeys], i.e. "consecutive days with a completed Morning
/// Charge, ending today". A single missed day breaks the chain: the streak
/// only ever reflects an unbroken run right up to today or yesterday.
int computeDailyStreak(Set<String> completedDayKeys, DateTime today) {
  var streak = 0;
  var cursor = today;
  while (completedDayKeys.contains(dayKeyFor(cursor))) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
