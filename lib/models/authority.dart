/// Authority model for EasyTax application
/// Represents revenue services, customs authorities, and other government bodies
library;

class Authority {
  final String id;
  final String countryId;
  final String name;
  final String code;
  final String authorityType;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Authority configuration fields
  final int? defaultPassAdvanceDays;
  final String? defaultCurrencyCode;

  // Additional fields from JOINs
  final String? countryName;
  final String? countryCode;

  const Authority({
    required this.id,
    required this.countryId,
    required this.name,
    required this.code,
    required this.authorityType,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.defaultPassAdvanceDays,
    this.defaultCurrencyCode,
    this.countryName,
    this.countryCode,
  });

  /// Create Authority from JSON (database result)
  factory Authority.fromJson(Map<String, dynamic> json) {
    // Extract country data from nested countries object if present
    final countryData = json['countries'] as Map<String, dynamic>?;

    return Authority(
      id: json['id']?.toString() ?? '',
      countryId: json['country_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      authorityType: json['authority_type']?.toString() ?? 'revenue_service',
      description: json['description']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
      defaultPassAdvanceDays:
          (json['default_pass_advance_days'] as num?)?.toInt(),
      defaultCurrencyCode: json['default_currency_code']?.toString(),
      // Try nested countries data first, then fall back to direct fields
      countryName:
          countryData?['name']?.toString() ?? json['country_name']?.toString(),
      countryCode: countryData?['country_code']?.toString() ??
          json['country_code']?.toString(),
    );
  }

  /// Convert Authority to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'country_id': countryId,
      'name': name,
      'code': code,
      'authority_type': authorityType,
      'description': description,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'default_pass_advance_days': defaultPassAdvanceDays,
      'default_currency_code': defaultCurrencyCode,
      'country_name': countryName,
      'country_code': countryCode,
    };
  }

  /// Create a copy with updated fields
  Authority copyWith({
    String? id,
    String? countryId,
    String? name,
    String? code,
    String? authorityType,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? passAdvanceDays,
    String? defaultCurrencyCode,
    String? countryName,
    String? countryCode,
  }) {
    return Authority(
      id: id ?? this.id,
      countryId: countryId ?? this.countryId,
      name: name ?? this.name,
      code: code ?? this.code,
      authorityType: authorityType ?? this.authorityType,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      defaultPassAdvanceDays: passAdvanceDays ?? defaultPassAdvanceDays,
      defaultCurrencyCode: defaultCurrencyCode ?? this.defaultCurrencyCode,
      countryName: countryName ?? this.countryName,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  /// Get display name for authority type
  String get authorityTypeDisplay {
    switch (authorityType) {
      case 'revenue_service':
        return 'Revenue Service';
      case 'customs':
        return 'Customs Authority';
      case 'immigration':
        return 'Immigration Authority';
      case 'global':
        return 'Global Authority';
      default:
        return authorityType
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word[0].toUpperCase() + word.substring(1))
            .join(' ');
    }
  }

  /// Get status display
  String get statusDisplay => isActive ? 'Active' : 'Inactive';

  /// Get full display name with country
  String get fullDisplayName {
    if (countryName != null) {
      return '$name ($countryName)';
    }
    return name;
  }

  @override
  String toString() {
    return 'Authority{id: $id, name: $name, code: $code, type: $authorityType, country: $countryName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Authority && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
