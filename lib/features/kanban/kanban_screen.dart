import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/project.dart';
import '../../core/models/task.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/theme/app_theme.dart';
import '../shell/widgets/add_project_dialog.dart';
import 'widgets/task_card.dart';
import 'widgets/add_task_dialog.dart';

class PlanningScreen extends StatelessWidget {
  const PlanningScreen({super.key});

  Future<void> _showAddProjectDialog(BuildContext context) async {
    final result = await showDialog<({String name, String description, int color})>(
      context: context,
      builder: (_) => const AddProjectDialog(),
    );
    if (result != null && context.mounted) {
      context.read<ProjectsProvider>().addProject(
        name: result.name,
        description: result.description,
        colorValue: result.color,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projects = context.watch<ProjectsProvider>().projects;
    final tasksProvider = context.watch<TasksProvider>();

    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.view_kanban_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a project to start tracking tasks',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _ColumnHeaders(onAddProject: () => _showAddProjectDialog(context)),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
            child: Column(
              children: [
                for (final project in projects)
                  _ProjectRow(project: project, tasksProvider: tasksProvider),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ColumnHeaders extends StatelessWidget {
  final VoidCallback onAddProject;

  const _ColumnHeaders({required this.onAddProject});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onAddProject,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        'New Project',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _StatusLabel(label: 'Done', color: AppTheme.kanbanDone)),
          const SizedBox(width: 8),
          Expanded(child: _StatusLabel(label: 'In Progress', color: AppTheme.kanbanInProgress)),
          const SizedBox(width: 8),
          Expanded(child: _StatusLabel(label: 'To Do', color: AppTheme.kanbanTodo)),
        ],
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final Project project;
  final TasksProvider tasksProvider;

  const _ProjectRow({required this.project, required this.tasksProvider});

  @override
  Widget build(BuildContext context) {
    final todoTasks = tasksProvider.tasksByStatus(project.id, TaskStatus.todo);
    final inProgressTasks = tasksProvider.tasksByStatus(project.id, TaskStatus.inProgress);
    final doneTasks = tasksProvider.tasksByStatus(project.id, TaskStatus.done);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Column(
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 180,
                    child: _ProjectLabel(
                      project: project,
                      taskCount: todoTasks.length + inProgressTasks.length + doneTasks.length,
                      onAddTask: () => _showAddTaskDialog(context),
                      onDelete: () => _deleteProject(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatusCell(
                      status: TaskStatus.done,
                      tasks: doneTasks,
                      accentColor: AppTheme.kanbanDone,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusCell(
                      status: TaskStatus.inProgress,
                      tasks: inProgressTasks,
                      accentColor: AppTheme.kanbanInProgress,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusCell(
                      status: TaskStatus.todo,
                      tasks: todoTasks,
                      accentColor: AppTheme.kanbanTodo,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final result = await showDialog<({String title, String description, TaskPriority priority})>(
      context: context,
      builder: (_) => const AddTaskDialog(),
    );
    if (result != null && context.mounted) {
      context.read<TasksProvider>().addTask(
            projectId: project.id,
            title: result.title,
            description: result.description,
            priority: result.priority,
          );
    }
  }

  Future<void> _deleteProject(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text(
          'This will permanently delete the project and all its tasks. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ProjectsProvider>().deleteProject(project.id);
    }
  }
}

class _ProjectLabel extends StatelessWidget {
  final Project project;
  final int taskCount;
  final VoidCallback onAddTask;
  final VoidCallback onDelete;

  const _ProjectLabel({
    required this.project,
    required this.taskCount,
    required this.onAddTask,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final projectColor = Color(project.colorValue);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: projectColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  project.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$taskCount tasks',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _SmallAction(
                icon: Icons.add,
                label: 'Add',
                onTap: onAddTask,
              ),
              const SizedBox(width: 4),
              _SmallAction(
                icon: Icons.delete_outline,
                onTap: onDelete,
                color: Colors.red.shade400,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final Color? color;

  const _SmallAction({required this.icon, this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: c),
            if (label != null) ...[
              const SizedBox(width: 3),
              Text(label!, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCell extends StatelessWidget {
  final TaskStatus status;
  final List<Task> tasks;
  final Color accentColor;

  const _StatusCell({
    required this.status,
    required this.tasks,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        context.read<TasksProvider>().moveTask(details.data.id, status);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
            color: isHovering
                ? accentColor.withValues(alpha: 0.06)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: isHovering
                ? Border.all(color: accentColor.withValues(alpha: 0.3), width: 2)
                : Border.all(color: Colors.grey.shade200, width: 1),
          ),
          padding: const EdgeInsets.all(6),
          child: tasks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Drop here',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final task in tasks)
                      TaskCard(task: task),
                  ],
                ),
        );
      },
    );
  }
}
