import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/models/journal_entry.dart';
import '../../core/providers/journal_provider.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _editorController = TextEditingController();
  String? _editingEntryId;
  bool _composing = false;

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<JournalProvider>().entries;
    final grouped = _groupByDay(entries);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            if (_composing || _editingEntryId != null)
              SliverToBoxAdapter(child: _buildEditor(context)),
            if (entries.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              ..._buildGroupedEntries(context, grouped),
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          const Icon(Icons.book_rounded, size: 26),
          const SizedBox(width: 12),
          const Text(
            'Journal',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (!_composing && _editingEntryId == null)
            ElevatedButton.icon(
              onPressed: () => setState(() => _composing = true),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Entry'),
            ),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final isEditing = _editingEntryId != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit Entry' : 'New Entry',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _editorController,
                maxLines: 5,
                autofocus: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'What\'s on your mind?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _saveEntry(context),
                    child: Text(isEditing ? 'Update' : 'Save'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _cancelEditing,
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.edit_note, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No journal entries yet',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "New Entry" to start writing',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedEntries(
    BuildContext context,
    List<({DateTime date, List<JournalEntry> entries})> groups,
  ) {
    final slivers = <Widget>[];
    for (final group in groups) {
      slivers.add(SliverToBoxAdapter(child: _DaySeparator(date: group.date)));
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, index) {
              final entry = group.entries[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _JournalEntryCard(
                  entry: entry,
                  onEdit: () => _startEditing(entry),
                  onDelete: () =>
                      context.read<JournalProvider>().deleteEntry(entry.id),
                ),
              );
            },
            childCount: group.entries.length,
          ),
        ),
      );
    }
    return slivers;
  }

  List<({DateTime date, List<JournalEntry> entries})> _groupByDay(
    List<JournalEntry> entries,
  ) {
    final groups = <String, List<JournalEntry>>{};
    for (final entry in entries) {
      final key = '${entry.date.year}-${entry.date.month}-${entry.date.day}';
      (groups[key] ??= []).add(entry);
    }
    final result = groups.entries.map((e) {
      final first = e.value.first;
      return (
        date: DateTime(first.date.year, first.date.month, first.date.day),
        entries: e.value,
      );
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  void _startEditing(JournalEntry entry) {
    setState(() {
      _editingEntryId = entry.id;
      _composing = false;
      _editorController.text = entry.content;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingEntryId = null;
      _composing = false;
      _editorController.clear();
    });
  }

  void _saveEntry(BuildContext context) {
    final content = _editorController.text.trim();
    if (content.isEmpty) return;

    final provider = context.read<JournalProvider>();
    if (_editingEntryId != null) {
      final existing =
          provider.entries.firstWhere((e) => e.id == _editingEntryId);
      provider.updateEntry(existing.copyWith(content: content));
    } else {
      provider.addEntry(content: content);
    }
    _cancelEditing();
  }
}

class _DaySeparator extends StatelessWidget {
  final DateTime date;

  const _DaySeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1;

    String label;
    if (isToday) {
      label = 'Today — ${DateFormat.MMMd().format(date)}';
    } else if (isYesterday) {
      label = 'Yesterday — ${DateFormat.MMMd().format(date)}';
    } else {
      label = DateFormat.yMMMEd().format(date);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(height: 1, color: Colors.grey.shade200),
          ),
        ],
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _JournalEntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, size: 13, color: Colors.grey.shade400),
                const SizedBox(width: 5),
                Text(
                  DateFormat.jm().format(entry.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const Spacer(),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined,
                        size: 14, color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline,
                        size: 14, color: Colors.grey.shade400),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.content,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}
