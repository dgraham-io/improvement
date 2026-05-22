# Data model

SQLite **schema version 1** (`PRAGMA user_version = 1`). Canonical SQL: [`schema.sql`](schema.sql).

**Runtime file:** `user://improvement.db` (see [`scripts/autoload/database.gd`](../scripts/autoload/database.gd)).

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

Timeline posts. **Soft delete:** `deleted_at` Unix seconds, or `NULL` if active.

| Column | Type | Notes |
|--------|------|--------|
| `id` | INTEGER PK | Auto-increment |
| `created_at` | INTEGER | Unix UTC seconds |
| `updated_at` | INTEGER | Unix UTC seconds |
| `body` | TEXT | Entry content (only text field) |
| `created_at` / `updated_at` | INTEGER | Unix UTC seconds; shown in UI |
| `deleted_at` | INTEGER | NULL = visible |

**Default sort:** `created_at DESC` (newest first), configurable via `app_settings.journal_sort_newest_first`.

### `todos`

Task list. Optional `journal_entry_id` links a task to a journal entry.

| Column | Type | Notes |
|--------|------|--------|
| `status` | TEXT | `pending`, `in_progress`, `done`, `cancelled` |
| `priority` | INTEGER | `0` none … `3` high |
| `due_at` | INTEGER | Unix seconds, NULL if unset |
| `sort_order` | INTEGER | Manual ordering within list |
| `deleted_at` | INTEGER | Soft delete |

**Default sort:** `sort_order ASC`, then `created_at DESC`.

### `pomodoro_sessions`

Work intervals for a future timer UI. `target_type` + `target_id` reference journal or todo when set.

| `target_type` | Meaning |
|---------------|---------|
| `none` | Untethered session |
| `journal` | `target_id` → `journal_entries.id` |
| `todo` | `target_id` → `todos.id` |

### `app_settings`

Key/value store in the same database (no separate `settings.cfg` in v1).

| Key | Default | Purpose |
|-----|---------|---------|
| `ui_scale` | `1.5` | Applied to `content_scale_factor` on startup |
| `journal_sort_newest_first` | `true` | Timeline direction |

## GDScript models

| Resource | Script | Maps to |
|----------|--------|---------|
| `JournalEntry` | [`scripts/models/journal_entry.gd`](../scripts/models/journal_entry.gd) | `journal_entries` |
| `TodoItem` | [`scripts/models/todo_item.gd`](../scripts/models/todo_item.gd) | `todos` |
| `PomodoroSession` | [`scripts/models/pomodoro_session.gd`](../scripts/models/pomodoro_session.gd) | `pomodoro_sessions` |

Factory: `JournalEntry.from_row(dict)` / `TodoItem.from_row(dict)` after SQLite queries.

## Services (autoloads)

| Autoload | Script | Role |
|----------|--------|------|
| `Database` | [`scripts/autoload/database.gd`](../scripts/autoload/database.gd) | Connection, migrations, SQL, settings |
| `JournalService` | [`scripts/autoload/journal_service.gd`](../scripts/autoload/journal_service.gd) | Journal CRUD + search + signals |
| `TodoService` | [`scripts/autoload/todo_service.gd`](../scripts/autoload/todo_service.gd) | Todo CRUD + signals |

**Rule:** UI and gameplay code call **services**, not `Database`, except for rare low-level needs.

### JournalService API

- `list_entries(limit, offset)` → `Array[JournalEntry]`
- `get_entry(id)`, `create_entry(body)`, `save_entry(entry)`, `delete_entry(id)` (soft)
- `search(query)` — `LIKE` on body (FTS5 deferred)
- Signals: `entry_created`, `entry_updated`, `entry_deleted`

### TodoService API

- `list_todos()`, `get_todo(id)`, `create_todo(...)`, `save_todo(item)`, `set_status(id, status)`, `delete_todo(id)`
- Signals: `todo_created`, `todo_updated`, `todo_deleted`

## Search (v1)

`LIKE '%query%'` on `body`. **FTS5** virtual table deferred until entry volume warrants it.

## Migrations

- Version tracked with `PRAGMA user_version`.
- v1 creates all tables and indexes (see `Database._migrate_to_v1()`).
- v2 removes legacy `mood` from `journal_entries` via table rebuild (skipped if never present).
- v3 removes `title`; entries are body-only.
- v4+ will add incremental `_migrate_to_vN()` functions; never edit shipped migration SQL in place.

## Seed data

On first run (zero journal rows), `Database` inserts two sample journal entries and two todos for development.

## Not in v1

- Encryption at rest  
- Cloud sync  
- FTS5  
- Attachments / blobs  
- Pomodoro UI (persistence API exists on `Database`)
