import 'package:flutter_test/flutter_test.dart';
import 'package:sloth/streak.dart';

void main() {
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
