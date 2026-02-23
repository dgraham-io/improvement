import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import '../services/storage_service.dart';

class ProjectsProvider extends ChangeNotifier {
  final StorageService _storage;
  final _uuid = const Uuid();

  List<Project> _projects = [];
  String? _selectedProjectId;

  ProjectsProvider(this._storage) {
    _loadProjects();
  }

  List<Project> get projects => List.unmodifiable(_projects);
  String? get selectedProjectId => _selectedProjectId;

  Project? get selectedProject {
    if (_selectedProjectId == null) return null;
    try {
      return _projects.firstWhere((p) => p.id == _selectedProjectId);
    } catch (_) {
      return null;
    }
  }

  void _loadProjects() {
    _projects = _storage.getProjects();
    notifyListeners();
  }

  void selectProject(String? id) {
    _selectedProjectId = id;
    notifyListeners();
  }

  Future<Project> addProject({
    required String name,
    String description = '',
    required int colorValue,
  }) async {
    final now = DateTime.now();
    final project = Project(
      id: _uuid.v4(),
      name: name,
      description: description,
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );
    await _storage.saveProject(project);
    _loadProjects();
    return project;
  }

  Future<void> updateProject(Project project) async {
    await _storage.saveProject(project.copyWith(updatedAt: DateTime.now()));
    _loadProjects();
  }

  Future<void> deleteProject(String id) async {
    if (_selectedProjectId == id) {
      _selectedProjectId = null;
    }
    await _storage.deleteProject(id);
    _loadProjects();
  }
}
