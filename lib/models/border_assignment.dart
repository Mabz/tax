class BorderAssignment {
  final String borderId;
  final String borderName;
  final String borderTypeLabel;
  final String countryName;
  final String officialProfileId;
  final String officialName;
  final String officialEmail;
  final DateTime assignedAt;

  BorderAssignment({
    required this.borderId,
    required this.borderName,
    required this.borderTypeLabel,
    required this.countryName,
    required this.officialProfileId,
    required this.officialName,
    required this.officialEmail,
    required this.assignedAt,
  });

  factory BorderAssignment.fromJson(Map<String, dynamic> json) {
    return BorderAssignment(
      borderId: json['border_id'] ?? '',
      borderName: json['border_name'] ?? '',
      borderTypeLabel: json['border_type_label'] ?? '',
      countryName: json['country_name'] ?? '',
      officialProfileId: json['official_profile_id'] ?? '',
      officialName: json['official_name'] ?? '',
      officialEmail: json['official_email'] ?? '',
      assignedAt: DateTime.parse(json['assigned_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'border_id': borderId,
      'border_name': borderName,
      'border_type_label': borderTypeLabel,
      'country_name': countryName,
      'official_profile_id': officialProfileId,
      'official_name': officialName,
      'official_email': officialEmail,
      'assigned_at': assignedAt.toIso8601String(),
    };
  }
}
