# Improvement App — Architecture

## Overview

Improvement is a Flutter desktop app designed to help people stay focused, motivated, and organized using AI-powered tools. The MVP includes project/task management via Kanban boards, a daily journal, and a Pomodoro timer.

## Tech Stack

- **Framework:** Flutter (desktop: macOS, Linux, Windows)
- **Language:** Dart
- **State Management:** Provider + ChangeNotifier
- **Local Storage:** Hive (supports AES-256 encryption for future E2E needs)
- **Fonts:** Google Fonts (Inter)

## Directory Structure

```
lib/
├── main.dart                     # Entry point — initializes Hive, runs app
├── app.dart                      # MaterialApp, provider wiring, theme
│
├── core/                         # Shared foundation layer
│   ├── theme/
│   │   └── app_theme.dart        # Colors, typography, component themes
│   ├── models/
│   │   ├── project.dart          # Project with name, description, color
│   │   ├── task.dart             # Task with status, priority, due date
│   │   ├── journal_entry.dart    # Journal entry with optional project/task link
│   │   └── pomodoro_session.dart # Completed Pomodoro session record
│   ├── providers/
│   │   ├── projects_provider.dart  # Project CRUD, selection state
│   │   ├── tasks_provider.dart     # Task CRUD, filtering by project/status
│   │   ├── journal_provider.dart   # Journal CRUD, filtering by date/project
│   │   └── pomodoro_provider.dart  # Timer state machine, session tracking
│   └── services/
│       └── storage_service.dart  # Hive-backed persistence for all models
│
└── features/                     # Feature modules (one folder per screen area)
    ├── shell/
    │   ├── app_shell.dart        # Top-level layout: top nav bar + content area
    │   └── widgets/
    │       ├── add_project_dialog.dart
    │       └── pomodoro_timer_widget.dart  # Compact timer in top nav bar
    ├── dashboard/
    │   └── dashboard_screen.dart # Stats overview, project list, recent journal
    ├── kanban/
    │   ├── kanban_screen.dart    # Unified planning view — all projects in swimlane rows
    │   └── widgets/
    │       ├── task_card.dart     # Draggable card with priority badge + timer indicator
    │       └── add_task_dialog.dart
    └── journal/
        └── journal_screen.dart   # Date navigation, entry list, side-panel editor
```

## Architecture Principles

### Layered separation

- **`core/`** — Models, providers, services, and theme. No UI. Everything here is reusable across features.
- **`features/`** — One folder per app area. Each feature owns its screens and widgets. Features depend on `core/` but never on each other.

### Data flow

```
UI (widgets) ──reads──▶ Provider (ChangeNotifier) ──reads/writes──▶ StorageService ──persists──▶ Hive
     │                        ▲
     └──calls methods on──────┘
```

Widgets use `context.watch<Provider>()` for reactive rebuilds and `context.read<Provider>()` for one-off actions. Providers own all business logic and delegate persistence to `StorageService`.

### Models

All models are immutable Dart classes with `copyWith`, `toMap`, and `fromMap`. No code generation — serialization is hand-written for simplicity and to keep the dependency footprint small.

### Storage

Hive stores each model type in its own box (`projects`, `tasks`, `journal`, `pomodoro`). Data is serialized as `Map<String, dynamic>`. Hive was chosen because:
- Fast key-value lookups, no SQL overhead
- Works on all desktop platforms
- Built-in AES-256 encryption support (for future E2E encryption)

### Navigation

The app uses a top navigation bar (`AppShell`) rather than Flutter's router. The bar contains:
- **Left:** App title
- **Center:** Chip-style nav buttons — Dashboard, Planning, Journal
- **Right:** Add-project button and a compact Pomodoro timer widget

The Planning view is the default destination and shows all projects at once.

## Feature: Pomodoro Timer

The Pomodoro timer follows a standard cycle:
- **25 min** work → **5 min** short break → repeat
- Every 4 work sessions → **15 min** long break instead

Key behaviors:
- **Always visible** in the sidebar with a circular progress ring, phase label, and controls (play/pause/stop/skip)
- **Optionally linked to a task** — start a Pomodoro from any task card's context menu, and the linked task shows a live countdown badge on its card
- **Session persistence** — completed sessions are saved to Hive for daily stats (session count, total focus minutes)
- **State machine** in `PomodoroProvider`: idle → running → (paused) → phase complete → next phase → idle

## Planned Features

- **Health tracking** — Diet, medication, and integration with Apple Health / Google Health / Garmin
- **AI agent integration** — API-connected agents for coaching, feedback, and task delegation
- **End-to-end encryption** — Hive box encryption + key management
- **Mobile** — Flutter's cross-platform support makes this a natural extension
