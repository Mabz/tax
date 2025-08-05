import '../constants/app_constants.dart';

/// Border model representing a border crossing in the EasyTax system
class Border {
  final String id;
  final String authorityId;
  final String name;
  final String borderTypeId;
  final String? borderTypeLabel;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Border({
    required this.id,
    required this.authorityId,
    required this.name,
    required this.borderTypeId,
    this.borderTypeLabel,
    required this.isActive,
    this.latitude,
    this.longitude,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create Border from JSON (from Supabase)
  factory Border.fromJson(Map<String, dynamic> json) {
    // Handle both direct table queries and function results
    if (json.containsKey('border_id')) {
      // From database function results
      return Border(
        id: json['border_id'] as String,
        authorityId: json['authority_id'] as String? ?? '',
        name: json['border_name'] as String,
        borderTypeId: json['border_type_id'] as String? ?? '',
        isActive: json['is_active'] as bool? ?? true,
        latitude: json['latitude'] as double?,
        longitude: json['longitude'] as double?,
        description: json['description'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.now(),
      );
    } else {
      // From direct table queries
      String? borderTypeLabel;
      if (json['border_types'] != null && json['border_types'] is Map) {
        borderTypeLabel = json['border_types']['label'] as String?;
      }

      return Border(
        id: json[AppConstants.fieldId] as String,
        authorityId: json[AppConstants.fieldBorderAuthorityId] as String,
        name: json[AppConstants.fieldBorderName] as String,
        borderTypeId: json[AppConstants.fieldBorderTypeId] as String,
        borderTypeLabel: borderTypeLabel,
        isActive: json[AppConstants.fieldBorderIsActive] as bool? ?? true,
        latitude: json[AppConstants.fieldBorderLatitude] as double?,
        longitude: json[AppConstants.fieldBorderLongitude] as double?,
        description: json[AppConstants.fieldBorderDescription] as String?,
        createdAt: DateTime.parse(json[AppConstants.fieldCreatedAt] as String),
        updatedAt: DateTime.parse(json[AppConstants.fieldUpdatedAt] as String),
      );
    }
  }

  /// Convert Border to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      AppConstants.fieldId: id,
      AppConstants.fieldBorderAuthorityId: authorityId,
      AppConstants.fieldBorderName: name,
      AppConstants.fieldBorderTypeId: borderTypeId,
      AppConstants.fieldBorderIsActive: isActive,
      AppConstants.fieldBorderLatitude: latitude,
      AppConstants.fieldBorderLongitude: longitude,
      AppConstants.fieldBorderDescription: description,
      AppConstants.fieldCreatedAt: createdAt.toIso8601String(),
      AppConstants.fieldUpdatedAt: updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Border copyWith({
    String? id,
    String? authorityId,
    String? name,
    String? borderTypeId,
    String? borderTypeLabel,
    bool? isActive,
    double? latitude,
    double? longitude,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Border(
      id: id ?? this.id,
      authorityId: authorityId ?? this.authorityId,
      name: name ?? this.name,
      borderTypeId: borderTypeId ?? this.borderTypeId,
      borderTypeLabel: borderTypeLabel ?? this.borderTypeLabel,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Border(id: $id, authorityId: $authorityId, name: $name, borderTypeId: $borderTypeId, isActive: $isActive, latitude: $latitude, longitude: $longitude, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Border && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
