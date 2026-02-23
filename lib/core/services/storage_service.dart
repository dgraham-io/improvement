import 'package:hive_flutter/hive_flutter.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/journal_entry.dart';
import '../models/pomodoro_session.dart';

class StorageService {
  static const _projectsBox = 'projects';
  static const _tasksBox = 'tasks';
  static const _journalBox = 'journal';
  static const _pomodoroBox = 'pomodoro';

  late Box _projects;
  late Box _tasks;
  late Box _journal;
  late Box _pomodoro;

  Future<void> init() async {
    await Hive.initFlutter();
    _projects = await Hive.openBox(_projectsBox);
    _tasks = await Hive.openBox(_tasksBox);
    _journal = await Hive.openBox(_journalBox);
    _pomodoro = await Hive.openBox(_pomodoroBox);
  }

  // Projects
  List<Project> getProjects() {
    return _projects.values
        .map((e) => Project.fromMap(e as Map))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveProject(Project project) async {
    await _projects.put(project.id, project.toMap());
  }

  Future<void> deleteProject(String id) async {
    await _projects.delete(id);
    final taskKeys = _tasks.keys.where((key) {
      final map = _tasks.get(key) as Map;
      return map['projectId'] == id;
    }).toList();
    for (final key in taskKeys) {
      await _tasks.delete(key);
    }
  }

  // Tasks
  List<Task> getTasks({String? projectId}) {
    var entries = _tasks.values.map((e) => Task.fromMap(e as Map));
    if (projectId != null) {
      entries = entries.where((t) => t.projectId == projectId);
    }
    return entries.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveTask(Task task) async {
    await _tasks.put(task.id, task.toMap());
  }

  Future<void> deleteTask(String id) async {
    await _tasks.delete(id);
  }

  // Journal
  List<JournalEntry> getJournalEntries({String? projectId}) {
    var entries =
        _journal.values.map((e) => JournalEntry.fromMap(e as Map));
    if (projectId != null) {
      entries = entries.where((e) => e.projectId == projectId);
    }
    return entries.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveJournalEntry(JournalEntry entry) async {
    await _journal.put(entry.id, entry.toMap());
  }

  Future<void> deleteJournalEntry(String id) async {
    await _journal.delete(id);
  }

  // Pomodoro
  List<PomodoroSession> getPomodoroSessions() {
    return _pomodoro.values
        .map((e) => PomodoroSession.fromMap(e as Map))
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  Future<void> savePomodoroSession(PomodoroSession session) async {
    await _pomodoro.put(session.id, session.toMap());
  }
}
