## One journal timeline row; displays entry preview and emits edit.
class_name JournalEntryRow
extends PanelContainer

const _TagDisplay := preload("res://scripts/ui/tag_display.gd")

signal edit_requested(entry: JournalEntry)

var entry: JournalEntry

@onready var _timestamps_label: Label = %TimestampsLabel
@onready var _body_label: Label = %BodyLabel
@onready var _tags_label: Label = %TagsLabel


func setup(journal_entry: JournalEntry, tags: Array = []) -> void:
	entry = journal_entry
	_timestamps_label.text = TimeFormat.format_journal_timestamps(
		journal_entry.created_at,
		journal_entry.updated_at
	)
	var preview := journal_entry.preview_text(480)
	_body_label.text = preview if not preview.is_empty() else "(Empty entry)"
	_body_label.visible = true
	var tag_text := _TagDisplay.format_tag_names(tags)
	_tags_label.text = tag_text
	_tags_label.visible = not tag_text.is_empty()


func _on_edit_pressed() -> void:
	if entry:
		edit_requested.emit(entry)
