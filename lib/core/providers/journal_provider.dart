import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/journal_entry.dart';
import '../services/storage_service.dart';

class JournalProvider extends ChangeNotifier {
  final StorageService _storage;
  final _uuid = const Uuid();

  List<JournalEntry> _entries = [];

  JournalProvider(this._storage) {
    _loadEntries();
  }

  List<JournalEntry> get entries => List.unmodifiable(_entries);

  List<JournalEntry> entriesForDate(DateTime date) => _entries
      .where((e) =>
          e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day)
      .toList();

  List<JournalEntry> entriesForProject(String projectId) =>
      _entries.where((e) => e.projectId == projectId).toList();

  List<JournalEntry> get recentEntries =>
      _entries.take(10).toList();

  void _loadEntries() {
    _entries = _storage.getJournalEntries();
    notifyListeners();
  }

  Future<JournalEntry> addEntry({
    required String content,
    String? taskId,
    String? projectId,
    DateTime? date,
  }) async {
    final now = DateTime.now();
    final entry = JournalEntry(
      id: _uuid.v4(),
      content: content,
      taskId: taskId,
      projectId: projectId,
      date: date ?? now,
      createdAt: now,
      updatedAt: now,
    );
    await _storage.saveJournalEntry(entry);
    _loadEntries();
    return entry;
  }

  Future<void> updateEntry(JournalEntry entry) async {
    await _storage.saveJournalEntry(
      entry.copyWith(updatedAt: DateTime.now()),
    );
    _loadEntries();
  }

  Future<void> deleteEntry(String id) async {
    await _storage.deleteJournalEntry(id);
    _loadEntries();
  }
}
