import 'package:intl/intl.dart';

/// Helpers for human-friendly time labels.
class TimeFormat {
  TimeFormat._();

  /// e.g. "14:32"
  static String clock(DateTime t) => DateFormat.Hm().format(t);

  /// Relative label used in lists: "ahora", "5 min", "3 h", "Ayer", "12/03".
  static String relative(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24 && now.day == t.day) return clock(t);
    if (diff.inHours < 48) return 'Ayer';
    return DateFormat('dd/MM').format(t);
  }

  /// Date divider label for conversations.
  static String dayLabel(DateTime t) {
    final now = DateTime.now();
    if (now.day == t.day && now.month == t.month && now.year == t.year) {
      return 'HOY';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (yesterday.day == t.day && yesterday.month == t.month) return 'AYER';
    return DateFormat('d MMMM', 'es').format(t).toUpperCase();
  }
}
