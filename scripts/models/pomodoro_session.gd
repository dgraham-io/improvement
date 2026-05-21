## Domain model for one Pomodoro work session (maps to pomodoro_sessions).
class_name PomodoroSession
extends Resource

const _DbRow := preload("res://scripts/database/db_row.gd")
const DEFAULT_DURATION_SEC := 25 * 60

@export var id: int = 0
@export var started_at: int = 0
@export var ended_at: int = 0
@export var planned_duration_sec: int = DEFAULT_DURATION_SEC
@export var target_type: String = DbConstants.TARGET_NONE
@export var target_id: int = 0
@export var completed: bool = false


static func from_row(row: Dictionary) -> PomodoroSession:
	var session := PomodoroSession.new()
	session.id = _DbRow.int_value(row.get("id"))
	session.started_at = _DbRow.int_value(row.get("started_at"))
	session.ended_at = _DbRow.int_value(row.get("ended_at"))
	session.planned_duration_sec = _DbRow.int_value(row.get("planned_duration_sec"), DEFAULT_DURATION_SEC)
	session.target_type = _DbRow.string_value(row.get("target_type"), DbConstants.TARGET_NONE)
	session.target_id = _DbRow.int_value(row.get("target_id"))
	session.completed = _DbRow.int_value(row.get("completed")) != 0
	return session
