import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../services/storage_service.dart';

class TasksProvider extends ChangeNotifier {
  final StorageService _storage;
  final _uuid = const Uuid();

  List<Task> _tasks = [];

  TasksProvider(this._storage) {
    _loadTasks();
  }

  List<Task> get allTasks => List.unmodifiable(_tasks);

  List<Task> tasksForProject(String projectId) =>
      _tasks.where((t) => t.projectId == projectId).toList();

  List<Task> tasksByStatus(String projectId, TaskStatus status) =>
      _tasks
          .where((t) => t.projectId == projectId && t.status == status)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  int taskCount({TaskStatus? status}) {
    if (status == null) return _tasks.length;
    return _tasks.where((t) => t.status == status).length;
  }

  void _loadTasks() {
    _tasks = _storage.getTasks();
    notifyListeners();
  }

  Future<Task> addTask({
    required String projectId,
    required String title,
    String description = '',
    TaskStatus status = TaskStatus.todo,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
  }) async {
    final now = DateTime.now();
    final task = Task(
      id: _uuid.v4(),
      projectId: projectId,
      title: title,
      description: description,
      status: status,
      priority: priority,
      dueDate: dueDate,
      createdAt: now,
      updatedAt: now,
    );
    await _storage.saveTask(task);
    _loadTasks();
    return task;
  }

  Future<void> updateTask(Task task) async {
    await _storage.saveTask(task.copyWith(updatedAt: DateTime.now()));
    _loadTasks();
  }

  Future<void> moveTask(String taskId, TaskStatus newStatus) async {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    await _storage.saveTask(
      task.copyWith(status: newStatus, updatedAt: DateTime.now()),
    );
    _loadTasks();
  }

  Future<void> deleteTask(String id) async {
    await _storage.deleteTask(id);
    _loadTasks();
  }
}
