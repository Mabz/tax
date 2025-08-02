import '../constants/app_constants.dart';

/// Country model representing a country in the EasyTax system
class Country {
  final String id;
  final String name;
  final String countryCode;
  final String revenueServiceName;
  final bool isActive;
  final bool isGlobal;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Country({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.revenueServiceName,
    required this.isActive,
    required this.isGlobal,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create Country from JSON (from Supabase)
  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json[AppConstants.fieldId] as String,
      name: json[AppConstants.fieldCountryName] as String,
      countryCode: json[AppConstants.fieldCountryCode] as String,
      revenueServiceName:
          json[AppConstants.fieldCountryRevenueServiceName] as String,
      isActive: json[AppConstants.fieldCountryIsActive] as bool? ?? false,
      isGlobal: json[AppConstants.fieldCountryIsGlobal] as bool? ?? false,
      createdAt: DateTime.parse(json[AppConstants.fieldCreatedAt] as String),
      updatedAt: DateTime.parse(json[AppConstants.fieldUpdatedAt] as String),
    );
  }

  /// Convert Country to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      AppConstants.fieldId: id,
      AppConstants.fieldCountryName: name,
      AppConstants.fieldCountryCode: countryCode,
      AppConstants.fieldCountryRevenueServiceName: revenueServiceName,
      AppConstants.fieldCountryIsActive: isActive,
      AppConstants.fieldCountryIsGlobal: isGlobal,
      AppConstants.fieldCreatedAt: createdAt.toIso8601String(),
      AppConstants.fieldUpdatedAt: updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Country copyWith({
    String? id,
    String? name,
    String? countryCode,
    String? revenueServiceName,
    bool? isActive,
    bool? isGlobal,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Country(
      id: id ?? this.id,
      name: name ?? this.name,
      countryCode: countryCode ?? this.countryCode,
      revenueServiceName: revenueServiceName ?? this.revenueServiceName,
      isActive: isActive ?? this.isActive,
      isGlobal: isGlobal ?? this.isGlobal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Country(id: $id, name: $name, countryCode: $countryCode, revenueServiceName: $revenueServiceName, isActive: $isActive, isGlobal: $isGlobal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Country && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
