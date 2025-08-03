class VehicleTaxRate {
  final String id;
  final String countryName;
  final String? borderName;
  final String vehicleType;
  final double taxAmount;
  final String currency;
  final DateTime createdAt;
  final DateTime updatedAt;

  VehicleTaxRate({
    required this.id,
    required this.countryName,
    this.borderName,
    required this.vehicleType,
    required this.taxAmount,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VehicleTaxRate.fromJson(Map<String, dynamic> json) {
    return VehicleTaxRate(
      id: json['id'] ?? '',
      countryName: json['country_name'] ?? '',
      borderName: json['border_name'],
      vehicleType: json['vehicle_type'] ?? '',
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'country_name': countryName,
      'border_name': borderName,
      'vehicle_type': vehicleType,
      'tax_amount': taxAmount,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isCountryWide => borderName == null;
  bool get isBorderSpecific => borderName != null;

  String get displayScope => isCountryWide ? 'Country-wide' : borderName!;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VehicleTaxRate && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
