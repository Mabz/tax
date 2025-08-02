class BorderType {
  final String id;
  final String code;
  final String label;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  BorderType({
    required this.id,
    required this.code,
    required this.label,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BorderType.fromJson(Map<String, dynamic> json) {
    return BorderType(
      id: json['id'] as String,
      code: json['code'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'label': label,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BorderType copyWith({
    String? id,
    String? code,
    String? label,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BorderType(
      id: id ?? this.id,
      code: code ?? this.code,
      label: label ?? this.label,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'BorderType(id: $id, code: $code, label: $label, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BorderType && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
