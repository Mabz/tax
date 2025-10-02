class PassTemplate {
  final String id;
  final String authorityId;
  final String countryId;
  final String? entryPointId; // Renamed from borderId
  final String? exitPointId; // New field for exit point
  final String createdByProfileId;
  final String vehicleTypeId;
  final String description;
  final int entryLimit;
  final int expirationDays;
  final int passAdvanceDays;
  final double taxAmount;
  final String currencyCode;
  final bool isActive;
  final bool
      allowUserSelectablePoints; // New field for user-selectable entry/exit
  final DateTime createdAt;
  final DateTime updatedAt;

  // Additional fields from JOIN queries
  final String? entryPointName; // Renamed from borderName
  final String? exitPointName; // New field for exit point name
  final String? vehicleType;
  final String? authorityName;

  const PassTemplate({
    required this.id,
    required this.authorityId,
    required this.countryId,
    this.entryPointId,
    this.exitPointId,
    required this.createdByProfileId,
    required this.vehicleTypeId,
    required this.description,
    required this.entryLimit,
    required this.expirationDays,
    required this.passAdvanceDays,
    required this.taxAmount,
    required this.currencyCode,
    required this.isActive,
    required this.allowUserSelectablePoints,
    required this.createdAt,
    required this.updatedAt,
    this.entryPointName,
    this.exitPointName,
    this.vehicleType,
    this.authorityName,
  });

  factory PassTemplate.fromJson(Map<String, dynamic> json) {
    return PassTemplate(
      id: json['id']?.toString() ?? '',
      authorityId: json['authority_id']?.toString() ?? '',
      countryId: json['country_id']?.toString() ?? '',
      entryPointId: json['entry_point_id']?.toString() ??
          json['border_id']?.toString(), // Support legacy border_id
      exitPointId: json['exit_point_id']?.toString(),
      createdByProfileId: json['created_by_profile_id']?.toString() ?? '',
      vehicleTypeId: json['vehicle_type_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      entryLimit: (json['entry_limit'] as num?)?.toInt() ?? 0,
      expirationDays: (json['expiration_days'] as num?)?.toInt() ?? 0,
      passAdvanceDays: (json['pass_advance_days'] as num?)?.toInt() ?? 0,
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      currencyCode: json['currency_code']?.toString() ?? '',
      isActive: json['is_active'] == true,
      allowUserSelectablePoints: json['allow_user_selectable_points'] == true,
      createdAt: DateTime.parse(
          json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at']?.toString() ?? DateTime.now().toIso8601String()),
      entryPointName: json['entry_point_name']?.toString() ??
          json['border_name']?.toString(), // Support legacy border_name
      exitPointName: json['exit_point_name']?.toString(),
      vehicleType: json['vehicle_type']?.toString(),
      authorityName: json['authority_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authority_id': authorityId,
      'country_id': countryId,
      'entry_point_id': entryPointId,
      'exit_point_id': exitPointId,
      'created_by_profile_id': createdByProfileId,
      'vehicle_type_id': vehicleTypeId,
      'description': description,
      'entry_limit': entryLimit,
      'expiration_days': expirationDays,
      'pass_advance_days': passAdvanceDays,
      'tax_amount': taxAmount,
      'currency_code': currencyCode,
      'is_active': isActive,
      'allow_user_selectable_points': allowUserSelectablePoints,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'entry_point_name': entryPointName,
      'exit_point_name': exitPointName,
      'vehicle_type': vehicleType,
      'authority_name': authorityName,
    };
  }

  PassTemplate copyWith({
    String? id,
    String? authorityId,
    String? countryId,
    String? entryPointId,
    String? exitPointId,
    String? createdByProfileId,
    String? vehicleTypeId,
    String? description,
    int? entryLimit,
    int? expirationDays,
    int? passAdvanceDays,
    double? taxAmount,
    String? currencyCode,
    bool? isActive,
    bool? allowUserSelectablePoints,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? entryPointName,
    String? exitPointName,
    String? vehicleType,
    String? authorityName,
  }) {
    return PassTemplate(
      id: id ?? this.id,
      authorityId: authorityId ?? this.authorityId,
      countryId: countryId ?? this.countryId,
      entryPointId: entryPointId ?? this.entryPointId,
      exitPointId: exitPointId ?? this.exitPointId,
      createdByProfileId: createdByProfileId ?? this.createdByProfileId,
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
      description: description ?? this.description,
      entryLimit: entryLimit ?? this.entryLimit,
      expirationDays: expirationDays ?? this.expirationDays,
      passAdvanceDays: passAdvanceDays ?? this.passAdvanceDays,
      taxAmount: taxAmount ?? this.taxAmount,
      currencyCode: currencyCode ?? this.currencyCode,
      isActive: isActive ?? this.isActive,
      allowUserSelectablePoints:
          allowUserSelectablePoints ?? this.allowUserSelectablePoints,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      entryPointName: entryPointName ?? this.entryPointName,
      exitPointName: exitPointName ?? this.exitPointName,
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
