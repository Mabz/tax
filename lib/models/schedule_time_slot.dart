/// Schedule Time Slot Model
/// Represents a time slot within a schedule template
class ScheduleTimeSlot {
  final String id;
  final String templateId;
  final int dayOfWeek; // 1=Monday, 7=Sunday
  final String startTime; // HH:MM format
  final String endTime; // HH:MM format
  final int minOfficials;
  final int maxOfficials;
  final bool isActive;

  const ScheduleTimeSlot({
    required this.id,
    required this.templateId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.minOfficials,
    required this.maxOfficials,
    required this.isActive,
  });

  factory ScheduleTimeSlot.fromJson(Map<String, dynamic> json) {
    return ScheduleTimeSlot(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
      dayOfWeek: json['day_of_week'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      minOfficials: json['min_officials'] as int? ?? 1,
      maxOfficials: json['max_officials'] as int? ?? 3,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'template_id': templateId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'min_officials': minOfficials,
      'max_officials': maxOfficials,
      'is_active': isActive,
    };
  }

  /// Get day name from day of week number
  String get dayName {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[dayOfWeek - 1];
  }

  /// Get short day name
  String get shortDayName {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dayOfWeek - 1];
  }

  /// Get duration in hours
  double get durationHours {
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);

    // Handle overnight shifts
    if (end.isBefore(start)) {
      final nextDay = end.add(const Duration(days: 1));
      return nextDay.difference(start).inMinutes / 60.0;
    }

    return end.difference(start).inMinutes / 60.0;
  }

  /// Parse time string to DateTime (today's date with the time)
  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  /// Check if this time slot overlaps with another
  bool overlapsWith(ScheduleTimeSlot other) {
    if (dayOfWeek != other.dayOfWeek) return false;

    final thisStart = _parseTime(startTime);
    final thisEnd = _parseTime(endTime);
    final otherStart = _parseTime(other.startTime);
    final otherEnd = _parseTime(other.endTime);

    return thisStart.isBefore(otherEnd) && otherStart.isBefore(thisEnd);
  }

  ScheduleTimeSlot copyWith({
    String? id,
    String? templateId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    int? minOfficials,
    int? maxOfficials,
    bool? isActive,
  }) {
    return ScheduleTimeSlot(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      minOfficials: minOfficials ?? this.minOfficials,
      maxOfficials: maxOfficials ?? this.maxOfficials,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduleTimeSlot && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ScheduleTimeSlot(id: $id, day: $dayName, time: $startTime-$endTime, officials: $minOfficials-$maxOfficials)';
  }
}
