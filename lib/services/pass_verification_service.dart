import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for verifying passes using hash codes or short codes
/// Used by border control systems and verification apps
class PassVerificationService {
  static final _supabase = Supabase.instance.client;

  /// Verify a pass using its UUID (primary method for QR scanning)
  static Future<PassVerificationResult?> verifyPassByUuid(String passUuid) async {
    try {
      final response = await _supabase.rpc('verify_pass_by_uuid', params: {
        'input_uuid': passUuid,
      });

      if (response != null && response.isNotEmpty) {
        final data = response[0] as Map<String, dynamic>;
        return PassVerificationResult.fromJson(data);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to verify pass by UUID: $e');
    }
  }

  /// Verify a pass using its hash code (legacy method for existing passes)
  static Future<PassVerificationResult?> verifyPassByHash(String passHash) async {
    try {
      final response = await _supabase.rpc('verify_pass_by_hash', params: {
        'input_hash': passHash,
      });

      if (response != null && response.isNotEmpty) {
        final data = response[0] as Map<String, dynamic>;
        return PassVerificationResult.fromJson(data);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to verify pass by hash: $e');
    }
  }

  /// Verify a pass using its short code (manual entry)
  static Future<PassVerificationResult?> verifyPassByShortCode(String shortCode) async {
    try {
      final response = await _supabase.rpc('verify_pass_by_short_code', params: {
        'input_code': shortCode,
      });

      if (response != null && response.isNotEmpty) {
        final data = response[0] as Map<String, dynamic>;
        return PassVerificationResult.fromJson(data);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to verify pass by short code: $e');
    }
  }

  /// Parse QR code data and extract UUID for verification (primary method)
  static String? extractUuidFromQrCode(String qrCodeData) {
    try {
      // Parse pipe-separated key:value pairs
      final pairs = qrCodeData.split('|');
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2 && (parts[0] == 'uuid' || parts[0] == 'passUuid' || parts[0] == 'id')) {
          return parts[1];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Parse QR code data and extract hash for verification (legacy method)
  static String? extractHashFromQrCode(String qrCodeData) {
    try {
      // Parse pipe-separated key:value pairs
      final pairs = qrCodeData.split('|');
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2 && parts[0] == 'hash') {
          return parts[1];
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Unified verification method that tries UUID first, then falls back to hash
  static Future<PassVerificationResult?> verifyPassFromQrCode(String qrCodeData) async {
    // Try UUID verification first (for new passes)
    final uuid = extractUuidFromQrCode(qrCodeData);
    if (uuid != null) {
      try {
        final result = await verifyPassByUuid(uuid);
        if (result != null) return result;
      } catch (e) {
        // Continue to hash verification if UUID fails
      }
    }

    // Fall back to hash verification (for existing passes)
    final hash = extractHashFromQrCode(qrCodeData);
    if (hash != null) {
      try {
        return await verifyPassByHash(hash);
      } catch (e) {
        // Hash verification failed
      }
    }

    return null;
  }

  /// Format short code for display (add dashes if needed)
  static String formatShortCode(String shortCode) {
    // Remove any existing dashes
    final clean = shortCode.replaceAll('-', '').toUpperCase();
    
    // Add dash in the middle if 8 characters
    if (clean.length == 8) {
      return '${clean.substring(0, 4)}-${clean.substring(4, 8)}';
    }
    
    return clean;
  }
}

/// Result of pass verification
class PassVerificationResult {
  final Map<String, dynamic> passData;
  final bool isValid;
  final String? passId;
  final String? passTemplate;
  final String? vehicle;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String? status;

  PassVerificationResult({
    required this.passData,
    required this.isValid,
    this.passId,
    this.passTemplate,
    this.vehicle,
    this.issuedAt,
    this.expiresAt,
    this.status,
  });

  factory PassVerificationResult.fromJson(Map<String, dynamic> json) {
    final passData = json['pass_data'] as Map<String, dynamic>? ?? {};
    final isValid = json['is_valid'] as bool? ?? false;

    return PassVerificationResult(
      passData: passData,
      isValid: isValid,
      passId: passData['passId']?.toString(),
      passTemplate: passData['passTemplate']?.toString(),
      vehicle: passData['vehicle']?.toString(),
      issuedAt: passData['issuedAt'] != null 
          ? DateTime.tryParse(passData['issuedAt'].toString())
          : null,
      status: json['status']?.toString(),
    );
  }

  /// Get a human-readable verification status
  String get statusMessage {
    if (!isValid) {
      return 'Invalid or expired pass';
    }
    return 'Valid pass';
  }

  /// Check if pass is currently active
  bool get isActive {
    return isValid && status == 'active';
  }

  /// Get formatted pass information for display
  Map<String, String> get displayInfo {
    return {
      'Status': statusMessage,
      'Pass ID': passId ?? 'Unknown',
      'Template': passTemplate ?? 'Unknown',
      'Vehicle': vehicle ?? 'Not specified',
      'Issued': issuedAt?.toString() ?? 'Unknown',
      'Valid': isValid ? 'Yes' : 'No',
    };
  }
}
