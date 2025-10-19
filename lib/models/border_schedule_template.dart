/// Border Schedule Template Model
/// Represents a reusable schedule template for a specific border
class BorderScheduleTemplate {
  final String id;
  final String borderId;
  final String templateName;
  final String? description;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BorderScheduleTemplate({
    required this.id,
    required this.borderId,
    required this.templateName,
    this.description,
    required this.isActive,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BorderScheduleTemplate.fromJson(Map<String, dynamic> json) {
    return BorderScheduleTemplate(
      id: json['id'] as String,
      borderId: json['border_id'] as String,
      templateName: json['template_name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'border_id': borderId,
      'template_name': templateName,
      'description': description,
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BorderScheduleTemplate copyWith({
    String? id,
    String? borderId,
    String? templateName,
    String? description,
    bool? isActive,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BorderScheduleTemplate(
      id: id ?? this.id,
      borderId: borderId ?? this.borderId,
      templateName: templateName ?? this.templateName,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BorderScheduleTemplate && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BorderScheduleTemplate(id: $id, templateName: $templateName, borderId: $borderId, isActive: $isActive)';
  }
}
