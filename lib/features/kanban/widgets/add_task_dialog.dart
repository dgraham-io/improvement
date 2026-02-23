import 'package:flutter/material.dart';
import '../../../core/models/task.dart';
import '../../../core/theme/app_theme.dart';

class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({super.key});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Task'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Task title',
                hintText: 'What needs to be done?',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add some details...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Priority',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<TaskPriority>(
              segments: [
                ButtonSegment(
                  value: TaskPriority.low,
                  label: const Text('Low'),
                  icon: Icon(Icons.arrow_downward, size: 16, color: AppTheme.priorityLow),
                ),
                ButtonSegment(
                  value: TaskPriority.medium,
                  label: const Text('Medium'),
                  icon: Icon(Icons.remove, size: 16, color: AppTheme.priorityMedium),
                ),
                ButtonSegment(
                  value: TaskPriority.high,
                  label: const Text('High'),
                  icon: Icon(Icons.arrow_upward, size: 16, color: AppTheme.priorityHigh),
                ),
              ],
              selected: {_priority},
              onSelectionChanged: (set) => setState(() => _priority = set.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop((
      title: title,
      description: _descController.text.trim(),
      priority: _priority,
    ));
  }
}
