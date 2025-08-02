import '../constants/app_constants.dart';

/// Border model representing a border crossing in the EasyTax system
class Border {
  final String id;
  final String countryId;
  final String name;
  final String borderTypeId;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Border({
    required this.id,
    required this.countryId,
    required this.name,
    required this.borderTypeId,
    required this.isActive,
    this.latitude,
    this.longitude,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create Border from JSON (from Supabase)
  factory Border.fromJson(Map<String, dynamic> json) {
    return Border(
      id: json[AppConstants.fieldId] as String,
      countryId: json[AppConstants.fieldBorderCountryId] as String,
      name: json[AppConstants.fieldBorderName] as String,
      borderTypeId: json[AppConstants.fieldBorderTypeId] as String,
      isActive: json[AppConstants.fieldBorderIsActive] as bool? ?? true,
      latitude: json[AppConstants.fieldBorderLatitude] as double?,
      longitude: json[AppConstants.fieldBorderLongitude] as double?,
      description: json[AppConstants.fieldBorderDescription] as String?,
      createdAt: DateTime.parse(json[AppConstants.fieldCreatedAt] as String),
      updatedAt: DateTime.parse(json[AppConstants.fieldUpdatedAt] as String),
    );
  }

  /// Convert Border to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      AppConstants.fieldId: id,
      AppConstants.fieldBorderCountryId: countryId,
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
    String? countryId,
    String? name,
    String? borderTypeId,
    bool? isActive,
    double? latitude,
    double? longitude,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Border(
      id: id ?? this.id,
      countryId: countryId ?? this.countryId,
      name: name ?? this.name,
      borderTypeId: borderTypeId ?? this.borderTypeId,
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
    return 'Border(id: $id, countryId: $countryId, name: $name, borderTypeId: $borderTypeId, isActive: $isActive, latitude: $latitude, longitude: $longitude, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Border && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
