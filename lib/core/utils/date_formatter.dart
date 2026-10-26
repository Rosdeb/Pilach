import 'package:intl/intl.dart';

class DateFormatter {
  const DateFormatter._();

  /// Checks if two DateTimes fall on the exact same calendar day in local time.
  static bool isSameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  /// Formats date for in-chat history sticky/separator chips.
  /// - Today -> 'Today'
  /// - Yesterday -> 'Yesterday'
  /// - This year -> 'MMMM d' (e.g., 'October 24')
  /// - Other years -> 'MMMM d, yyyy' (e.g., 'October 24, 2025')
  static String formatChatDate(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final today = DateTime(now.year, now.month, now.day);

    final isToday =
        local.year == now.year && local.month == now.month && local.day == now.day;
    if (isToday) {
      return 'Today';
    }

    final yesterday = today.subtract(const Duration(days: 1));
    final isYesterday = local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;
    if (isYesterday) {
      return 'Yesterday';
    }

    if (local.year == now.year) {
      return DateFormat('MMMM d').format(local);
    }

    return DateFormat('MMMM d, yyyy').format(local);
  }

  /// Formats time/date for the conversation list tile (Chat list).
  /// - Today -> 'hh:mm a' (e.g., '10:30 AM')
  /// - Yesterday -> 'Yesterday'
  /// - This year -> 'MMM d' (e.g., 'Oct 24')
  /// - Other years -> 'MMM d, yyyy' (e.g., 'Oct 24, 2025')
  static String formatConversationTime(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final today = DateTime(now.year, now.month, now.day);

    final isToday =
        local.year == now.year && local.month == now.month && local.day == now.day;
    if (isToday) {
      return DateFormat('hh:mm a').format(local);
    }

    final yesterday = today.subtract(const Duration(days: 1));
    final isYesterday = local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;
    if (isYesterday) {
      return 'Yesterday';
    }

    if (local.year == now.year) {
      return DateFormat('MMM d').format(local);
    }

    return DateFormat('MMM d, yyyy').format(local);
  }

  /// Flexible helper for string timestamps (ISO8601, epoch string, etc.).
  static String formatConversationTimeString(dynamic raw) {
    if (raw == null) return '';
    if (raw is DateTime) return formatConversationTime(raw);

    final str = raw.toString().trim();
    if (str.isEmpty) return '';

    // If it's already a formatted non-ISO label, keep it
    if (str == 'Yesterday' || str == 'Sending...' || str == 'Today') {
      return str;
    }

    final parsed = DateTime.tryParse(str);
    if (parsed != null) {
      return formatConversationTime(parsed);
    }

    final numVal = int.tryParse(str);
    if (numVal != null) {
      final dt = numVal > 100000000000
          ? DateTime.fromMillisecondsSinceEpoch(numVal)
          : DateTime.fromMillisecondsSinceEpoch(numVal * 1000);
      return formatConversationTime(dt);
    }

    return str;
  }
}
