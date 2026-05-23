# Improvement

A journalling app for self improvement, knowledge enhancement, and staying focused on the tasks that matter.

Built with Godot 4.6 — readable typography, scrollable journal and task panes, and local storage via SQLite.

![Improvement — journal composer and mission sidebar](docs/screenshots/Screenshot_20260521_093840.png)

**Architecture:** [docs/architecture.md](docs/architecture.md) · **Data model:** [docs/data-model.md](docs/data-model.md)

## Status

Early prototype with **SQLite-backed** journal and todo lists (create, edit, delete, checkbox done state).

| Area | Status |
|------|--------|
| Split journal / todo layout | Shipped |
| Journal list from SQLite | Shipped |
| Todo list from SQLite | Shipped |
| Create / edit / delete (dialogs) | Shipped |
| Theme + Roboto font | Shipped |
| UI scale (`content_scale_factor`) | Fixed at **1.0** (settings adjustment planned) |
| SQLite schema + migrations | Shipped (`user://improvement.db`) |
| `JournalService` / `TodoService` | Shipped |
| Encryption | Planned |
| Pomodoro timer UI | Shipped (journal + top mission; todo work time on rows) |
| Dropbox / iCloud sync | Planned |

## Features

### Shipped

- Two-pane UI: journal timeline (left) and task list (right), separated by a draggable split.
- Lists loaded from `user://improvement.db` via **JournalService** / **TodoService**.
- **+ New entry** / **+ New todo**; inline mission editor; row **Edit** / **Delete**; todo checkbox marks done.
- **Pomodoro timers** on journal composer and top mission; starting a mission timer sets status to **in progress** and records work time on the row (completed pomodoro count + elapsed time).
- Global theme ([`assets/themes/improvement_theme.tres`](assets/themes/improvement_theme.tres)) with Roboto at 20px base size.
- UI scale fixed at **1.0** (`content_scale_factor`); user-adjustable scale planned in Settings.

### Planned

- Journal entries that form a timeline.
- Task list with focus on what matters today.
- Pomodoro on arbitrary todo rows (today: top-of-list mission timer only).
- Encrypted, indexed local storage.
- Dropbox / iCloud storage.

## Requirements

- [Godot Engine **4.6.x**](https://godotengine.org/download) (project targets 4.6; developed with 4.6.2).
- **Desktop** for day-to-day development (Linux, macOS, or Windows). The project lists the Mobile feature tag for future mobile exports; mobile is not the current focus.
- **godot-sqlite** addon under [`addons/godot-sqlite/`](addons/godot-sqlite/); accessed only via the [`Database`](scripts/autoload/database.gd) autoload.

## Getting started

1. Clone the repository and open the project folder in Godot (**Project → Import** if needed, then select [`project.godot`](project.godot)).
2. Confirm the main scene: **Project → Project Settings → Application → Run → Main Scene** should be [`res://scenes/main.tscn`](scenes/main.tscn).
3. Press **F5** (or **Project → Run Project**) to run.
4. On first run, the **setup dialog** asks for a folder (e.g. under **Dropbox**); `improvement.db` is created there. The path is stored in `user://app_config.json` (Godot app user data, not inside the DB).

**Reset setup (testing):** `godot --path . --headless -s res://scripts/tools/reset_app_data.gd` — or delete `%APPDATA%\Godot\app_userdata\Improvement\` on Windows.

### Running in a resizable window (recommended for layout testing)

Godot 4.6 often runs the game **embedded** in the editor by default, which does not behave like a normal OS window.

1. Open the **Game** workspace tab at the top of the editor.
2. In the Game toolbar menu, turn **off** **Embed Game on Next Play**.
3. Or set **Editor → Editor Settings → Run → Window Placement → Game Embed Mode** to **Disabled**.
4. Press **F5** again and resize the standalone game window.

Embedded **Stretch to fit** only affects the in-editor preview; it does not replace proper Control layout or a standalone window for testing.

### UI scale

Runtime scale is **1.0** on all platforms ([`scenes/main.gd`](scenes/main.gd)). **TODO:** add a Settings control to read/write `app_settings.ui_scale` and apply `content_scale_factor` (see roadmap).

## Project structure

```
improvement/
├── project.godot
├── README.md
├── docs/
│   ├── architecture.md
│   ├── data-model.md
│   └── schema.sql
├── scenes/
│   ├── main.tscn
│   └── main.gd
├── scripts/
│   ├── autoload/          # Database, JournalService, TodoService
│   ├── database/
│   └── models/
├── assets/{fonts,themes,icons}/
└── addons/godot-sqlite/
```

Godot generates `.godot/` and `*.import` files locally; they are ignored by git (see [`.gitignore`](.gitignore)). Local SQLite test databases (`*.db`, `data/`, `user_data/`) are ignored; the **godot-sqlite** addon under `addons/` remains tracked.

### Conventions

- **Scenes** live under `scenes/`. Scene-specific scripts sit beside their `.tscn` file (e.g. `scenes/main.gd`).
- **Shared assets** (fonts, themes, icons) live under `assets/`.
- **Third-party plugins** live under `addons/` and are enabled in `project.godot`.

Next UI step: `scenes/journal/journal_entry_row.tscn` and bind lists to `JournalService.list_entries()` / `TodoService.list_todos()`.

## Development notes

- **Main scene UID** is `uid://d4bhhy4ln2jhd`; keep this stable if you rename files so run settings keep working.
- **Database:** `user://improvement.db` — use `JournalService` / `TodoService`, not raw SQL in scenes.
- **Debug run:** console prints journal/todo counts after DB init when running a debug build.
- **Rendering:** `renderer/rendering_method="mobile"` is set for lightweight UI; adjust in **Project Settings → Rendering** if desktop-specific issues appear.

## Roadmap

1. ~~SQLite schema + services~~ (done — see [docs/data-model.md](docs/data-model.md)).
2. ~~Journal/todo UI bound to services~~ (done).
3. User preferences UI (`app_settings`: sort, theme) — **TODO:** UI scale slider bound to `ui_scale` / `content_scale_factor`.
4. ~~Pomodoro timer linked to active entry or task~~ (partial — see [docs/data-model.md](docs/data-model.md)#pomodoro-work-tracking).
5. Encryption at rest for the local database.
6. Optional sync (Dropbox / iCloud) behind a clear export/backup flow.

## Third-party licenses

| Component | Location | License |
|-----------|----------|---------|
| [Godot SQLite](https://github.com/godot-sqlite/godot-sqlite) | [`addons/godot-sqlite/`](addons/godot-sqlite/) | [MIT](addons/godot-sqlite/LICENSE.md) |
| Roboto font | [`assets/fonts/`](assets/fonts/) | [Apache License 2.0](https://fonts.google.com/specimen/Roboto/license) (Google Fonts) |

## License

**Improvement** (application code and original assets in this repository, excluding third-party components listed above) is licensed under the [MIT License](LICENSE).

Copyright (c) 2026 David Graham
