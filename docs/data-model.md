# Data model

SQLite **schema version 3** at runtime (`PRAGMA user_version = 3`). Canonical SQL: [`schema.sql`](schema.sql).

**Runtime file:** `<chosen_folder>/improvement.db`.

**Bootstrap (before SQLite opens):** [`scripts/app/app_config.gd`](../scripts/app/app_config.gd) reads/writes `user://app_config.json` with `db_directory` (absolute path). After open, `app_settings.db_directory` mirrors the path for in-app use.

## Entity relationship

```mermaid
erDiagram
	journal_entries ||--o{ todos : "optional journal_entry_id"
	journal_entries ||--o{ pomodoro_sessions : "target"
	todos ||--o{ pomodoro_sessions : "target"

	journal_entries {
		int id PK
		int created_at
		int updated_at
		text body
		int deleted_at
	}

	todos {
		int id PK
		int created_at
		int updated_at
		text title
		text notes
		text status
		int priority
		int due_at
		int sort_order
		int journal_entry_id FK
		int deleted_at
	}

	pomodoro_sessions {
		int id PK
		int started_at
		int ended_at
		int planned_duration_sec
		text target_type
		int target_id
		int completed
	}

	app_settings {
		text key PK
		text value
	}
```

## Tables

### `journal_entries`

Timeline posts. **Soft delete:** `deleted_at` set to Unix seconds, or `NULL` if active.

| Column | Notes |
|--------|--------|
| `body` | Only text field (v3; legacy `title` removed) |
| `created_at` / `updated_at` | Unix UTC seconds; shown in UI |
| `deleted_at` | NULL = visible |

**Default sort:** `created_at DESC` (newest first), configurable via `app_settings.journal_sort_newest_first`.

### `todos`

Mission list. Optional `journal_entry_id` links to a journal entry.

| Column | Notes |
|--------|--------|
| `status` | `pending`, `in_progress`, `done`, `cancelled` |
| `priority` | `0` none … `3` high (strip color in UI) |
| `due_at` | Unix seconds, NULL if unset |
| `sort_order` | Manual list order |
| `deleted_at` | Soft delete |

**Default sort:** `sort_order ASC`, then `created_at DESC`.

**Pomodoro integration:** Work is stored in `pomodoro_sessions`, not on the row. Starting a timer on a **pending** mission sets `status` to `in_progress`. Rows show **total work time**; tooltip shows **completed pomodoro** count.

### `pomodoro_sessions`

Work intervals for journal or mission targets.

| Column | Notes |
|--------|--------|
| `started_at` / `ended_at` | Unix UTC; `ended_at` NULL while running |
| `planned_duration_sec` | Default **1500** (25 min) |
| `completed` | `1` if timer finished; `0` if stopped early |
| `target_type` | `none`, `journal`, `todo` |
| `target_id` | FK when set |

#### Pomodoro work tracking (computed)

Per todo (`target_type = 'todo'`):

| Metric | Rule |
|--------|------|
| **Completed pomodoros** | `COUNT(*)` where `completed = 1` |
| **Total work time** | `SUM(ended_at - started_at)` for rows with `ended_at` set |

UI replaces the old `P0` label with `TimeFormat.format_work_duration(total_work_sec)`.

**API:** `Database.fetch_todo_pomodoro_work_stats()` / `fetch_todo_pomodoro_work_stats_map()`; `TodoService.get_work_stats()` / `get_work_stats_map()`.

### `app_settings`

| Key | Default | Purpose |
|-----|---------|---------|
| `db_directory` | from setup | Absolute folder containing `improvement.db` |
| `ui_scale` | `1.0` | For future Settings UI (**runtime fixed at 1.0**) |
| `journal_sort_newest_first` | `true` | Timeline direction |
| `window_width`, `window_height`, `window_x`, `window_y`, `window_mode` | — | Desktop window layout (`WindowLayout`) |

## GDScript models

| Resource | Script |
|----------|--------|
| `JournalEntry` | [`scripts/models/journal_entry.gd`](../scripts/models/journal_entry.gd) |
| `TodoItem` | [`scripts/models/todo_item.gd`](../scripts/models/todo_item.gd) |
| `PomodoroSession` | [`scripts/models/pomodoro_session.gd`](../scripts/models/pomodoro_session.gd) |

Factory: `*.from_row(dict)` after SQLite queries via [`db_row.gd`](../scripts/database/db_row.gd).

## Services (autoloads)

| Autoload | Role |
|----------|------|
| `AppSetup` | First-run folder UI (not in DB) |
| `Database` | Connection, migrations, SQL, settings |
| `WindowLayout` | Window bounds → `app_settings` |
| `JournalService` | Journal CRUD + search + signals |
| `TodoService` | Mission CRUD + reorder + work stats + signals |
| `PomodoroService` | Timer + DB sessions + `in_progress` on first mission start |

**Rule:** UI calls **services**, not `Database`, except bootstrap/low-level cases.

### JournalService

- `list_entries(limit, offset)`, `get_entry`, `create_entry`, `save_entry`, `delete_entry`
- `search(query)` — `LIKE` on `body`
- Signals: `entry_created`, `entry_updated`, `entry_deleted`

### TodoService

- `list_todos`, `get_todo`, `create_todo`, `save_todo`, `set_status`, `delete_todo`
- `get_work_stats`, `get_work_stats_map`
- `move_todo_relative_to` (drag reorder)
- Signals: `todo_created`, `todo_updated`, `todo_deleted`, `todo_stats_changed`, `todo_reordered`

### PomodoroService

- `start_for`, `pause`, `resume`, `stop`, `attach_target`
- Signals: `state_changed`, `session_ended`

## Migrations

| Version | Change |
|---------|--------|
| **1** | Initial tables |
| **2** | Remove legacy `mood` (rebuild if present) |
| **3** | Remove `title`; body-only journal entries |
| **4+** | Add `_migrate_to_vN()`; never edit shipped migration SQL in place |

## Not in v1

- Encryption at rest  
- App-level cloud sync (folder sync via Dropbox is a deployment choice)  
- FTS5  
- Attachments / blobs  
