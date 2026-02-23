# Improvement

An AI-powered personal improvement app for focus, motivation, and health. Track projects and tasks on a Kanban-style planning board, keep a daily journal, and stay focused with a built-in Pomodoro timer.

## Download

**macOS:** [Download the latest macOS build](https://nightly.link/dgraham-io/improvement/workflows/build-macos.yml/main/improvement-macos.zip)

**Windows:** [Download the latest Windows build](https://nightly.link/dgraham-io/improvement/workflows/build-windows.yml/main/improvement-windows.zip)

## Features

- **Planning Board** — All projects displayed in a single view with swimlane rows and Done / In Progress / To Do columns. Drag and drop tasks between statuses.
- **Journal** — Infinitely scrollable daily journal with day separators and inline editing.
- **Pomodoro Timer** — 25/5/15 minute focus timer in the top bar, optionally linked to tasks with a live countdown badge on the card.
- **Local Storage** — All data persisted locally with Hive (encryption-ready for future E2E support).

## Building from Source

Requires [Flutter](https://docs.flutter.dev/get-started/install) (stable channel).

```bash
# Install dependencies
flutter pub get

# Run in development
flutter run -d macos    # or -d windows, -d linux

# Build a release binary
flutter build macos --release
flutter build windows --release
flutter build linux --release
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for details on the project structure, data flow, and design decisions.
