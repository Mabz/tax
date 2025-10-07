import 'dart:convert';

class PurchasedPass {
  final String passId;
  final String vehicleDescription;
  final String passDescription;
  final String? entryPointName; // Renamed from borderName
  final String? exitPointName; // New field for exit point
  final int entryLimit;
  final int entriesRemaining;
  final DateTime issuedAt;
  final DateTime activationDate;
  final DateTime expiresAt;
  final String status;
  final String?
      currentStatus; // Vehicle movement status: unused, checked_in, checked_out
  final String currency;
  final double amount;
  final String? qrCode;
  final String? shortCode;
  final String? passHash;
  final String? authorityId;
  final String? authorityName;
  final String? countryName;
  final String? profileId;
  final String? entryPointId; // Renamed from borderId
  final String? exitPointId; // New field for exit point ID
  final String? vehicleRegistrationNumber;
  final String? vehicleVin;
  final String? vehicleMake;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? vehicleColor;
  final String? secureCode;
  final DateTime? secureCodeExpiresAt;

  PurchasedPass({
    required this.passId,
    required this.vehicleDescription,
    required this.passDescription,
    this.entryPointName,
    this.exitPointName,
    required this.entryLimit,
    required this.entriesRemaining,
    required this.issuedAt,
    required this.activationDate,
    required this.expiresAt,
    required this.status,
    this.currentStatus,
    required this.currency,
    required this.amount,
    this.qrCode,
    this.shortCode,
    this.passHash,
    this.authorityId,
    this.authorityName,
    this.countryName,
    this.profileId,
    this.entryPointId,
    this.exitPointId,
    this.vehicleRegistrationNumber,
    this.vehicleVin,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
    this.secureCode,
    this.secureCodeExpiresAt,
  });

  factory PurchasedPass.fromJson(Map<String, dynamic> json) {
    // Extract QR data from JSONB field or create from existing data
    final qrData = json['qr_data'] as Map<String, dynamic>?;

    // Generate simple QR code string - just the pass ID in JSON format
    String? qrCodeString;
    if (qrData != null && qrData['id'] != null) {
      // Simple format: just {"id": "pass-uuid"}
      qrCodeString = jsonEncode({'id': qrData['id']});
    }

    // Enhanced data extraction with multiple fallback sources
    int entryLimit = (json['entry_limit'] as num?)?.toInt() ?? 0;
    double amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
    String currency = json['currency']?.toString() ?? '';

    // If primary fields are missing/zero, try nested template data
    if (entryLimit == 0 && json['pass_templates'] != null) {
      final template = json['pass_templates'] as Map<String, dynamic>;
      entryLimit = (template['entry_limit'] as num?)?.toInt() ?? 0;
    }

    if (amount == 0.0 && json['pass_templates'] != null) {
      final template = json['pass_templates'] as Map<String, dynamic>;
      amount = (template['tax_amount'] as num?)?.toDouble() ?? 0.0;
    }

    if (currency.isEmpty && json['pass_templates'] != null) {
      final template = json['pass_templates'] as Map<String, dynamic>;
      currency = template['currency_code']?.toString() ?? '';
    }

    // Extract entry and exit point names from nested data if not already flattened
    String? entryPointName = json['entry_point_name']?.toString() ??
        json['border_name']?.toString(); // Support legacy border_name
    String? exitPointName = json['exit_point_name']?.toString();

    if (entryPointName == null && json['pass_templates'] != null) {
      final template = json['pass_templates'] as Map<String, dynamic>;
      if (template['borders'] != null) {
        final border = template['borders'] as Map<String, dynamic>;
        entryPointName = border['name']?.toString();
      }
    }

    return PurchasedPass(
      passId: json['pass_id']?.toString() ?? json['id']?.toString() ?? '',
      vehicleDescription: json['vehicle_description']?.toString() ?? '',
      passDescription: json['pass_description']?.toString() ?? '',
      entryPointName: entryPointName,
      exitPointName: exitPointName,
      entryLimit: entryLimit,
      entriesRemaining:
          (json['entries_remaining'] as num?)?.toInt() ?? entryLimit,
      issuedAt: DateTime.parse(
          json['issued_at']?.toString() ?? DateTime.now().toIso8601String()),
      activationDate: DateTime.parse(json['activation_date']?.toString() ??
          DateTime.now().toIso8601String()),
      expiresAt: DateTime.parse(
          json['expires_at']?.toString() ?? DateTime.now().toIso8601String()),
      status: json['status']?.toString() ?? 'active',
      currentStatus: json['current_status']?.toString(),
      currency: currency,
      amount: amount,
      qrCode: qrCodeString,
      shortCode: json['short_code']?.toString(),
      passHash: json['pass_hash']?.toString(),
      authorityId: json['authority_id']?.toString(),
      authorityName: json['authority_name']?.toString(),
      countryName: json['country_name']?.toString(),
      profileId: json['profile_id']?.toString(),
      entryPointId: json['entry_point_id']?.toString() ??
          json['border_id']?.toString(), // Support legacy border_id
      exitPointId: json['exit_point_id']?.toString(),
      vehicleRegistrationNumber:
          json['vehicle_registration_number']?.toString() ??
              json['vehicle_number_plate']?.toString(),
      vehicleVin: json['vehicle_vin']?.toString(),
      vehicleMake: json['vehicle_make']?.toString(),
      vehicleModel: json['vehicle_model']?.toString(),
      vehicleYear: json['vehicle_year'] != null
          ? int.tryParse(json['vehicle_year'].toString())
          : null,
      vehicleColor: json['vehicle_color']?.toString(),
      secureCode: json['secure_code']?.toString(),
      secureCodeExpiresAt: json['secure_code_expires_at'] != null
          ? DateTime.parse(json['secure_code_expires_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pass_id': passId,
      'pass_description': passDescription,
      'entry_point_name': entryPointName,
      'exit_point_name': exitPointName,
      'entry_limit': entryLimit,
      'entries_remaining': entriesRemaining,
      'issued_at': issuedAt.toIso8601String(),
      'activation_date': activationDate.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'status': status,
      'current_status': currentStatus,
      'currency': currency,
      'amount': amount,
      'qr_code': qrCode,
      'short_code': shortCode,
      'pass_hash': passHash,
      'authority_id': authorityId,
      'authority_name': authorityName,
      'country_name': countryName,
      'profile_id': profileId,
      'entry_point_id': entryPointId,
      'exit_point_id': exitPointId,
      'vehicle_description': vehicleDescription,
      'vehicle_registration_number': vehicleRegistrationNumber,
      'vehicle_vin': vehicleVin,
      'vehicle_make': vehicleMake,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'vehicle_color': vehicleColor,
      'secure_code': secureCode,
      'secure_code_expires_at': secureCodeExpiresAt?.toIso8601String(),
    };
  }

  // Helper method to build a display-friendly vehicle description
  String get displayVehicleDescription {
    final List<String> parts = [];

    // Use make/model/year if available, otherwise fall back to description
    if (vehicleMake != null && vehicleModel != null) {
      String makeModel = '$vehicleMake $vehicleModel';
      if (vehicleYear != null) {
        makeModel += ' ($vehicleYear)';
      }
      parts.add(makeModel);
    } else if (vehicleDescription.isNotEmpty) {
      parts.add(vehicleDescription);
    }

    if (vehicleRegistrationNumber != null &&
        vehicleRegistrationNumber!.isNotEmpty) {
      parts.add('Reg: $vehicleRegistrationNumber');
    }

    if (vehicleColor != null && vehicleColor!.isNotEmpty) {
      parts.add('Color: $vehicleColor');
    }

    if (parts.isEmpty) {
      return 'General Pass';
    }

    return parts.join(' - ');
  }

  // Check if this pass has vehicle information
  bool get hasVehicleInfo {
    return (vehicleDescription.isNotEmpty) ||
        (vehicleRegistrationNumber != null &&
            vehicleRegistrationNumber!.isNotEmpty) ||
        (vehicleVin != null && vehicleVin!.isNotEmpty) ||
        (vehicleMake != null && vehicleMake!.isNotEmpty) ||
        (vehicleModel != null && vehicleModel!.isNotEmpty);
  }

  bool get isExpired {
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    return nowDate.isAfter(expiryDate);
  }

  bool get isActivated {
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final activationDateOnly =
        DateTime(activationDate.year, activationDate.month, activationDate.day);
    return nowDate.isAfter(activationDateOnly) ||
        nowDate.isAtSameMomentAs(activationDateOnly);
  }

  bool get hasEntriesRemaining => entriesRemaining > 0;

  bool get isActive =>
      status == 'active' &&
      !isExpired &&
      isActivated &&
      (hasEntriesRemaining || currentStatus == 'checked_in');

  String get statusDisplay {
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    final activationDateOnly =
        DateTime(activationDate.year, activationDate.month, activationDate.day);

    // Check if expired by date first
    if (nowDate.isAfter(expiryDate)) {
      return 'Expired';
    }

    // Check if not yet activated
    if (nowDate.isBefore(activationDateOnly)) {
      return 'Pending Activation';
    }

    // Check if pass is not active
    if (status != 'active') {
      return status.toUpperCase();
    }

    // IMPORTANT FIX: Check vehicle status first, then entries
    // If vehicle is in country, pass is still "Active" even with 0 entries
    if (currentStatus == 'checked_in') {
      return 'Active'; // Vehicle in country, can still check out
    }

    // If vehicle has checked out and no entries remaining, then it's consumed
    if (currentStatus == 'checked_out' && !hasEntriesRemaining) {
      return 'Consumed';
    }

    // If vehicle hasn't entered and no entries remaining, it's consumed
    if ((currentStatus == null || currentStatus == 'unused') &&
        !hasEntriesRemaining) {
      return 'Consumed';
    }

    // Otherwise, it's active
    return 'Active';
  }

  /// Get the color that should be used for displaying this pass status
  /// Returns a Color enum value that can be used with Flutter's Colors class
  String get statusColorName {
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    final activationDateOnly =
        DateTime(activationDate.year, activationDate.month, activationDate.day);

    // Red for expired
    if (nowDate.isAfter(expiryDate)) {
      return 'red';
    }

    // Yellow for pending activation (activates in the future)
    if (nowDate.isBefore(activationDateOnly)) {
      return 'yellow';
    }

    // Check if pass is not active
    if (status != 'active') {
      return 'red';
    }

    // IMPORTANT FIX: Check vehicle status first, then entries
    // If vehicle is in country, pass is still "Active" (green) even with 0 entries
    if (currentStatus == 'checked_in') {
      return 'green'; // Vehicle in country, can still check out
    }

    // Red for consumed (vehicle checked out or never entered, and no entries)
    if ((currentStatus == 'checked_out' ||
            currentStatus == null ||
            currentStatus == 'unused') &&
        !hasEntriesRemaining) {
      return 'red';
    }

    // Green for active passes with entries
    if (hasEntriesRemaining) {
      return 'green';
    }

    return 'grey';
  }

  /// Generate a short backup code from pass ID for manual entry when QR can't be scanned
  static String generateShortCode(String passId) {
    // Create a hash from the pass ID
    var hash = passId.hashCode.abs();

    // Convert to base36 (0-9, A-Z) and ensure 8 characters
    var code = hash.toRadixString(36).toUpperCase();
    code = code.padLeft(8, '0').substring(0, 8);

    // Format as XXXX-XXXX for readability
    return '${code.substring(0, 4)}-${code.substring(4, 8)}';
  }

  /// Get the short code for this pass (generate if not stored)
  String get displayShortCode {
    return shortCode ?? generateShortCode(passId);
  }

  /// Get user-friendly entries display
  String get entriesDisplay {
    // Handle case where data might not be fully loaded yet
    if (entryLimit == 0) {
      return 'Loading...';
    }

    if (entryLimit == 1) {
      return hasEntriesRemaining ? '1 entry remaining' : 'No entries remaining';
    } else {
      return '$entriesRemaining out of $entryLimit entries remaining';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PurchasedPass &&
        other.passId == passId &&
        other.vehicleDescription == vehicleDescription &&
        other.passDescription == passDescription &&
        other.entryPointName == entryPointName &&
        other.exitPointName == exitPointName &&
        other.entryLimit == entryLimit &&
        other.entriesRemaining == entriesRemaining &&
        other.issuedAt == issuedAt &&
        other.activationDate == activationDate &&
        other.expiresAt == expiresAt &&
        other.status == status &&
        other.currentStatus == currentStatus &&
        other.currency == currency &&
        other.amount == amount &&
        other.qrCode == qrCode &&
        other.shortCode == shortCode &&
        other.authorityId == authorityId &&
        other.authorityName == authorityName &&
        other.countryName == countryName &&
        other.profileId == profileId &&
        other.entryPointId == entryPointId &&
        other.exitPointId == exitPointId &&
        other.vehicleRegistrationNumber == vehicleRegistrationNumber &&
        other.vehicleVin == vehicleVin &&
        other.vehicleMake == vehicleMake &&
        other.vehicleModel == vehicleModel &&
        other.vehicleYear == vehicleYear &&
        other.vehicleColor == vehicleColor;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      passId,
      vehicleDescription,
      passDescription,
      entryPointName,
      exitPointName,
      entryLimit,
      entriesRemaining,
      issuedAt,
      activationDate,
      expiresAt,
      status,
      currentStatus,
      currency,
      amount,
      qrCode,
      shortCode,
      authorityId,
      authorityName,
      countryName,
      profileId,
      entryPointId,
      exitPointId,
      vehicleRegistrationNumber,
      vehicleVin,
      vehicleMake,
      vehicleModel,
      vehicleYear,
      vehicleColor,
    ]);
  }

  /// Check if this pass has a valid (non-expired) secure code
  bool get hasValidSecureCode {
    if (secureCode == null || secureCode!.isEmpty) return false;
    if (secureCodeExpiresAt == null) return false;
    return DateTime.now().isBefore(secureCodeExpiresAt!);
  }

  /// Check if this pass has an expired secure code
  bool get hasExpiredSecureCode {
    if (secureCode == null || secureCode!.isEmpty) return false;
    if (secureCodeExpiresAt == null) return false;
    return DateTime.now().isAfter(secureCodeExpiresAt!);
  }

  /// Get the secure code status for display
  String get secureCodeStatus {
    if (secureCode == null || secureCode!.isEmpty) return 'none';
    if (hasValidSecureCode) return 'valid';
    if (hasExpiredSecureCode) return 'expired';
    return 'none';
  }

  /// Get time remaining for secure code in minutes
  int get secureCodeMinutesRemaining {
    if (secureCodeExpiresAt == null) return 0;
    final remaining = secureCodeExpiresAt!.difference(DateTime.now());
    return remaining.inMinutes.clamp(0, 999);
  }

  /// Get the vehicle movement status display
  String get vehicleStatusDisplay {
    switch (currentStatus?.toLowerCase()) {
      case 'unused':
        return 'Not Yet Arrived';
      case 'checked_in':
        return 'In Country';
      case 'checked_out':
        return 'Departed';
      default:
        return 'Status Unknown';
    }
  }

  /// Get the vehicle status description
  String get vehicleStatusDescription {
    switch (currentStatus?.toLowerCase()) {
      case 'unused':
        return 'Vehicle has not yet crossed the border';
      case 'checked_in':
        return 'Vehicle has entered the country';
      case 'checked_out':
        return 'Vehicle has exited the country';
      default:
        return 'Vehicle movement status is not available';
    }
  }

  /// Get the color for vehicle status display
  String get vehicleStatusColorName {
    switch (currentStatus?.toLowerCase()) {
      case 'unused':
        return 'grey'; // Neutral - hasn't started journey
      case 'checked_in':
        return 'green'; // Positive - vehicle is in country
      case 'checked_out':
        return 'blue'; // Neutral/Complete - journey completed
      default:
        return 'grey'; // Unknown status
    }
  }

  /// Get the icon for vehicle status
  String get vehicleStatusIcon {
    switch (currentStatus?.toLowerCase()) {
      case 'unused':
        return 'pending'; // Icons.schedule or Icons.pending
      case 'checked_in':
        return 'in_country'; // Icons.location_on or Icons.check_circle
      case 'checked_out':
        return 'departed'; // Icons.flight_takeoff or Icons.exit_to_app
      default:
        return 'unknown'; // Icons.help_outline
    }
  }

  @override
  String toString() {
    return 'PurchasedPass(passId: $passId, passDescription: $passDescription, status: $status)';
  }
}
