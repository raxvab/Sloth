import 'package:flutter_test/flutter_test.dart';
import 'package:sloth/date_labels.dart';

void main() {
  group('greetingFor', () {
    test('uses morning, afternoon, and evening greetings', () {
      expect(greetingFor(DateTime(2026, 11, 10, 8)), 'Good Morning');
      expect(greetingFor(DateTime(2026, 11, 10, 14)), 'Good Afternoon');
      expect(greetingFor(DateTime(2026, 11, 10, 19)), 'Good Evening');
    });
  });

  test('friendlyDate includes the weekday and month', () {
    expect(friendlyDate(DateTime(2026, 11, 10)), 'Tuesday, November 10');
  });
}
