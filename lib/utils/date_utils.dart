import 'package:flutter/material.dart';

class DateUtils {
  /// Format date in a friendly, human-readable way
  static String formatFriendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    // Check if it's today, tomorrow, or yesterday
    if (targetDate.isAtSameMomentAs(today)) {
      return 'Today, ${_formatTime(date)}';
    } else if (targetDate.isAtSameMomentAs(tomorrow)) {
      return 'Tomorrow, ${_formatTime(date)}';
    } else if (targetDate.isAtSameMomentAs(yesterday)) {
      return 'Yesterday, ${_formatTime(date)}';
    }

    // Check if it's within this week
    final daysFromNow = targetDate.difference(today).inDays;
    if (daysFromNow > 0 && daysFromNow <= 7) {
      final weekday = _getWeekdayName(date.weekday);
      return '$weekday, ${_formatTime(date)}';
    } else if (daysFromNow < 0 && daysFromNow >= -7) {
      final weekday = _getWeekdayName(date.weekday);
      return 'Last $weekday, ${_formatTime(date)}';
    }

    // Check if it's within this month
    if (date.year == now.year && date.month == now.month) {
      final day = date.day;
      final suffix = _getDaySuffix(day);
      return '${day}$suffix ${_getMonthName(date.month)}, ${_formatTime(date)}';
    }

    // Check if it's within this year
    if (date.year == now.year) {
      final day = date.day;
      final suffix = _getDaySuffix(day);
      return '${day}$suffix ${_getMonthName(date.month)}, ${_formatTime(date)}';
    }

    // Default format for dates in other years
    final day = date.day;
    final suffix = _getDaySuffix(day);
    return '${day}$suffix ${_getMonthName(date.month)} ${date.year}, ${_formatTime(date)}';
  }

  /// Format date without time - just the day
  static String formatFriendlyDateOnly(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    // Check if it's today, tomorrow, or yesterday
    if (targetDate.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (targetDate.isAtSameMomentAs(tomorrow)) {
      return 'Tomorrow';
    } else if (targetDate.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    }

    // Check if it's within this week
    final daysFromNow = targetDate.difference(today).inDays;
    if (daysFromNow > 0 && daysFromNow <= 7) {
      final weekday = _getWeekdayName(date.weekday);
      return weekday;
    } else if (daysFromNow < 0 && daysFromNow >= -7) {
      final weekday = _getWeekdayName(date.weekday);
      return 'Last $weekday';
    }

    // Check if it's within this month
    if (date.year == now.year && date.month == now.month) {
      final day = date.day;
      final suffix = _getDaySuffix(day);
      return '$day$suffix ${_getMonthName(date.month)}';
    }

    // Check if it's within this year
    if (date.year == now.year) {
      final day = date.day;
      final suffix = _getDaySuffix(day);
      return '$day$suffix ${_getMonthName(date.month)}';
    }

    // Default format for dates in other years
    final day = date.day;
    final suffix = _getDaySuffix(day);
    return '$day$suffix ${_getMonthName(date.month)} ${date.year}';
  }

  /// Format date for display in lists (shorter format)
  static String formatListDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (targetDate.isAtSameMomentAs(tomorrow)) {
      return 'Tomorrow';
    }

    final daysFromNow = targetDate.difference(today).inDays;
    if (daysFromNow > 0 && daysFromNow <= 7) {
      return _getWeekdayName(date.weekday);
    }

    if (date.year == now.year) {
      return '${date.day} ${_getMonthName(date.month).substring(0, 3)}';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  /// Format time in 12-hour format
  static String _formatTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  /// Get weekday name
  static String _getWeekdayName(int weekday) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return weekdays[weekday - 1];
  }

  /// Get month name
  static String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  /// Get day suffix (st, nd, rd, th)
  static String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  /// Get relative time description
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      final absDifference = difference.abs();
      if (absDifference.inDays > 0) {
        return '${absDifference.inDays} day${absDifference.inDays == 1 ? '' : 's'} ago';
      } else if (absDifference.inHours > 0) {
        return '${absDifference.inHours} hour${absDifference.inHours == 1 ? '' : 's'} ago';
      } else if (absDifference.inMinutes > 0) {
        return '${absDifference.inMinutes} minute${absDifference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } else {
      if (difference.inDays > 0) {
        return 'In ${difference.inDays} day${difference.inDays == 1 ? '' : 's'}';
      } else if (difference.inHours > 0) {
        return 'In ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'}';
      } else if (difference.inMinutes > 0) {
        return 'In ${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'}';
      } else {
        return 'Now';
      }
    }
  }

  /// Get color for date based on urgency
  static Color getDateColor(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      return Colors.red.shade600; // Past dates
    } else if (difference.inHours <= 24) {
      return Colors.orange.shade600; // Within 24 hours
    } else if (difference.inDays <= 7) {
      return Colors.blue.shade600; // Within a week
    } else {
      return Colors.green.shade600; // Future dates
    }
  }
}
