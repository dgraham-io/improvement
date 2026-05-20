# Improvement

A journalling app for self improvement, knowledge enhancement, and staying focused on the tasks that matter.

Calm, accessible UI built with Godot 4.6 — readable typography, scrollable journal and task panes, and local storage planned via SQLite.

## Status

Early prototype. The main window layout exists; persistence, timers, and cloud sync are not implemented yet.

| Area | Status |
|------|--------|
| Split journal / todo layout | Shipped (UI shell) |
| Scrollable list containers | Shipped (empty; rows not wired) |
| Theme + Roboto font | Shipped |
| UI scale (`content_scale_factor`) | Shipped |
| Journal entry rows + timeline data | Planned |
| Task list data + editing | Planned |
| SQLite storage | Planned (addon installed) |
| Encryption | Planned |
| Pomodoro timer | Planned |
| Dropbox / iCloud sync | Planned |

## Features

### Shipped

- Two-pane UI: journal timeline (left) and task list (right), separated by a draggable split.
- `ScrollContainer` + `VBoxContainer` structure ready for dynamic entry rows.
- Global theme ([`assets/themes/improvement_theme.tres`](assets/themes/improvement_theme.tres)) with Roboto at 20px base size.
- Optional UI scale via `scale_factor` on the main scene (default **1.5** in the editor).

### Planned

- Journal entries that form a timeline.
- Task list with focus on what matters today.
- Pomodoro timer for journal entries and tasks.
- Encrypted, indexed local storage.
- Dropbox / iCloud storage.

## Requirements

- [Godot Engine **4.6.x**](https://godotengine.org/download) (project targets 4.6; developed with 4.6.2).
- **Desktop** for day-to-day development (Linux, macOS, or Windows). The project lists the Mobile feature tag for future mobile exports; mobile is not the current focus.
- **godot-sqlite** addon is included under [`addons/godot-sqlite/`](addons/godot-sqlite/) and enabled in project settings. No application code uses it yet.

## Getting started

1. Clone the repository and open the project folder in Godot (**Project → Import** if needed, then select [`project.godot`](project.godot)).
2. Confirm the main scene: **Project → Project Settings → Application → Run → Main Scene** should be [`res://scenes/main.tscn`](scenes/main.tscn).
3. Press **F5** (or **Project → Run Project**) to run.

### Running in a resizable window (recommended for layout testing)

Godot 4.6 often runs the game **embedded** in the editor by default, which does not behave like a normal OS window.

1. Open the **Game** workspace tab at the top of the editor.
2. In the Game toolbar menu, turn **off** **Embed Game on Next Play**.
3. Or set **Editor → Editor Settings → Run → Window Placement → Game Embed Mode** to **Disabled**.
4. Press **F5** again and resize the standalone game window.

Embedded **Stretch to fit** only affects the in-editor preview; it does not replace proper Control layout or a standalone window for testing.

### Adjusting UI scale

On the root **Main** node in [`scenes/main.tscn`](scenes/main.tscn), change the exported **Scale Factor** (applied in [`scenes/main.gd`](scenes/main.gd) as `content_scale_factor`). Use this for readability on HiDPI displays until a dedicated settings screen exists.

## Project structure

```
improvement/
├── project.godot          # Engine config, plugins, main scene UID
├── README.md
├── scenes/
│   ├── main.tscn          # Main UI (split journal / todo)
│   └── main.gd            # Root script (UI scale on ready)
├── assets/
│   ├── fonts/             # Roboto (Regular, Bold, Italic)
│   ├── themes/
│   │   └── improvement_theme.tres
│   └── icons/
│       └── icon.svg       # Application icon
└── addons/
    └── godot-sqlite/      # SQLite GDExtension (MIT)
```

Godot generates `.godot/` and `*.import` files locally; they are ignored by git (see [`.gitignore`](.gitignore)). Local SQLite test databases (`*.db`, `data/`, `user_data/`) are ignored; the **godot-sqlite** addon under `addons/` remains tracked.

### Conventions

- **Scenes** live under `scenes/`. Scene-specific scripts sit beside their `.tscn` file (e.g. `scenes/main.gd`).
- **Shared assets** (fonts, themes, icons) live under `assets/`.
- **Third-party plugins** live under `addons/` and are enabled in `project.godot`.

As the app grows, expect `scripts/` for autoloads (database, settings) and row scenes such as `scenes/journal/journal_entry_row.tscn`.

## Development notes

- **Main scene UID** is `uid://d4bhhy4ln2jhd`; keep this stable if you rename files so run settings keep working.
- **Database (future):** store SQLite files under `user://`, not `res://`. Wire access through an autoload rather than calling the addon from many scenes.
- **List rows (future):** instantiate entry scenes into the journal and todo `VBoxContainer` nodes inside each `ScrollContainer`.
- **Rendering:** `renderer/rendering_method="mobile"` is set for lightweight UI; adjust in **Project Settings → Rendering** if desktop-specific issues appear.

## Roadmap

1. Journal entry row scene + populate timeline from SQLite.
2. Todo row scene + CRUD and persistence.
3. User preferences (font size, UI scale, margins) without editing the scene export.
4. Pomodoro timer linked to active entry or task.
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
