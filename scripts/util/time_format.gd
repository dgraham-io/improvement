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
