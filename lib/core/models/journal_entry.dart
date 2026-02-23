class JournalEntry {
  final String id;
  final String content;
  final String? taskId;
  final String? projectId;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;

  JournalEntry({
    required this.id,
    required this.content,
    this.taskId,
    this.projectId,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  JournalEntry copyWith({
    String? content,
    String? taskId,
    String? projectId,
    DateTime? date,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id,
      content: content ?? this.content,
      taskId: taskId ?? this.taskId,
      projectId: projectId ?? this.projectId,
      date: date ?? this.date,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'content': content,
        'taskId': taskId,
        'projectId': projectId,
        'date': date.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory JournalEntry.fromMap(Map<dynamic, dynamic> map) => JournalEntry(
        id: map['id'] as String,
        content: map['content'] as String,
        taskId: map['taskId'] as String?,
        projectId: map['projectId'] as String?,
        date: DateTime.parse(map['date'] as String),
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );
}
