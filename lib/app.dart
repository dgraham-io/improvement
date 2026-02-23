import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/providers/journal_provider.dart';
import 'core/providers/pomodoro_provider.dart';
import 'core/providers/projects_provider.dart';
import 'core/providers/tasks_provider.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';

class ImprovementApp extends StatelessWidget {
  final StorageService storage;

  const ImprovementApp({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProjectsProvider(storage)),
        ChangeNotifierProvider(create: (_) => TasksProvider(storage)),
        ChangeNotifierProvider(create: (_) => JournalProvider(storage)),
        ChangeNotifierProvider(create: (_) => PomodoroProvider(storage)),
      ],
      child: MaterialApp(
        title: 'Improvement',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AppShell(),
      ),
    );
  }
}
