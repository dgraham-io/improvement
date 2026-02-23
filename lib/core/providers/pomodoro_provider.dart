import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/pomodoro_session.dart';
import '../services/storage_service.dart';

enum TimerState { idle, running, paused }

class PomodoroProvider extends ChangeNotifier {
  final StorageService _storage;
  final _uuid = const Uuid();

  static const defaultWorkMinutes = 25;
  static const defaultShortBreakMinutes = 5;
  static const defaultLongBreakMinutes = 15;
  static const sessionsBeforeLongBreak = 4;

  TimerState _state = TimerState.idle;
  PomodoroPhase _phase = PomodoroPhase.work;
  int _remainingSeconds = defaultWorkMinutes * 60;
  int _completedWorkSessions = 0;
  Timer? _timer;

  String? _linkedTaskId;
  String? _linkedTaskTitle;
  String? _linkedProjectId;

  List<PomodoroSession> _todaySessions = [];

  PomodoroProvider(this._storage) {
    _loadTodaySessions();
  }

  TimerState get state => _state;
  PomodoroPhase get phase => _phase;
  int get remainingSeconds => _remainingSeconds;
  int get completedWorkSessions => _completedWorkSessions;
  String? get linkedTaskId => _linkedTaskId;
  String? get linkedTaskTitle => _linkedTaskTitle;
  List<PomodoroSession> get todaySessions => List.unmodifiable(_todaySessions);

  int get totalMinutes {
    switch (_phase) {
      case PomodoroPhase.work:
        return defaultWorkMinutes;
      case PomodoroPhase.shortBreak:
        return defaultShortBreakMinutes;
      case PomodoroPhase.longBreak:
        return defaultLongBreakMinutes;
    }
  }

  double get progress {
    final total = totalMinutes * 60;
    if (total == 0) return 0;
    return 1.0 - (_remainingSeconds / total);
  }

  String get displayTime {
    final m = (_remainingSeconds / 60).ceil();
    return '${m}m';
  }

  int get todayWorkSessionCount =>
      _todaySessions.where((s) => s.phase == PomodoroPhase.work).length;

  int get todayFocusMinutes => _todaySessions
      .where((s) => s.phase == PomodoroPhase.work)
      .fold(0, (sum, s) => sum + s.durationMinutes);

  void linkTask({required String taskId, required String title, String? projectId}) {
    _linkedTaskId = taskId;
    _linkedTaskTitle = title;
    _linkedProjectId = projectId;
    notifyListeners();
  }

  void unlinkTask() {
    _linkedTaskId = null;
    _linkedTaskTitle = null;
    _linkedProjectId = null;
    notifyListeners();
  }

  void start() {
    if (_state == TimerState.running) return;
    _state = TimerState.running;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void pause() {
    _timer?.cancel();
    _state = TimerState.paused;
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _state = TimerState.idle;
    _remainingSeconds = totalMinutes * 60;
    notifyListeners();
  }

  void skip() {
    _timer?.cancel();
    _advancePhase();
    notifyListeners();
  }

  void _tick() {
    if (_remainingSeconds <= 0) {
      _timer?.cancel();
      _onPhaseComplete();
      return;
    }
    final prevMinute = (_remainingSeconds / 60).ceil();
    _remainingSeconds--;
    final newMinute = (_remainingSeconds / 60).ceil();
    if (newMinute != prevMinute || _remainingSeconds <= 0) {
      notifyListeners();
    }
  }

  void _onPhaseComplete() {
    final session = PomodoroSession(
      id: _uuid.v4(),
      taskId: _linkedTaskId,
      taskTitle: _linkedTaskTitle,
      projectId: _linkedProjectId,
      phase: _phase,
      durationMinutes: totalMinutes,
      completedAt: DateTime.now(),
    );
    _storage.savePomodoroSession(session);
    _todaySessions.insert(0, session);

    if (_phase == PomodoroPhase.work) {
      _completedWorkSessions++;
    }

    _advancePhase();
  }

  void _advancePhase() {
    if (_phase == PomodoroPhase.work) {
      if (_completedWorkSessions > 0 &&
          _completedWorkSessions % sessionsBeforeLongBreak == 0) {
        _phase = PomodoroPhase.longBreak;
      } else {
        _phase = PomodoroPhase.shortBreak;
      }
    } else {
      _phase = PomodoroPhase.work;
    }
    _remainingSeconds = totalMinutes * 60;
    _state = TimerState.idle;
    notifyListeners();
  }

  void _loadTodaySessions() {
    final now = DateTime.now();
    _todaySessions = _storage
        .getPomodoroSessions()
        .where((s) =>
            s.completedAt.year == now.year &&
            s.completedAt.month == now.month &&
            s.completedAt.day == now.day)
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
