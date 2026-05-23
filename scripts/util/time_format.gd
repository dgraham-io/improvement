## Formats Unix timestamps for UI labels.
class_name TimeFormat
extends RefCounted


static func format_timestamp(unix_seconds: int, include_seconds: bool = true) -> String:
	if unix_seconds <= 0:
		return ""
	var dict := Time.get_datetime_dict_from_unix_time(unix_seconds)
	if include_seconds:
		return "%04d-%02d-%02d %02d:%02d:%02d" % [
			dict.year,
			dict.month,
			dict.day,
			dict.hour,
			dict.minute,
			dict.second,
		]
	return "%04d-%02d-%02d %02d:%02d" % [
		dict.year,
		dict.month,
		dict.day,
		dict.hour,
		dict.minute,
	]


## Timestamp line(s) for journal list rows and composer (no "Created"/"Updated" labels).
static func format_journal_timestamps(created_at: int, updated_at: int) -> String:
	var created_text := format_timestamp(created_at)
	if created_text.is_empty():
		return ""
	if updated_at <= 0 or updated_at == created_at:
		return created_text
	return "%s\n%s" % [created_text, format_timestamp(updated_at)]


## Human-readable duration from pomodoro elapsed seconds (e.g. 25m, 1h 15m).
static func format_work_duration(total_sec: int) -> String:
	if total_sec <= 0:
		return ""
	var hours := total_sec / 3600
	var minutes := (total_sec % 3600) / 60
	if hours > 0 and minutes > 0:
		return "%dh %dm" % [hours, minutes]
	if hours > 0:
		return "%dh" % hours
	return "%dm" % maxi(1, minutes)
