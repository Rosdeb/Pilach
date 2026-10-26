import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/utils/date_formatter.dart';

void main() {
  group('DateFormatter', () {
    test('isSameDay correctly identifies same vs different calendar days', () {
      final d1 = DateTime(2026, 10, 26, 10, 30);
      final d2 = DateTime(2026, 10, 26, 23, 59);
      final d3 = DateTime(2026, 10, 25, 23, 59);

      expect(DateFormatter.isSameDay(d1, d2), isTrue);
      expect(DateFormatter.isSameDay(d1, d3), isFalse);
    });

    test('formatChatDate formats Today, Yesterday, same year, and past years', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 14, 0);
      final yesterday = today.subtract(const Duration(days: 1));
      final pastYear = DateTime(now.year - 1, 5, 12, 10, 0);

      expect(DateFormatter.formatChatDate(today), equals('Today'));
      expect(DateFormatter.formatChatDate(yesterday), equals('Yesterday'));
      expect(DateFormatter.formatChatDate(pastYear), contains('${now.year - 1}'));
    });

    test('formatConversationTime formats today with time, yesterday with Yesterday', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10, 30);
      final yesterday = today.subtract(const Duration(days: 1));
      final pastYear = DateTime(now.year - 1, 3, 15, 11, 0);

      expect(DateFormatter.formatConversationTime(today), contains('10:30'));
      expect(DateFormatter.formatConversationTime(yesterday), equals('Yesterday'));
      expect(DateFormatter.formatConversationTime(pastYear), contains('${now.year - 1}'));
    });
  });
}
