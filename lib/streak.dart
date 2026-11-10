String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
