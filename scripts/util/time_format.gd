## Formats Unix timestamps for UI labels.
class_name TimeFormat
extends RefCounted

const _WEEKDAY_NAMES := [
	"Sunday",
	"Monday",
	"Tuesday",
	"Wednesday",
	"Thursday",
	"Friday",
	"Saturday",
]


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
		return "0m"
	var hours := total_sec / 3600
	var minutes := (total_sec % 3600) / 60
	if hours > 0 and minutes > 0:
		return "%dh %dm" % [hours, minutes]
	if hours > 0:
		return "%dh" % hours
	if minutes > 0:
		return "%dm" % minutes
	return "0m"


## Unix time at local midnight for the calendar day containing [param unix_seconds].
static func local_day_start(unix_seconds: int) -> int:
	if unix_seconds <= 0:
		return 0
	var parts := Time.get_datetime_dict_from_unix_time(unix_seconds)
	parts.hour = 0
	parts.minute = 0
	parts.second = 0
	return int(Time.get_unix_time_from_datetime_dict(parts))


## Stable local date key `YYYY-MM-DD` for grouping timeline days.
static func local_day_key(unix_seconds: int) -> String:
	if unix_seconds <= 0:
		return ""
	var parts := Time.get_datetime_dict_from_unix_time(unix_seconds)
	return "%04d-%02d-%02d" % [parts.year, parts.month, parts.day]


## Primary heading for a daily metrics card (Today, Yesterday, or weekday + date).
static func format_day_heading(day_start_unix: int) -> String:
	if day_start_unix <= 0:
		return ""
	var now := int(Time.get_unix_time_from_system())
	var today_start := local_day_start(now)
	if day_start_unix == today_start:
		return "Today"
	if day_start_unix == today_start - 86400:
		return "Yesterday"
	var parts := Time.get_datetime_dict_from_unix_time(day_start_unix)
	var weekday_index := clampi(int(parts.weekday), 0, _WEEKDAY_NAMES.size() - 1)
	var weekday: String = _WEEKDAY_NAMES[weekday_index]
	return "%s · %04d-%02d-%02d" % [weekday, parts.year, parts.month, parts.day]


## Subtitle line under the day heading (full date when heading is relative).
static func format_day_subtitle(day_start_unix: int) -> String:
	if day_start_unix <= 0:
		return ""
	var now := int(Time.get_unix_time_from_system())
	var today_start := local_day_start(now)
	if day_start_unix == today_start or day_start_unix == today_start - 86400:
		var parts := Time.get_datetime_dict_from_unix_time(day_start_unix)
		return "%04d-%02d-%02d" % [parts.year, parts.month, parts.day]
	return "End of day summary"
