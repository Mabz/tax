class BorderOfficial {
  final String profileId;
  final String fullName;
  final String email;
  final int borderCount;
  final String assignedBorders;

  BorderOfficial({
    required this.profileId,
    required this.fullName,
    required this.email,
    required this.borderCount,
    required this.assignedBorders,
  });

  factory BorderOfficial.fromJson(Map<String, dynamic> json) {
    return BorderOfficial(
      profileId: json['profile_id'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      borderCount: json['border_count'] ?? 0,
      assignedBorders: json['assigned_borders'] ?? '',
    );
  }

  factory BorderOfficial.fromProfileData(Map<String, dynamic> json) {
    return BorderOfficial(
      profileId: json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      borderCount: 0, // Will be populated separately if needed
      assignedBorders: '', // Will be populated separately if needed
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'full_name': fullName,
      'email': email,
      'border_count': borderCount,
      'assigned_borders': assignedBorders,
    };
  }

  bool get hasAssignedBorders => borderCount > 0;
  
  List<String> get assignedBordersList {
    if (assignedBorders.isEmpty) return [];
    return assignedBorders.split(', ');
  }
}
