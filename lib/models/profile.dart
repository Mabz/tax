import '../constants/app_constants.dart';

/// Profile model representing a user profile in the EasyTax system
class Profile {
  final String id;
  final String? fullName;
  final String? email;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    this.fullName,
    this.email,
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
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
