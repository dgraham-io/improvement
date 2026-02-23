import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../journal/journal_screen.dart';
import '../kanban/kanban_screen.dart' show PlanningScreen;
import 'widgets/pomodoro_timer_widget.dart';

enum NavDestination { dashboard, planning, journal }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  NavDestination _destination = NavDestination.planning;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _TopBar(
            destination: _destination,
            onDestinationSelected: (dest) {
              setState(() => _destination = dest);
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_destination) {
      case NavDestination.dashboard:
        return const DashboardScreen();
      case NavDestination.planning:
        return const PlanningScreen();
      case NavDestination.journal:
        return const JournalScreen();
    }
  }

}

class _TopBar extends StatelessWidget {
  final NavDestination destination;
  final ValueChanged<NavDestination> onDestinationSelected;

  const _TopBar({
    required this.destination,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Text(
            'Improvement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 24),
          _NavChip(
            icon: Icons.dashboard_rounded,
            label: 'Dashboard',
            selected: destination == NavDestination.dashboard,
            onTap: () => onDestinationSelected(NavDestination.dashboard),
          ),
          const SizedBox(width: 6),
          _NavChip(
            icon: Icons.view_kanban_rounded,
            label: 'Planning',
            selected: destination == NavDestination.planning,
            onTap: () => onDestinationSelected(NavDestination.planning),
          ),
          const SizedBox(width: 6),
          _NavChip(
            icon: Icons.book_rounded,
            label: 'Journal',
            selected: destination == NavDestination.journal,
            onTap: () => onDestinationSelected(NavDestination.journal),
          ),
          const Spacer(),
          const PomodoroTimerWidget(),
        ],
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? primaryColor.withValues(alpha: 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        hoverColor: Colors.grey.shade100,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? primaryColor : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? primaryColor : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
