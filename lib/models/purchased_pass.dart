class PurchasedPass {
  final String passId;
  final String vehicleDescription;
  final String passDescription;
  final String? borderName;
  final int entryLimit;
  final int entriesRemaining;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String status;
  final String currency;
  final double amount;
  final String? qrCode;
  final String? shortCode;

  PurchasedPass({
    required this.passId,
    required this.vehicleDescription,
    required this.passDescription,
    this.borderName,
    required this.entryLimit,
    required this.entriesRemaining,
    required this.issuedAt,
    required this.expiresAt,
    required this.status,
    required this.currency,
    required this.amount,
    this.qrCode,
    this.shortCode,
  });

  factory PurchasedPass.fromJson(Map<String, dynamic> json) {
    // Extract QR data from JSONB field or create from existing data
    final qrData = json['qr_data'] as Map<String, dynamic>?;
    
    // Generate QR code string from JSONB data or fallback to legacy format
    String? qrCodeString;
    if (qrData != null) {
      qrCodeString = qrData.entries.map((e) => '${e.key}:${e.value}').join('|');
    }
    
    return PurchasedPass(
      passId: json['pass_id']?.toString() ?? json['id']?.toString() ?? '',
      vehicleDescription: json['vehicle_desc']?.toString() ?? '',
      passDescription: json['pass_description']?.toString() ?? '',
      borderName: json['border_name']?.toString(),
      entryLimit: (json['entry_limit'] as num?)?.toInt() ?? 0,
      entriesRemaining: (json['entries_remaining'] as num?)?.toInt() ?? 0,
      issuedAt: DateTime.parse(json['issued_at']?.toString() ?? DateTime.now().toIso8601String()),
      expiresAt: DateTime.parse(json['expires_at']?.toString() ?? DateTime.now().toIso8601String()),
      status: json['status']?.toString() ?? 'active',
      currency: json['currency']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      qrCode: qrCodeString,
      shortCode: json['short_code']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pass_id': passId,
      'vehicle_desc': vehicleDescription,
      'pass_description': passDescription,
      'border_name': borderName,
      'entry_limit': entryLimit,
      'entries_remaining': entriesRemaining,
      'issued_at': issuedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'status': status,
      'currency': currency,
      'amount': amount,
      'qr_code': qrCode,
      'short_code': shortCode,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isActive => status == 'active' && !isExpired;
  bool get hasEntriesRemaining => entriesRemaining > 0;

  String get statusDisplay {
    if (isExpired) return 'Expired';
    if (status == 'active') return 'Active';
    return status.toUpperCase();
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PurchasedPass &&
        other.passId == passId &&
        other.vehicleDescription == vehicleDescription &&
        other.passDescription == passDescription &&
        other.borderName == borderName &&
        other.entryLimit == entryLimit &&
        other.entriesRemaining == entriesRemaining &&
        other.issuedAt == issuedAt &&
        other.expiresAt == expiresAt &&
        other.status == status &&
        other.currency == currency &&
        other.amount == amount &&
        other.qrCode == qrCode &&
        other.shortCode == shortCode;
  }

  @override
  int get hashCode {
    return Object.hash(
      passId,
      vehicleDescription,
      passDescription,
      borderName,
      entryLimit,
      entriesRemaining,
      issuedAt,
      expiresAt,
      status,
      currency,
      amount,
      qrCode,
      shortCode,
    );
  }

  @override
  String toString() {
    return 'PurchasedPass(passId: $passId, passDescription: $passDescription, status: $status)';
  }
}
