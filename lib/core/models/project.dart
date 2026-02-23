class Project {
  final String id;
  final String name;
  final String description;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    this.description = '',
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
  });

  Project copyWith({
    String? name,
    String? description,
    int? colorValue,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Project.fromMap(Map<dynamic, dynamic> map) => Project(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        colorValue: map['colorValue'] as int,
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );
}
