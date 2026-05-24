## Shared table names, column conventions, and enum string values for SQLite.
class_name DbConstants
extends RefCounted

const DB_FILE_STEM := "improvement"
## Legacy default when no `user://app_config.json` exists (setup dialog sets the real path).
const DB_PATH_DEFAULT := "user://improvement"
const SCHEMA_VERSION := 4

const TABLE_JOURNAL := "journal_entries"
const TABLE_TODOS := "todos"
const TABLE_POMODORO := "pomodoro_sessions"
const TABLE_SETTINGS := "app_settings"
const TABLE_TAGS := "tags"
const TABLE_JOURNAL_ENTRY_TAGS := "journal_entry_tags"
const TABLE_TODO_TAGS := "todo_tags"

# todo.status
const TODO_PENDING := "pending"
const TODO_IN_PROGRESS := "in_progress"
const TODO_DONE := "done"
const TODO_CANCELLED := "cancelled"

static func todo_status_values() -> PackedStringArray:
	return PackedStringArray([
		TODO_PENDING,
		TODO_IN_PROGRESS,
		TODO_DONE,
		TODO_CANCELLED,
	])

# pomodoro_sessions.target_type
const TARGET_NONE := "none"
const TARGET_JOURNAL := "journal"
const TARGET_TODO := "todo"

static func pomodoro_target_values() -> PackedStringArray:
	return PackedStringArray([TARGET_NONE, TARGET_JOURNAL, TARGET_TODO])

# app_settings keys (stored in app_settings table)
const SETTING_DB_DIRECTORY := "db_directory"
const SETTING_UI_SCALE := "ui_scale"
const SETTING_JOURNAL_SORT_NEWEST_FIRST := "journal_sort_newest_first"
const SETTING_WINDOW_WIDTH := "window_width"
const SETTING_WINDOW_HEIGHT := "window_height"
const SETTING_WINDOW_X := "window_x"
const SETTING_WINDOW_Y := "window_y"
const SETTING_WINDOW_MODE := "window_mode"
const SETTING_TODO_CLEANUP_DAY_KEY := "todo_cleanup_day_key"
