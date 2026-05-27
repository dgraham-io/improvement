-- Improvement — SQLite schema reference (v5)
-- Applied at runtime by scripts/autoload/database.gd (PRAGMA user_version = 5).
-- Database file: <chosen_folder>/improvement.db (see user://app_config.json)

PRAGMA foreign_keys = ON;

-- ---------------------------------------------------------------------------
-- journal_entries — timeline of journal posts (soft delete)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS journal_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    deleted_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_journal_entries_active_created
    ON journal_entries (created_at DESC)
    WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- tasks — task list (optional link to journal_entries)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    title TEXT NOT NULL,
    notes TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'in_progress', 'done', 'cancelled')),
    priority INTEGER NOT NULL DEFAULT 0
        CHECK (priority >= 0 AND priority <= 3),
    due_at INTEGER,
    sort_order INTEGER NOT NULL DEFAULT 0,
    journal_entry_id INTEGER REFERENCES journal_entries (id) ON DELETE SET NULL,
    deleted_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_tasks_active_sort
    ON tasks (sort_order ASC, created_at DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_active_due
    ON tasks (due_at ASC)
    WHERE deleted_at IS NULL AND due_at IS NOT NULL;

-- ---------------------------------------------------------------------------
-- tags — optional labels shared by journal entries and tasks
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL COLLATE NOCASE,
    created_at INTEGER NOT NULL,
    UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS journal_entry_tags (
    entry_id INTEGER NOT NULL REFERENCES journal_entries (id) ON DELETE CASCADE,
    tag_id INTEGER NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
    PRIMARY KEY (entry_id, tag_id)
);

CREATE TABLE IF NOT EXISTS task_tags (
    task_id INTEGER NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
    tag_id INTEGER NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, tag_id)
);

CREATE INDEX IF NOT EXISTS idx_journal_entry_tags_tag
    ON journal_entry_tags (tag_id);

CREATE INDEX IF NOT EXISTS idx_task_tags_tag
    ON task_tags (tag_id);

-- ---------------------------------------------------------------------------
-- pomodoro_sessions — work intervals linked to journal or task (optional)
-- Task work time / completed pomodoro count are aggregated from this table (see docs/data-model.md).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pomodoro_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    planned_duration_sec INTEGER NOT NULL DEFAULT 1500,
    target_type TEXT NOT NULL DEFAULT 'none'
        CHECK (target_type IN ('none', 'journal', 'task')),
    target_id INTEGER,
    completed INTEGER NOT NULL DEFAULT 0
        CHECK (completed IN (0, 1))
);

CREATE INDEX IF NOT EXISTS idx_pomodoro_started
    ON pomodoro_sessions (started_at DESC);

-- ---------------------------------------------------------------------------
-- app_settings — key/value preferences (UI scale, sort order, etc.)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app_settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
