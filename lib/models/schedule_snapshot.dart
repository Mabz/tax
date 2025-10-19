/// Schedule Snapshot Model
/// Represents a historical snapshot of a schedule configuration
class ScheduleSnapshot {
  final String id;
  final String templateId;
  final DateTime snapshotDate;
  final Map<String, dynamic> snapshotData;
  final String reason;
  final String createdBy;
  final DateTime createdAt;

  const ScheduleSnapshot({
    required this.id,
    required this.templateId,
    required this.snapshotDate,
    required this.snapshotData,
    required this.reason,
    required this.createdBy,
    required this.createdAt,
  });

  factory ScheduleSnapshot.fromJson(Map<String, dynamic> json) {
    return ScheduleSnapshot(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
      snapshotDate: DateTime.parse(json['snapshot_date'] as String),
      snapshotData: json['snapshot_data'] as Map<String, dynamic>,
      reason: json['reason'] as String,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'template_id': templateId,
      'snapshot_date': snapshotDate.toIso8601String(),
      'snapshot_data': snapshotData,
      'reason': reason,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get template name from snapshot data
  String? get templateName {
    return snapshotData['template_name'] as String?;
  }

  /// Get border name from snapshot data
  String? get borderName {
    return snapshotData['border_name'] as String?;
  }

  /// Get total officials from snapshot data
  int get totalOfficials {
    return snapshotData['metadata']?['total_officials'] as int? ?? 0;
  }

  /// Get total hours per week from snapshot data
  int get totalHoursPerWeek {
    return snapshotData['metadata']?['total_hours_per_week'] as int? ?? 0;
  }

  /// Get coverage percentage from snapshot data
  double get coveragePercentage {
    return snapshotData['metadata']?['coverage_percentage'] as double? ?? 0.0;
  }

  /// Get time slots from snapshot data
  List<Map<String, dynamic>> get timeSlots {
    return List<Map<String, dynamic>>.from(
        snapshotData['time_slots'] as List? ?? []);
  }

  /// Get reason display name
  String get reasonDisplayName {
    switch (reason) {
      case 'schedule_change':
        return 'Schedule Modified';
      case 'official_reassignment':
        return 'Official Reassigned';
      case 'template_activation':
        return 'Template Activated';
      case 'template_deactivation':
        return 'Template Deactivated';
      case 'monthly_archive':
        return 'Monthly Archive';
      case 'manual_snapshot':
        return 'Manual Snapshot';
      default:
        return reason;
    }
  }

  ScheduleSnapshot copyWith({
    String? id,
    String? templateId,
    DateTime? snapshotDate,
    Map<String, dynamic>? snapshotData,
    String? reason,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return ScheduleSnapshot(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      snapshotDate: snapshotDate ?? this.snapshotDate,
      snapshotData: snapshotData ?? this.snapshotData,
      reason: reason ?? this.reason,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduleSnapshot && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ScheduleSnapshot(id: $id, templateId: $templateId, reason: $reason, date: $snapshotDate)';
  }
}
