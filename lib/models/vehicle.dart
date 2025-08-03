class Vehicle {
  final String id;
  final String profileId;
  final String numberPlate;
  final String description;
  final String? vinNumber;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Vehicle({
    required this.id,
    required this.profileId,
    required this.numberPlate,
    required this.description,
    this.vinNumber,
    required this.createdAt,
    this.updatedAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['vehicle_id']?.toString() ?? json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      numberPlate: json['number_plate']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      vinNumber: json['vin_number']?.toString(),
      createdAt: DateTime.parse(json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at']?.toString() != null ? DateTime.parse(json['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'number_plate': numberPlate,
      'description': description,
      'vin_number': vinNumber,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Vehicle copyWith({
    String? id,
    String? profileId,
    String? numberPlate,
    String? description,
    String? vinNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      numberPlate: numberPlate ?? this.numberPlate,
      description: description ?? this.description,
      vinNumber: vinNumber ?? this.vinNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vehicle &&
        other.id == id &&
        other.profileId == profileId &&
        other.numberPlate == numberPlate &&
        other.description == description &&
        other.vinNumber == vinNumber &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      profileId,
      numberPlate,
      description,
      vinNumber,
      createdAt,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, numberPlate: $numberPlate, description: $description, vinNumber: $vinNumber)';
  }
}
