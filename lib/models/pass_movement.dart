class PassMovement {
  final String movementId;
  final String passId;
  final String? borderName;
  final String? officialName;
  final String? officialProfileImageUrl;
  final String movementType; // 'check_in', 'check_out', 'local_authority_scan'
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? notes;
  final String? vehicleRegistrationNumber;
  final String? vehicleVin;
  final String? vehicleMake;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? vehicleColor;
  final String? vehicleDescription;
  final String? ownerName;
  final String? ownerEmail;
  final String? ownerPhone;

  PassMovement({
    required this.movementId,
    required this.passId,
    this.borderName,
    this.officialName,
    this.officialProfileImageUrl,
    required this.movementType,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.notes,
    this.vehicleRegistrationNumber,
    this.vehicleVin,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
    this.vehicleDescription,
    this.ownerName,
    this.ownerEmail,
    this.ownerPhone,
  });

  factory PassMovement.fromJson(Map<String, dynamic> json) {
    return PassMovement(
      movementId:
          json['movement_id']?.toString() ?? json['id']?.toString() ?? '',
      passId: json['pass_id']?.toString() ?? '',
      borderName: json['border_name']?.toString(),
      officialName: json['official_name']?.toString(),
      officialProfileImageUrl: json['official_profile_image_url']?.toString(),
      movementType: json['movement_type']?.toString() ?? 'check_in',
      timestamp: DateTime.parse(
          json['timestamp']?.toString() ?? DateTime.now().toIso8601String()),
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
      notes: json['notes']?.toString(),
      vehicleRegistrationNumber:
          json['vehicle_registration_number']?.toString(),
      vehicleVin: json['vehicle_vin']?.toString(),
      vehicleMake: json['vehicle_make']?.toString(),
      vehicleModel: json['vehicle_model']?.toString(),
      vehicleYear: json['vehicle_year'] != null
          ? int.tryParse(json['vehicle_year'].toString())
          : null,
      vehicleColor: json['vehicle_color']?.toString(),
      vehicleDescription: json['vehicle_description']?.toString(),
      ownerName: json['owner_name']?.toString(),
      ownerEmail: json['owner_email']?.toString(),
      ownerPhone: json['owner_phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'movement_id': movementId,
      'pass_id': passId,
      'border_name': borderName,
      'official_name': officialName,
      'official_profile_image_url': officialProfileImageUrl,
      'movement_type': movementType,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'vehicle_registration_number': vehicleRegistrationNumber,
      'vehicle_vin': vehicleVin,
      'vehicle_make': vehicleMake,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'vehicle_color': vehicleColor,
      'vehicle_description': vehicleDescription,
      'owner_name': ownerName,
      'owner_email': ownerEmail,
      'owner_phone': ownerPhone,
    };
  }

  String get movementTypeDisplay {
    switch (movementType) {
      case 'check_in':
        return 'Vehicle Check-In';
      case 'check_out':
        return 'Vehicle Check-Out';
      case 'local_authority_scan':
        return 'Scan Initiated';
      default:
        return 'Movement';
    }
  }

  String get vehicleInfo {
    final List<String> parts = [];

    if (vehicleMake != null && vehicleModel != null) {
      String makeModel = '$vehicleMake $vehicleModel';
      if (vehicleYear != null) {
        makeModel += ' ($vehicleYear)';
      }
      parts.add(makeModel);
    } else if (vehicleDescription != null && vehicleDescription!.isNotEmpty) {
      parts.add(vehicleDescription!);
    }

    if (vehicleRegistrationNumber != null &&
        vehicleRegistrationNumber!.isNotEmpty) {
      parts.add('Reg: $vehicleRegistrationNumber');
    }

    if (parts.isEmpty) {
      return 'Vehicle Information Not Available';
    }

    return parts.join(' - ');
  }

  @override
  String toString() {
    return 'PassMovement(movementId: $movementId, passId: $passId, movementType: $movementType)';
  }
}

class VehicleMovementSummary {
  final String? vehicleRegistrationNumber;
  final String? vehicleVin;
  final String? vehicleMake;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? vehicleColor;
  final String? vehicleDescription;
  final int totalMovements;
  final DateTime? lastMovement;
  final String? lastMovementType;
  final List<String> passIds;

  VehicleMovementSummary({
    this.vehicleRegistrationNumber,
    this.vehicleVin,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
    this.vehicleDescription,
    required this.totalMovements,
    this.lastMovement,
    this.lastMovementType,
    required this.passIds,
  });

  factory VehicleMovementSummary.fromJson(Map<String, dynamic> json) {
    return VehicleMovementSummary(
      vehicleRegistrationNumber:
          json['vehicle_registration_number']?.toString(),
      vehicleVin: json['vehicle_vin']?.toString(),
      vehicleMake: json['vehicle_make']?.toString(),
      vehicleModel: json['vehicle_model']?.toString(),
      vehicleYear: json['vehicle_year'] != null
          ? int.tryParse(json['vehicle_year'].toString())
          : null,
      vehicleColor: json['vehicle_color']?.toString(),
      vehicleDescription: json['vehicle_description']?.toString(),
      totalMovements: (json['total_movements'] as num?)?.toInt() ?? 0,
      lastMovement: json['last_movement'] != null
          ? DateTime.parse(json['last_movement'].toString())
          : null,
      lastMovementType: json['last_movement_type']?.toString(),
      passIds:
          (json['pass_ids'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  String get vehicleInfo {
    final List<String> parts = [];

    if (vehicleMake != null && vehicleModel != null) {
      String makeModel = '$vehicleMake $vehicleModel';
      if (vehicleYear != null) {
        makeModel += ' ($vehicleYear)';
      }
      parts.add(makeModel);
    } else if (vehicleDescription != null && vehicleDescription!.isNotEmpty) {
      parts.add(vehicleDescription!);
    }

    if (vehicleRegistrationNumber != null &&
        vehicleRegistrationNumber!.isNotEmpty) {
      parts.add('Reg: $vehicleRegistrationNumber');
    }

    if (vehicleVin != null && vehicleVin!.isNotEmpty) {
      parts.add('VIN: $vehicleVin');
    }

    if (parts.isEmpty) {
      return 'Vehicle Information Not Available';
    }

    return parts.join(' - ');
  }

  String get searchableText {
    final List<String> searchTerms = [];

    if (vehicleVin != null) searchTerms.add(vehicleVin!);
    if (vehicleMake != null) searchTerms.add(vehicleMake!);
    if (vehicleModel != null) searchTerms.add(vehicleModel!);
    if (vehicleRegistrationNumber != null)
      searchTerms.add(vehicleRegistrationNumber!);
    if (vehicleDescription != null) searchTerms.add(vehicleDescription!);

    return searchTerms.join(' ').toLowerCase();
  }
}
