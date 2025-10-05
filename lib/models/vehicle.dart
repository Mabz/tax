class Vehicle {
  final String id;
  final String profileId;
  final String? numberPlate; // Keep for backward compatibility
  final String description;
  final String? vinNumber;
  final String? make;
  final String? model;
  final int? year;
  final String? color;
  final String? bodyType;
  final String? fuelType;
  final String? transmission;
  final double? engineCapacity;
  final String? registrationNumber;
  final String? countryOfRegistrationId;
  final String? countryOfRegistrationName;
  final String? vehicleType;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Vehicle({
    required this.id,
    required this.profileId,
    this.numberPlate,
    required this.description,
    this.vinNumber,
    this.make,
    this.model,
    this.year,
    this.color,
    this.bodyType,
    this.fuelType,
    this.transmission,
    this.engineCapacity,
    this.registrationNumber,
    this.countryOfRegistrationId,
    this.countryOfRegistrationName,
    this.vehicleType,
    required this.createdAt,
    this.updatedAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['vehicle_id']?.toString() ?? json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      numberPlate: json['number_plate']?.toString(),
      description: json['description']?.toString() ?? '',
      vinNumber: json['vin_number']?.toString(),
      make: json['make']?.toString(),
      model: json['model']?.toString(),
      year: json['year'] != null ? int.tryParse(json['year'].toString()) : null,
      color: json['color']?.toString(),
      bodyType: json['body_type']?.toString(),
      fuelType: json['fuel_type']?.toString(),
      transmission: json['transmission']?.toString(),
      engineCapacity: json['engine_capacity'] != null
          ? double.tryParse(json['engine_capacity'].toString())
          : null,
      registrationNumber: json['registration_number']?.toString(),
      countryOfRegistrationId: json['country_of_registration_id']?.toString(),
      countryOfRegistrationName:
          json['country_of_registration_name']?.toString(),
      vehicleType: json['vehicle_type_label']?.toString(),
      createdAt: DateTime.parse(
          json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at']?.toString() != null
          ? DateTime.parse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'number_plate': numberPlate,
      'description': description,
      'vin_number': vinNumber,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'body_type': bodyType,
      'fuel_type': fuelType,
      'transmission': transmission,
      'engine_capacity': engineCapacity,
      'registration_number': registrationNumber,
      'country_of_registration_id': countryOfRegistrationId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Computed properties for display
  String get displayName {
    List<String> parts = [];
    if (make != null && make!.isNotEmpty) parts.add(make!);
    if (model != null && model!.isNotEmpty) parts.add(model!);
    if (year != null) parts.add(year.toString());

    if (parts.isEmpty) {
      return description.isNotEmpty ? description : 'Vehicle';
    }

    return parts.join(' ');
  }

  String get displayRegistration {
    return registrationNumber ?? numberPlate ?? 'No Registration';
  }

  String get fullDescription {
    List<String> parts = [];

    // Main identification
    parts.add(displayName);

    // Registration
    if (displayRegistration != 'No Registration') {
      parts.add('(${displayRegistration})');
    }

    // Color
    if (color != null && color!.isNotEmpty) {
      parts.add('- $color');
    }

    return parts.join(' ');
  }

  Vehicle copyWith({
    String? id,
    String? profileId,
    String? numberPlate,
    String? description,
    String? vinNumber,
    String? make,
    String? model,
    int? year,
    String? color,
    String? bodyType,
    String? fuelType,
    String? transmission,
    double? engineCapacity,
    String? registrationNumber,
    String? countryOfRegistrationId,
    String? countryOfRegistrationName,
    String? vehicleType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      numberPlate: numberPlate ?? this.numberPlate,
      description: description ?? this.description,
      vinNumber: vinNumber ?? this.vinNumber,
      make: make ?? this.make,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      bodyType: bodyType ?? this.bodyType,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      engineCapacity: engineCapacity ?? this.engineCapacity,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      countryOfRegistrationId:
          countryOfRegistrationId ?? this.countryOfRegistrationId,
      countryOfRegistrationName:
          countryOfRegistrationName ?? this.countryOfRegistrationName,
      vehicleType: vehicleType ?? this.vehicleType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vehicle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Vehicle(id: $id, displayName: $displayName, registration: $displayRegistration)';
  }
}

// Constants for dropdown options
class VehicleConstants {
  static const List<String> colors = [
    'White',
    'Black',
    'Silver',
    'Gray',
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Orange',
    'Brown',
    'Purple',
    'Pink',
    'Gold',
    'Beige',
    'Maroon',
    'Navy',
    'Other',
  ];

  static const List<String> vehicleTypes = [
    'Car',
    'SUV',
    'Truck',
    'Van',
    'Motorcycle',
    'Bus',
    'Trailer',
    'Pickup',
    'Coupe',
    'Sedan',
    'Hatchback',
    'Convertible',
    'Wagon',
    'Other',
  ];

  static const List<String> fuelTypes = [
    'Petrol',
    'Diesel',
    'Electric',
    'Hybrid',
    'LPG',
    'CNG',
    'Hydrogen',
    'Other',
  ];

  static const List<String> transmissionTypes = [
    'Manual',
    'Automatic',
    'CVT',
    'Semi-Automatic',
    'Other',
  ];

  static const List<String> bodyTypes = [
    'Sedan',
    'Hatchback',
    'SUV',
    'Coupe',
    'Convertible',
    'Wagon',
    'Pickup',
    'Van',
    'Truck',
    'Bus',
    'Motorcycle',
    'Other',
  ];
}
