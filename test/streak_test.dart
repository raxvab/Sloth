import 'package:flutter_test/flutter_test.dart';
import 'package:sloth/streak.dart';

void main() {
  group('CompletionRecord', () {
    test('round trips streak and completion date together', () {
      final saved = const CompletionRecord(
        streak: 5,
        lastCompletedDate: '2026-11-10',
      ).toJson();
      final restored = CompletionRecord.fromStored(
        json: saved,
        legacyStreak: 0,
        legacyLastCompletedDate: '',
      );

      expect(restored.streak, 5);
      expect(restored.lastCompletedDate, '2026-11-10');
    });

    test('reads values saved by the first V1 build', () {
      final restored = CompletionRecord.fromStored(
        json: null,
        legacyStreak: 4,
        legacyLastCompletedDate: '2026-11-09',
      );

      expect(restored.streak, 4);
      expect(restored.lastCompletedDate, '2026-11-09');
    });

    test('falls back to legacy values if a stored record is malformed', () {
      final restored = CompletionRecord.fromStored(
        json: '{broken json',
        legacyStreak: 3,
        legacyLastCompletedDate: '2026-11-08',
      );

      expect(restored.streak, 3);
      expect(restored.lastCompletedDate, '2026-11-08');
    });
  });

  group('dailyHabitStatus', () {
    final today = DateTime(2026, 11, 10);

    test('is pending when there is no record for today', () {
      expect(
        dailyHabitStatus(
          lastCompletedDate: '2026-11-09',
          lastSkippedDate: '',
          today: today,
        ),
        DailyHabitStatus.pending,
      );
    });

    test('restores a skip recorded for today', () {
      expect(
        dailyHabitStatus(
          lastCompletedDate: '2026-11-09',
          lastSkippedDate: '2026-11-10',
          today: today,
        ),
        DailyHabitStatus.skipped,
      );
    });

    test('completion takes precedence over an earlier skip on the same day',
        () {
      expect(
        dailyHabitStatus(
          lastCompletedDate: '2026-11-10',
          lastSkippedDate: '2026-11-10',
          today: today,
        ),
        DailyHabitStatus.completed,
      );
    });
  });

  group('streakAfterCompletion', () {
    final today = DateTime(2026, 11, 10);

    test('starts a streak at one when there is no previous completion', () {
      expect(
        streakAfterCompletion(
          currentStreak: 0,
          lastCompletedDate: '',
          today: today,
        ),
        1,
      );
    });

    test('increments after yesterday and resets after a missed day', () {
      expect(
        streakAfterCompletion(
          currentStreak: 3,
          lastCompletedDate: '2026-11-09',
          today: today,
        ),
        4,
      );
      expect(
        streakAfterCompletion(
          currentStreak: 3,
          lastCompletedDate: '2026-11-08',
          today: today,
        ),
        1,
      );
    });

    test('does not increment twice for the same day', () {
      expect(
        streakAfterCompletion(
          currentStreak: 3,
          lastCompletedDate: '2026-11-10',
          today: today,
        ),
        3,
      );
    });
  });
}
