class PassTemplate {
  final String id;
  final String authorityId;
  final String countryId;
  final String? borderId;
  final String createdByProfileId;
  final String vehicleTypeId;
  final String description;
  final int entryLimit;
  final int expirationDays;
  final double taxAmount;
  final String currencyCode;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional fields from JOIN queries
  final String? borderName;
  final String? vehicleType;
  final String? authorityName;

  const PassTemplate({
    required this.id,
    required this.authorityId,
    required this.countryId,
    this.borderId,
    required this.createdByProfileId,
    required this.vehicleTypeId,
    required this.description,
    required this.entryLimit,
    required this.expirationDays,
    required this.taxAmount,
    required this.currencyCode,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.borderName,
    this.vehicleType,
    this.authorityName,
  });

  factory PassTemplate.fromJson(Map<String, dynamic> json) {
    return PassTemplate(
      id: json['id']?.toString() ?? '',
      authorityId: json['authority_id']?.toString() ?? '',
      countryId: json['country_id']?.toString() ?? '',
      borderId: json['border_id']?.toString(),
      createdByProfileId: json['created_by_profile_id']?.toString() ?? '',
      vehicleTypeId: json['vehicle_type_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      entryLimit: (json['entry_limit'] as num?)?.toInt() ?? 0,
      expirationDays: (json['expiration_days'] as num?)?.toInt() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currency_code']?.toString() ?? '',
      isActive: json['is_active'] == true,
      createdAt: DateTime.parse(
          json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at']?.toString() ?? DateTime.now().toIso8601String()),
      borderName: json['border_name']?.toString(),
      vehicleType: json['vehicle_type']?.toString(),
      authorityName: json['authority_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authority_id': authorityId,
      'country_id': countryId,
      'border_id': borderId,
      'created_by_profile_id': createdByProfileId,
      'vehicle_type_id': vehicleTypeId,
      'description': description,
      'entry_limit': entryLimit,
      'expiration_days': expirationDays,
      'tax_amount': taxAmount,
      'currency_code': currencyCode,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'border_name': borderName,
      'vehicle_type': vehicleType,
      'authority_name': authorityName,
    };
  }

  PassTemplate copyWith({
    String? id,
    String? authorityId,
    String? countryId,
    String? borderId,
    String? createdByProfileId,
    String? vehicleTypeId,
    String? description,
    int? entryLimit,
    int? expirationDays,
    double? taxAmount,
    String? currencyCode,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? borderName,
    String? vehicleType,
    String? authorityName,
  }) {
    return PassTemplate(
      id: id ?? this.id,
      authorityId: authorityId ?? this.authorityId,
      countryId: countryId ?? this.countryId,
      borderId: borderId ?? this.borderId,
      createdByProfileId: createdByProfileId ?? this.createdByProfileId,
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
      description: description ?? this.description,
      entryLimit: entryLimit ?? this.entryLimit,
      expirationDays: expirationDays ?? this.expirationDays,
      taxAmount: taxAmount ?? this.taxAmount,
      currencyCode: currencyCode ?? this.currencyCode,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      borderName: borderName ?? this.borderName,
      vehicleType: vehicleType ?? this.vehicleType,
      authorityName: authorityName ?? this.authorityName,
    );
  }

  @override
  String toString() {
    return 'PassTemplate(id: $id, description: $description, vehicleType: $vehicleType, taxAmount: $taxAmount $currencyCode)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PassTemplate && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
