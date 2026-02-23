enum PomodoroPhase { work, shortBreak, longBreak }

class PomodoroSession {
  final String id;
  final String? taskId;
  final String? taskTitle;
  final String? projectId;
  final PomodoroPhase phase;
  final int durationMinutes;
  final DateTime completedAt;

  PomodoroSession({
    required this.id,
    this.taskId,
    this.taskTitle,
    this.projectId,
    required this.phase,
    required this.durationMinutes,
    required this.completedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'taskId': taskId,
        'taskTitle': taskTitle,
        'projectId': projectId,
        'phase': phase.index,
        'durationMinutes': durationMinutes,
        'completedAt': completedAt.toIso8601String(),
      };

  factory PomodoroSession.fromMap(Map<dynamic, dynamic> map) =>
      PomodoroSession(
        id: map['id'] as String,
        taskId: map['taskId'] as String?,
        taskTitle: map['taskTitle'] as String?,
        projectId: map['projectId'] as String?,
        phase: PomodoroPhase.values[map['phase'] as int],
        durationMinutes: map['durationMinutes'] as int,
        completedAt: DateTime.parse(map['completedAt'] as String),
      );
}
