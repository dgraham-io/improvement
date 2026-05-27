## Pure helpers for end-of-day removal of completed tasks.
extends RefCounted


static func today_day_key(now_unix: int) -> String:
	return TimeFormat.local_day_key(now_unix)


## True when cleanup should run for the current local calendar day.
static func should_run_cleanup(last_cleanup_day_key: String, now_unix: int) -> bool:
	var today := today_day_key(now_unix)
	return last_cleanup_day_key != today


## IDs of done tasks last updated before [param today_start_unix] (local midnight today).
static func ids_to_purge(items: Array, today_start_unix: int) -> Array[int]:
	var ids: Array[int] = []
	for item in items:
		if item is TaskItem:
			var task := item as TaskItem
			if task.is_done() and task.updated_at > 0 and task.updated_at < today_start_unix:
				ids.append(task.id)
	return ids
