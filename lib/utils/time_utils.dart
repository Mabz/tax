import 'package:intl/intl.dart';

/// Utility class for time formatting
class TimeUtils {
  /// Format DateTime to a user-friendly string
  /// Examples:
  /// - "Just now" (< 1 minute ago)
  /// - "5 minutes ago"
  /// - "2 hours ago"
  /// - "Yesterday at 3:45 PM"
  /// - "Dec 15 at 10:30 AM"
  /// - "Jan 5, 2023 at 2:15 PM"
  static String formatFriendlyTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // Less than 1 minute ago
    if (difference.inMinutes < 1) {
      return 'Just now';
    }

    // Less than 1 hour ago
    if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    }

    // Less than 24 hours ago (today)
    if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    }

    // Yesterday
    if (difference.inDays == 1) {
      final timeFormat = DateFormat('h:mm a');
      return 'Yesterday at ${timeFormat.format(dateTime)}';
    }

    // Less than 7 days ago (this week)
    if (difference.inDays < 7) {
      final dayFormat = DateFormat('EEEE'); // Day name
      final timeFormat = DateFormat('h:mm a');
      return '${dayFormat.format(dateTime)} at ${timeFormat.format(dateTime)}';
    }

    // This year
    if (dateTime.year == now.year) {
      final dateFormat = DateFormat('MMM d'); // Dec 15
      final timeFormat = DateFormat('h:mm a');
      return '${dateFormat.format(dateTime)} at ${timeFormat.format(dateTime)}';
    }

    // Different year
    final dateFormat = DateFormat('MMM d, yyyy'); // Jan 5, 2023
    final timeFormat = DateFormat('h:mm a');
    return '${dateFormat.format(dateTime)} at ${timeFormat.format(dateTime)}';
  }

  /// Format DateTime to a compact friendly string for small spaces
  /// Examples:
  /// - "Now"
  /// - "5m ago"
  /// - "2h ago"
  /// - "Yesterday"
  /// - "Dec 15"
  /// - "Jan 5, 2023"
  static String formatCompactTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    // Less than 1 minute ago
    if (difference.inMinutes < 1) {
      return 'Now';
    }

    // Less than 1 hour ago
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }

    // Less than 24 hours ago (today)
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }

    // Yesterday
    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    // Less than 7 days ago (this week)
    if (difference.inDays < 7) {
      final dayFormat = DateFormat('EEE'); // Mon, Tue, etc.
      return dayFormat.format(dateTime);
    }

    // This year
    if (dateTime.year == now.year) {
      final dateFormat = DateFormat('MMM d'); // Dec 15
      return dateFormat.format(dateTime);
    }

    // Different year
    final dateFormat = DateFormat('MMM d, yyyy'); // Jan 5, 2023
    return dateFormat.format(dateTime);
  }

  /// Format DateTime to show both date and time clearly
  /// Example: "Dec 15, 2023 at 3:45 PM"
  static String formatFullDateTime(DateTime dateTime) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    return '${dateFormat.format(dateTime)} at ${timeFormat.format(dateTime)}';
  }
}
