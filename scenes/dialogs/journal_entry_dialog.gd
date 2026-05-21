## Modal editor for creating or updating a journal entry (body only).
class_name JournalEntryDialog
extends AcceptDialog

signal saved(entry: JournalEntry)
signal deleted(entry_id: int)

var _editing_entry: JournalEntry = null

@onready var _timestamps_label: Label = %TimestampsLabel
@onready var _body_field: TextEdit = %BodyField
@onready var _delete_button: Button = %DeleteButton


func open_create() -> void:
	_editing_entry = null
	title = "New journal entry"
	_delete_button.visible = false
	_timestamps_label.text = "Timestamps are set when you save."
	_body_field.text = ""
	popup_centered(Vector2i(720, 480))


func open_edit(entry: JournalEntry) -> void:
	_editing_entry = entry
	title = "Edit journal entry"
	_delete_button.visible = true
	_timestamps_label.text = TimeFormat.format_journal_timestamps(entry.created_at, entry.updated_at)
	_body_field.text = entry.body
	popup_centered(Vector2i(720, 480))


func _on_confirmed() -> void:
	var entry_body := _body_field.text.strip_edges()
	if entry_body.is_empty():
		return
	if _editing_entry == null:
		var created := JournalService.create_entry(entry_body)
		if created:
			saved.emit(created)
	else:
		_editing_entry.body = entry_body
		if JournalService.save_entry(_editing_entry):
			saved.emit(_editing_entry)


func _on_delete_pressed() -> void:
	if _editing_entry == null:
		return
	var entry_id := _editing_entry.id
	if JournalService.delete_entry(entry_id):
		deleted.emit(entry_id)
		hide()
