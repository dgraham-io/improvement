## Shared table names, column conventions, and enum string values for SQLite.
class_name DbConstants
extends RefCounted

const DB_FILE_STEM := "improvement"
## Legacy default when no `user://app_config.json` exists (setup dialog sets the real path).
const DB_PATH_DEFAULT := "user://improvement"
const SCHEMA_VERSION := 5

const TABLE_JOURNAL := "journal_entries"
const TABLE_TASKS := "tasks"
const TABLE_POMODORO := "pomodoro_sessions"
const TABLE_SETTINGS := "app_settings"
const TABLE_TAGS := "tags"
const TABLE_JOURNAL_ENTRY_TAGS := "journal_entry_tags"
const TABLE_TASK_TAGS := "task_tags"

# task.status
const TASK_PENDING := "pending"
const TASK_IN_PROGRESS := "in_progress"
const TASK_DONE := "done"
const TASK_CANCELLED := "cancelled"

static func task_status_values() -> PackedStringArray:
	return PackedStringArray([
		TASK_PENDING,
		TASK_IN_PROGRESS,
		TASK_DONE,
		TASK_CANCELLED,
	])

# pomodoro_sessions.target_type
const TARGET_NONE := "none"
const TARGET_JOURNAL := "journal"
const TARGET_TASK := "task"

static func pomodoro_target_values() -> PackedStringArray:
	return PackedStringArray([TARGET_NONE, TARGET_JOURNAL, TARGET_TASK])

# app_settings keys (stored in app_settings table)
const SETTING_DB_DIRECTORY := "db_directory"
const SETTING_UI_SCALE := "ui_scale"
const SETTING_JOURNAL_SORT_NEWEST_FIRST := "journal_sort_newest_first"
const SETTING_WINDOW_WIDTH := "window_width"
const SETTING_WINDOW_HEIGHT := "window_height"
const SETTING_WINDOW_X := "window_x"
const SETTING_WINDOW_Y := "window_y"
const SETTING_WINDOW_MODE := "window_mode"
const SETTING_TASK_CLEANUP_DAY_KEY := "task_cleanup_day_key"

# Cross-machine heartbeat (for Dropbox / shared folder "another instance open" detection)
const SETTING_OPEN_SESSION := "open_session"
const SETTING_OPEN_MACHINE_PATH := "open_machine_path"
const SETTING_LAST_HEARTBEAT_AT := "last_heartbeat_at"
const OTHER_INSTANCE_RECENT_SEC := 45 * 60  # 45 minutes

# Used to show the "existing database detected" message only once per machine
const SETTING_EXISTING_DB_ACKNOWLEDGED := "existing_db_acknowledged"
