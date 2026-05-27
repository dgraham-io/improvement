## Aggregated pomodoro focus for one local calendar day.
class_name DailyWorkStats
extends RefCounted

const EMPTY := {
	"total_work_sec": 0,
	"completed_pomodoros": 0,
	"session_count": 0,
	"journal_work_sec": 0,
	"task_work_sec": 0,
	"hourly_work_sec": [],
}

var day_start_unix: int = 0
var total_work_sec: int = 0
var completed_pomodoros: int = 0
var session_count: int = 0
var journal_work_sec: int = 0
var task_work_sec: int = 0
var hourly_work_sec: PackedInt32Array = PackedInt32Array()


static func from_dictionary(day_start: int, data: Dictionary):
	var stats := new()
	stats.day_start_unix = day_start
	stats.total_work_sec = int(data.get("total_work_sec", 0))
	stats.completed_pomodoros = int(data.get("completed_pomodoros", 0))
	stats.session_count = int(data.get("session_count", 0))
	stats.journal_work_sec = int(data.get("journal_work_sec", 0))
	stats.task_work_sec = int(data.get("task_work_sec", 0))
	var hourly: Variant = data.get("hourly_work_sec", [])
	if hourly is PackedInt32Array:
		stats.hourly_work_sec = hourly
	elif hourly is Array:
		for value in hourly:
			stats.hourly_work_sec.append(int(value))
	return stats


func has_work() -> bool:
	return total_work_sec > 0 or session_count > 0
