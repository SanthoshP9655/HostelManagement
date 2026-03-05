// lib/core/utils/date_formatter.dart
import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String format(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);
  static String formatWithTime(DateTime dt) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  static String formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);
  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return format(dt);
  }
}
