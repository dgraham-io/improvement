## Autoload: tag catalog and assignments for journal entries and todos.
extends Node

signal entry_tags_changed(entry_id: int)
signal todo_tags_changed(todo_id: int)


func _ready() -> void:
	if not Database.is_ready:
		await Database.ready_changed
	if not Database.is_ready:
		return


func list_tags() -> Array[Tag]:
	if not Database.is_ready:
		return []
	var rows := Database.fetch_all_tags()
	var result: Array[Tag] = []
	for row in rows:
		result.append(Tag.from_row(row))
	return result


func find_or_create(name: String) -> Tag:
	if not Database.is_ready:
		return null
	var normalized := TagNames.normalize(name)
	if normalized.is_empty():
		return null
	var existing := Database.fetch_tag_by_name(normalized)
	if not existing.is_empty():
		return Tag.from_row(existing)
	var tag_id := Database.insert_tag(normalized)
	if tag_id < 0:
		return null
	return get_tag(tag_id)


func get_tag(tag_id: int) -> Tag:
	if not Database.is_ready:
		return null
	var row := Database.fetch_tag_by_id(tag_id)
	if row.is_empty():
		return null
	return Tag.from_row(row)


func get_tags_for_entry(entry_id: int) -> Array[Tag]:
	var rows := Database.fetch_tags_for_journal_entry(entry_id)
	var result: Array[Tag] = []
	for row in rows:
		result.append(Tag.from_row(row))
	return result


func get_tags_for_todo(todo_id: int) -> Array[Tag]:
	var rows := Database.fetch_tags_for_todo(todo_id)
	var result: Array[Tag] = []
	for row in rows:
		result.append(Tag.from_row(row))
	return result


func get_entry_tags_map() -> Dictionary:
	return Database.fetch_journal_entry_tags_map()


func get_todo_tags_map() -> Dictionary:
	return Database.fetch_todo_tags_map()


func set_entry_tags(entry_id: int, tag_ids: Array) -> bool:
	if entry_id <= 0:
		return false
	if not Database.set_journal_entry_tags(entry_id, _sanitize_tag_ids(tag_ids)):
		return false
	entry_tags_changed.emit(entry_id)
	return true


func set_todo_tags(todo_id: int, tag_ids: Array) -> bool:
	if todo_id <= 0:
		return false
	if not Database.set_todo_tags(todo_id, _sanitize_tag_ids(tag_ids)):
		return false
	todo_tags_changed.emit(todo_id)
	return true


func _sanitize_tag_ids(tag_ids: Array) -> Array[int]:
	var seen: Dictionary = {}
	var result: Array[int] = []
	for raw_id in tag_ids:
		var tag_id := int(raw_id)
		if tag_id <= 0 or seen.has(tag_id):
			continue
		seen[tag_id] = true
		result.append(tag_id)
	return result
