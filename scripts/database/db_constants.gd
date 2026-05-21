## Shared table names, column conventions, and enum string values for SQLite.
class_name DbConstants
extends RefCounted

const DB_PATH := "user://improvement"
const SCHEMA_VERSION := 3

const TABLE_JOURNAL := "journal_entries"
const TABLE_TODOS := "todos"
const TABLE_POMODORO := "pomodoro_sessions"
const TABLE_SETTINGS := "app_settings"

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
const SETTING_UI_SCALE := "ui_scale"
const SETTING_JOURNAL_SORT_NEWEST_FIRST := "journal_sort_newest_first"
