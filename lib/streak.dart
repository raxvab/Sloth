import 'dart:convert';

String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class CompletionRecord {
  const CompletionRecord({
    required this.streak,
    required this.lastCompletedDate,
  });

  final int streak;
  final String lastCompletedDate;

  String toJson() => jsonEncode({
        'streak': streak,
        'lastCompletedDate': lastCompletedDate,
      });

  factory CompletionRecord.fromStored({
    required String? json,
    required int legacyStreak,
    required String legacyLastCompletedDate,
  }) {
    if (json != null) {
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map &&
            decoded['streak'] is num &&
            decoded['lastCompletedDate'] is String) {
          return CompletionRecord(
            streak: (decoded['streak'] as num).toInt(),
            lastCompletedDate: decoded['lastCompletedDate'] as String,
          );
        }
      } on FormatException {
        // Fall back to the separate keys used by the first V1 build.
      }
    }
    return CompletionRecord(
      streak: legacyStreak,
      lastCompletedDate: legacyLastCompletedDate,
    );
  }
}

enum DailyHabitStatus { pending, completed, skipped }

DailyHabitStatus dailyHabitStatus({
  required String lastCompletedDate,
  required String lastSkippedDate,
  required DateTime today,
}) {
  final todayKey = dateKey(today);
  if (lastCompletedDate == todayKey) return DailyHabitStatus.completed;
  if (lastSkippedDate == todayKey) return DailyHabitStatus.skipped;
  return DailyHabitStatus.pending;
}

int streakAfterCompletion({
  required int currentStreak,
  required String lastCompletedDate,
  required DateTime today,
}) {
  final todayKey = dateKey(today);
  if (lastCompletedDate == todayKey) return currentStreak;

  final yesterdayKey = dateKey(today.subtract(const Duration(days: 1)));
  return lastCompletedDate == yesterdayKey ? currentStreak + 1 : 1;
}
