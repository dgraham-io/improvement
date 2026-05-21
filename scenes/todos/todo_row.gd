## One todo row; checkbox toggles done state, emits edit/delete.
class_name TodoRow
extends PanelContainer

signal edit_requested(item: TodoItem)
signal delete_requested(todo_id: int)

var item: TodoItem

@onready var _check_box: CheckBox = %DoneCheckBox
@onready var _title_label: Label = %TitleLabel
@onready var _notes_label: Label = %NotesLabel


func setup(todo_item: TodoItem) -> void:
	item = todo_item
	_check_box.set_block_signals(true)
	_check_box.button_pressed = todo_item.is_done()
	_check_box.set_block_signals(false)
	_title_label.text = todo_item.title
	_notes_label.text = todo_item.notes.strip_edges()
	_notes_label.visible = not _notes_label.text.is_empty()
	_apply_done_style(todo_item.is_done())


func _apply_done_style(done: bool) -> void:
	if done:
		_title_label.modulate = Color(0.55, 0.55, 0.55, 1.0)
	else:
		_title_label.modulate = Color(1, 1, 1, 1)


func _on_done_toggled(toggled_on: bool) -> void:
	if item == null:
		return
	var new_status := DbConstants.TODO_DONE if toggled_on else DbConstants.TODO_PENDING
	if item.status == new_status:
		return
	item.status = new_status
	_apply_done_style(toggled_on)
	TodoService.save_todo(item)


func _on_edit_pressed() -> void:
	if item:
		edit_requested.emit(item)


func _on_delete_pressed() -> void:
	if item:
		delete_requested.emit(item.id)
