/// Official Schedule Assignment Model
/// Represents an assignment of a border official to a specific time slot
class OfficialScheduleAssignment {
  final String id;
  final String timeSlotId;
  final String profileId;
  final DateTime effectiveFrom;
  final DateTime? effectiveTo;
  final String assignmentType; // 'primary', 'backup', 'temporary'
  final String createdBy;
  final DateTime createdAt;

  const OfficialScheduleAssignment({
    required this.id,
    required this.timeSlotId,
    required this.profileId,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.assignmentType,
    required this.createdBy,
    required this.createdAt,
  });

  factory OfficialScheduleAssignment.fromJson(Map<String, dynamic> json) {
    return OfficialScheduleAssignment(
      id: json['id'] as String,
      timeSlotId: json['time_slot_id'] as String,
      profileId: json['profile_id'] as String,
      effectiveFrom: DateTime.parse(json['effective_from'] as String),
      effectiveTo: json['effective_to'] != null
          ? DateTime.parse(json['effective_to'] as String)
          : null,
      assignmentType: json['assignment_type'] as String? ?? 'primary',
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'time_slot_id': timeSlotId,
      'profile_id': profileId,
      'effective_from': effectiveFrom.toIso8601String(),
      'effective_to': effectiveTo?.toIso8601String(),
      'assignment_type': assignmentType,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Check if this assignment is currently active
  bool get isCurrentlyActive {
    final now = DateTime.now();
    return now.isAfter(effectiveFrom) &&
        (effectiveTo == null || now.isBefore(effectiveTo!));
  }

  /// Check if this assignment is active on a specific date
  bool isActiveOnDate(DateTime date) {
    return date.isAfter(effectiveFrom) &&
        (effectiveTo == null || date.isBefore(effectiveTo!));
  }

  /// Get assignment type display name
  String get assignmentTypeDisplayName {
    switch (assignmentType) {
      case 'primary':
        return 'Primary';
      case 'backup':
        return 'Backup';
      case 'temporary':
        return 'Temporary';
      default:
        return assignmentType;
    }
  }

  /// Get assignment type color
  String get assignmentTypeColor {
    switch (assignmentType) {
      case 'primary':
        return '#4CAF50'; // Green
      case 'backup':
        return '#FF9800'; // Orange
      case 'temporary':
        return '#2196F3'; // Blue
      default:
        return '#757575'; // Grey
    }
  }

  OfficialScheduleAssignment copyWith({
    String? id,
    String? timeSlotId,
    String? profileId,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    String? assignmentType,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return OfficialScheduleAssignment(
      id: id ?? this.id,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      profileId: profileId ?? this.profileId,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      assignmentType: assignmentType ?? this.assignmentType,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfficialScheduleAssignment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'OfficialScheduleAssignment(id: $id, profileId: $profileId, type: $assignmentType, active: $isCurrentlyActive)';
  }
}
