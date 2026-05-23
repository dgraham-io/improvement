## Groups journal entries into consecutive local-day blocks (list order preserved).
class_name JournalTimelineLayout
extends RefCounted


static func build_day_blocks(entries: Array) -> Array:
	var blocks: Array = []
	if entries.is_empty():
		return blocks
	var index := 0
	while index < entries.size():
		var entry: JournalEntry = entries[index]
		var day_start := TimeFormat.local_day_start(entry.created_at)
		var day_entries: Array[JournalEntry] = []
		while index < entries.size():
			var candidate: JournalEntry = entries[index]
			if TimeFormat.local_day_start(candidate.created_at) != day_start:
				break
			day_entries.append(candidate)
			index += 1
		blocks.append({"day_start": day_start, "entries": day_entries})
	return blocks
