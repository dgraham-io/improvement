## One journal timeline row; displays entry preview and emits edit/delete.
class_name JournalEntryRow
extends PanelContainer

signal edit_requested(entry: JournalEntry)
signal delete_requested(entry_id: int)

var entry: JournalEntry

@onready var _timestamps_label: Label = %TimestampsLabel
@onready var _body_label: Label = %BodyLabel


func setup(journal_entry: JournalEntry) -> void:
	entry = journal_entry
	_timestamps_label.text = TimeFormat.format_journal_timestamps(
		journal_entry.created_at,
		journal_entry.updated_at
	)
	var preview := journal_entry.preview_text(480)
	_body_label.text = preview if not preview.is_empty() else "(Empty entry)"
	_body_label.visible = true


func _on_edit_pressed() -> void:
	if entry:
		edit_requested.emit(entry)


func _on_delete_pressed() -> void:
	if entry:
		delete_requested.emit(entry.id)
