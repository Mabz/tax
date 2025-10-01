/// Enhanced border assignment model with direction permissions
class EnhancedBorderAssignment {
  final String borderId;
  final String borderName;
  final bool isAssigned;
  final bool canCheckIn;
  final bool canCheckOut;

  EnhancedBorderAssignment({
    required this.borderId,
    required this.borderName,
    required this.isAssigned,
    required this.canCheckIn,
    required this.canCheckOut,
  });

  factory EnhancedBorderAssignment.fromBorder(
    Map<String, dynamic> border, {
    bool isAssigned = false,
    bool canCheckIn = true,
    bool canCheckOut = true,
  }) {
    return EnhancedBorderAssignment(
      borderId: border['id'] as String,
      borderName: border['name'] as String,
      isAssigned: isAssigned,
      canCheckIn: canCheckIn,
      canCheckOut: canCheckOut,
    );
  }

  EnhancedBorderAssignment copyWith({
    bool? isAssigned,
    bool? canCheckIn,
    bool? canCheckOut,
  }) {
    return EnhancedBorderAssignment(
      borderId: borderId,
      borderName: borderName,
      isAssigned: isAssigned ?? this.isAssigned,
      canCheckIn: canCheckIn ?? this.canCheckIn,
      canCheckOut: canCheckOut ?? this.canCheckOut,
    );
  }

  String get permissionDescription {
    if (!isAssigned) return 'Not Assigned';
    if (canCheckIn && canCheckOut) return 'Entry & Exit';
    if (canCheckIn) return 'Entry Only';
    if (canCheckOut) return 'Exit Only';
    return 'No Permissions';
  }

  bool get hasValidPermissions => isAssigned && (canCheckIn || canCheckOut);
}
