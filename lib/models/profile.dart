import '../constants/app_constants.dart';

/// Profile model representing a user profile in the EasyTax system
class Profile {
  final String id;
  final String? fullName;
  final String? email;
  final String? profileImageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    this.fullName,
    this.email,
    this.profileImageUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create Profile from JSON (from Supabase)
  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json[AppConstants.fieldId] as String,
      fullName: json[AppConstants.fieldProfileFullName] as String?,
      email: json[AppConstants.fieldProfileEmail] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      isActive: json[AppConstants.fieldProfileIsActive] as bool? ?? true,
      createdAt: DateTime.parse(json[AppConstants.fieldCreatedAt] as String),
      updatedAt: DateTime.parse(json[AppConstants.fieldUpdatedAt] as String),
    );
  }

  /// Convert Profile to JSON (for Supabase)
  Map<String, dynamic> toJson() {
    return {
      AppConstants.fieldId: id,
      AppConstants.fieldProfileFullName: fullName,
      AppConstants.fieldProfileEmail: email,
      'profile_image_url': profileImageUrl,
      AppConstants.fieldProfileIsActive: isActive,
      AppConstants.fieldCreatedAt: createdAt.toIso8601String(),
      AppConstants.fieldUpdatedAt: updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Profile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? profileImageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if profile is complete (has required fields)
  bool get isComplete {
    return fullName != null &&
        fullName!.trim().isNotEmpty &&
        email != null &&
        email!.trim().isNotEmpty;
  }

  /// Check if profile needs setup (missing critical information)
  bool get needsSetup => !isComplete;

  @override
  String toString() {
    return 'Profile(id: $id, fullName: $fullName, email: $email)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Profile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
