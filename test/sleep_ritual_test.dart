import 'package:bolt_of_aether/studio/date_keys.dart';
import 'package:bolt_of_aether/studio/ritual_content.dart';
import 'package:bolt_of_aether/studio/sleep_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sleepDurationBetween', () {
    test('crosses midnight correctly', () {
      final duration = sleepDurationBetween(
        const TimeOfDay(hour: 22, minute: 30),
        const TimeOfDay(hour: 6, minute: 15),
      );
      expect(duration, const Duration(hours: 7, minutes: 45));
    });

    test('same-day span when wake time is strictly after bed time', () {
      // Naps or unusual entries where both times sit on the same clock day.
      final duration = sleepDurationBetween(
        const TimeOfDay(hour: 8, minute: 0),
        const TimeOfDay(hour: 9, minute: 30),
      );
      expect(duration, const Duration(hours: 1, minutes: 30));
    });

    test('wake time equal to bed time is treated as a full 24h cycle', () {
      final duration = sleepDurationBetween(
        const TimeOfDay(hour: 23, minute: 0),
        const TimeOfDay(hour: 23, minute: 0),
      );
      expect(duration, const Duration(hours: 24));
    });
  });

  group('formatSleepDuration', () {
    test('shows both hours and minutes', () {
      expect(formatSleepDuration(const Duration(hours: 7, minutes: 30)), '7h 30m');
    });

    test('drops minutes when they are zero', () {
      expect(formatSleepDuration(const Duration(hours: 8)), '8h');
    });
  });

  group('computeDailyStreak', () {
    test('counts consecutive days ending today', () {
      final today = DateTime(2026, 3, 10);
      final dayKeys = {
        dayKeyFor(today),
        dayKeyFor(today.subtract(const Duration(days: 1))),
        dayKeyFor(today.subtract(const Duration(days: 2))),
      };
      expect(computeDailyStreak(dayKeys, today), 3);
    });

    test('stops counting at the first gap', () {
      final today = DateTime(2026, 3, 10);
      final dayKeys = {
        dayKeyFor(today),
        // Yesterday is missing — the streak should not reach further back.
        dayKeyFor(today.subtract(const Duration(days: 2))),
        dayKeyFor(today.subtract(const Duration(days: 3))),
      };
      expect(computeDailyStreak(dayKeys, today), 1);
    });

    test('is zero when today itself was skipped', () {
      final today = DateTime(2026, 3, 10);
      final dayKeys = {dayKeyFor(today.subtract(const Duration(days: 1)))};
      expect(computeDailyStreak(dayKeys, today), 0);
    });
  });

  group('RitualContent', () {
    test('word and quote of day are deterministic for the same date', () {
      final date = DateTime(2026, 6, 1);
      expect(RitualContent.wordOfDay(date), RitualContent.wordOfDay(date));
      expect(RitualContent.quoteOfDay(date), RitualContent.quoteOfDay(date));
    });

    test('every generated index stays within the list bounds', () {
      for (var i = 0; i < 400; i++) {
        final date = DateTime(2025, 1, 1).add(Duration(days: i));
        expect(RitualContent.words, contains(RitualContent.wordOfDay(date)));
        expect(RitualContent.quotes, contains(RitualContent.quoteOfDay(date)));
      }
    });

    test('word lists have no duplicate entries', () {
      expect(RitualContent.words.toSet().length, RitualContent.words.length);
      expect(RitualContent.quotes.toSet().length, RitualContent.quotes.length);
    });
  });

  group('stableHash', () {
    test('is deterministic for the same input', () {
      expect(stableHash('2026-06-01'), stableHash('2026-06-01'));
    });

    test('differs across different inputs (no trivial collisions)', () {
      expect(stableHash('2026-06-01'), isNot(stableHash('2026-06-02')));
    });
  });
}
