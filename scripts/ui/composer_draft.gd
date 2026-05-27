## Serializable in-memory drafts for inline journal/task composers.
class_name ComposerDraft
extends RefCounted


static func journal_from_fields(
	body: String,
	tag_ids: Array,
	editing_entry_id: int,
	timestamps_text: String,
	save_button_text: String,
	delete_visible: bool
) -> Dictionary:
	return {
		"body": body,
		"tag_ids": tag_ids.duplicate(),
		"editing_entry_id": editing_entry_id,
		"timestamps_text": timestamps_text,
		"save_button_text": save_button_text,
		"delete_visible": delete_visible,
	}


static func task_from_fields(
	title: String,
	notes: String,
	tag_ids: Array,
	status: String,
	editing_task_id: int,
	save_button_text: String,
	delete_visible: bool
) -> Dictionary:
	return {
		"title": title,
		"notes": notes,
		"tag_ids": tag_ids.duplicate(),
		"status": status,
		"editing_task_id": editing_task_id,
		"save_button_text": save_button_text,
		"delete_visible": delete_visible,
	}


static func tags_from_ids(tag_ids: Array) -> Array:
	var tags: Array = []
	for raw_id in tag_ids:
		var tag_id := int(raw_id)
		if tag_id <= 0:
			continue
		var tag := TagService.get_tag(tag_id)
		if tag != null:
			tags.append(tag)
	return tags
