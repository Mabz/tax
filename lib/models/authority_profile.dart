/// Model representing a user's profile within an authority
class AuthorityProfile {
  final String id;
  final String profileId;
  final String authorityId;
  final bool isActive;
  final DateTime assignedAt;
  final DateTime? updatedAt;

  // Profile information
  final String profileEmail;
  final String? profileFullName;
  final String? profileImageUrl;

  // Authority information
  final String? authorityName;
  final String? authorityCode;

  // Additional fields for UI
  final String? assignedByName;
  final String? notes;
  final String? displayNameFromDb; // display_name from authority_profiles table

  AuthorityProfile({
    required this.id,
    required this.profileId,
    required this.authorityId,
    required this.isActive,
    required this.assignedAt,
    this.updatedAt,
    required this.profileEmail,
    this.profileFullName,
    this.profileImageUrl,
    this.authorityName,
    this.authorityCode,
    this.assignedByName,
    this.notes,
    this.displayNameFromDb,
  });

  /// Create AuthorityProfile from JSON (from database)
  factory AuthorityProfile.fromJson(Map<String, dynamic> json) {
    final profileData = json['profiles'] as Map<String, dynamic>?;
    final authorityData = json['authorities'] as Map<String, dynamic>?;

    return AuthorityProfile(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      authorityId: json['authority_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      assignedAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      profileEmail: profileData?['email'] as String? ?? '',
      profileFullName: profileData?['full_name'] as String?,
      profileImageUrl: profileData?['profile_image_url'] as String?,
      authorityName: authorityData?['name'] as String?,
      authorityCode: authorityData?['code'] as String?,
      notes: null, // Notes field doesn't exist in current database schema
      displayNameFromDb: json['display_name'] as String?,
    );
  }

  /// Convert AuthorityProfile to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'authority_id': authorityId,
      'is_active': isActive,
      'created_at': assignedAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  /// Get display name for the user
  String get displayName {
    // Prioritize display_name from authority_profiles table
    if (displayNameFromDb != null && displayNameFromDb!.isNotEmpty) {
      return displayNameFromDb!;
    }
    // Fallback to full_name from profiles table
    if (profileFullName != null && profileFullName!.isNotEmpty) {
      return profileFullName!;
    }
    return profileEmail.split('@').first; // Use email prefix as fallback
  }

  /// Create a copy with updated fields
  AuthorityProfile copyWith({
    String? id,
    String? profileId,
    String? authorityId,
    bool? isActive,
    DateTime? assignedAt,
    DateTime? updatedAt,
    String? profileEmail,
    String? profileFullName,
    String? profileImageUrl,
    String? authorityName,
    String? authorityCode,
    String? assignedByName,
    String? notes,
    String? displayNameFromDb,
  }) {
    return AuthorityProfile(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      authorityId: authorityId ?? this.authorityId,
      isActive: isActive ?? this.isActive,
      assignedAt: assignedAt ?? this.assignedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileEmail: profileEmail ?? this.profileEmail,
      profileFullName: profileFullName ?? this.profileFullName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      authorityName: authorityName ?? this.authorityName,
      authorityCode: authorityCode ?? this.authorityCode,
      assignedByName: assignedByName ?? this.assignedByName,
      notes: notes ?? this.notes,
      displayNameFromDb: displayNameFromDb ?? this.displayNameFromDb,
    );
  }

  @override
  String toString() {
    return 'AuthorityProfile(id: $id, profileEmail: $profileEmail, displayName: $displayName, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthorityProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
