class IdentityDocuments {
  final String? countryOfOriginId;
  final String? countryName;
  final String? countryCode;
  final String? nationalIdNumber;
  final String? passportNumber;
  final DateTime? updatedAt;

  IdentityDocuments({
    this.countryOfOriginId,
    this.countryName,
    this.countryCode,
    this.nationalIdNumber,
    this.passportNumber,
    this.updatedAt,
  });

  factory IdentityDocuments.fromJson(Map<String, dynamic> json) {
    return IdentityDocuments(
      countryOfOriginId: json['country_of_origin_id']?.toString(),
      countryName: json['country_name']?.toString(),
      countryCode: json['country_code']?.toString(),
      nationalIdNumber: json['national_id_number']?.toString(),
      passportNumber: json['passport_number']?.toString(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'country_of_origin_id': countryOfOriginId,
      'country_name': countryName,
      'country_code': countryCode,
      'national_id_number': nationalIdNumber,
      'passport_number': passportNumber,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  IdentityDocuments copyWith({
    String? countryOfOriginId,
    String? countryName,
    String? countryCode,
    String? nationalIdNumber,
    String? passportNumber,
    DateTime? updatedAt,
  }) {
    return IdentityDocuments(
      countryOfOriginId: countryOfOriginId ?? this.countryOfOriginId,
      countryName: countryName ?? this.countryName,
      countryCode: countryCode ?? this.countryCode,
      nationalIdNumber: nationalIdNumber ?? this.nationalIdNumber,
      passportNumber: passportNumber ?? this.passportNumber,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IdentityDocuments &&
        other.countryOfOriginId == countryOfOriginId &&
        other.countryName == countryName &&
        other.countryCode == countryCode &&
        other.nationalIdNumber == nationalIdNumber &&
        other.passportNumber == passportNumber &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      countryOfOriginId,
      countryName,
      countryCode,
      nationalIdNumber,
      passportNumber,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'IdentityDocuments(countryOfOriginId: $countryOfOriginId, countryName: $countryName, countryCode: $countryCode, nationalIdNumber: $nationalIdNumber, passportNumber: $passportNumber, updatedAt: $updatedAt)';
  }
}
