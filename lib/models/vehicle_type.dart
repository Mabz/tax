class VehicleType {
  final String id;
  final String label;
  final String? description;
  final bool isActive;

  VehicleType({
    required this.id,
    required this.label,
    this.description,
    required this.isActive,
  });

  factory VehicleType.fromJson(Map<String, dynamic> json) {
    return VehicleType(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      description: json['description'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'description': description,
      'is_active': isActive,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VehicleType && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
