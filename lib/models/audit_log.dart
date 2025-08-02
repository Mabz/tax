import '../constants/app_constants.dart';

/// Model representing an audit log entry
class AuditLog {
  final String id;
  final String actorProfileId;
  final String? targetProfileId;
  final String action;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  // Computed fields from joins
  final String? actorName;
  final String? actorEmail;
  final String? targetName;
  final String? targetEmail;

  const AuditLog({
    required this.id,
    required this.actorProfileId,
    this.targetProfileId,
    required this.action,
    this.metadata,
    required this.createdAt,
    this.actorName,
    this.actorEmail,
    this.targetName,
    this.targetEmail,
  });

  /// Create AuditLog from JSON (from database)
  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json[AppConstants.fieldId] as String,
      actorProfileId: json[AppConstants.fieldAuditLogActorProfileId] as String,
      targetProfileId: json[AppConstants.fieldAuditLogTargetProfileId] as String?,
      action: json[AppConstants.fieldAuditLogAction] as String,
      metadata: json[AppConstants.fieldAuditLogMetadata] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json[AppConstants.fieldCreatedAt] as String),
      actorName: json['actor_name'] as String?,
      actorEmail: json['actor_email'] as String?,
      targetName: json['target_name'] as String?,
      targetEmail: json['target_email'] as String?,
    );
  }

  /// Convert AuditLog to JSON
  Map<String, dynamic> toJson() {
    return {
      AppConstants.fieldId: id,
      AppConstants.fieldAuditLogActorProfileId: actorProfileId,
      AppConstants.fieldAuditLogTargetProfileId: targetProfileId,
      AppConstants.fieldAuditLogAction: action,
      AppConstants.fieldAuditLogMetadata: metadata,
      AppConstants.fieldCreatedAt: createdAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  AuditLog copyWith({
    String? id,
    String? actorProfileId,
    String? targetProfileId,
    String? action,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    String? actorName,
    String? actorEmail,
    String? targetName,
    String? targetEmail,
  }) {
    return AuditLog(
      id: id ?? this.id,
      actorProfileId: actorProfileId ?? this.actorProfileId,
      targetProfileId: targetProfileId ?? this.targetProfileId,
      action: action ?? this.action,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      actorName: actorName ?? this.actorName,
      actorEmail: actorEmail ?? this.actorEmail,
      targetName: targetName ?? this.targetName,
      targetEmail: targetEmail ?? this.targetEmail,
    );
  }

  @override
  String toString() {
    return 'AuditLog(id: $id, actorProfileId: $actorProfileId, targetProfileId: $targetProfileId, action: $action, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuditLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Get a human-readable description of the action
  String get actionDescription {
    switch (action) {
      case 'role_assigned':
        final roleName = metadata?['role_name'] as String?;
        final countryName = metadata?['country_name'] as String?;
        if (countryName != null && countryName != 'Global') {
          return 'Assigned $roleName role in $countryName';
        }
        return 'Assigned $roleName role';
      case 'role_removed':
        final roleName = metadata?['role_name'] as String?;
        final countryName = metadata?['country_name'] as String?;
        if (countryName != null && countryName != 'Global') {
          return 'Removed $roleName role from $countryName';
        }
        return 'Removed $roleName role';
      case 'role_updated':
        final roleName = metadata?['role_name'] as String?;
        return 'Updated $roleName role assignment';
      case 'profile_status_changed':
        final newStatus = metadata?['new_status'] as bool?;
        return newStatus == true ? 'Activated profile' : 'Deactivated profile';
      case 'border_created':
        final borderName = metadata?['border_name'] as String?;
        return 'Created border: $borderName';
      case 'border_updated':
        final borderName = metadata?['border_name'] as String?;
        return 'Updated border: $borderName';
      case 'border_deleted':
        final borderName = metadata?['border_name'] as String?;
        return 'Deleted border: $borderName';
      case 'border_status_changed':
        final borderName = metadata?['border_name'] as String?;
        final newStatus = metadata?['new_status'] as bool?;
        return '${newStatus == true ? 'Activated' : 'Deactivated'} border: $borderName';
      case 'country_created':
        final countryName = metadata?['country_name'] as String?;
        return 'Created country: $countryName';
      case 'country_updated':
        final countryName = metadata?['country_name'] as String?;
        return 'Updated country: $countryName';
      case 'country_deleted':
        final countryName = metadata?['country_name'] as String?;
        return 'Deleted country: $countryName';
      case 'border_type_created':
        final borderTypeName = metadata?['border_type_name'] as String?;
        return 'Created border type: $borderTypeName';
      case 'border_type_updated':
        final borderTypeName = metadata?['border_type_name'] as String?;
        return 'Updated border type: $borderTypeName';
      case 'border_type_deleted':
        final borderTypeName = metadata?['border_type_name'] as String?;
        return 'Deleted border type: $borderTypeName';
      default:
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }

  /// Get the target description (who was affected)
  String get targetDescription {
    if (targetName != null) {
      return targetName!;
    } else if (targetEmail != null) {
      return targetEmail!;
    } else if (targetProfileId != null) {
      return 'User ID: ${targetProfileId!.substring(0, 8)}...';
    }
    return 'System';
  }

  /// Get the actor description (who performed the action)
  String get actorDescription {
    if (actorName != null) {
      return actorName!;
    } else if (actorEmail != null) {
      return actorEmail!;
    }
    return 'User ID: ${actorProfileId.substring(0, 8)}...';
  }
}
