## Modal editor for creating or updating a todo.
class_name TodoItemDialog
extends AcceptDialog

signal saved(item: TodoItem)
signal deleted(todo_id: int)

var _editing_item: TodoItem = null

@onready var _title_field: LineEdit = %TitleField
@onready var _notes_field: TextEdit = %NotesField
@onready var _status_option: OptionButton = %StatusOption
@onready var _delete_button: Button = %DeleteButton


func _ready() -> void:
	_status_option.clear()
	_status_option.add_item("Pending", 0)
	_status_option.set_item_metadata(0, DbConstants.TODO_PENDING)
	_status_option.add_item("In progress", 1)
	_status_option.set_item_metadata(1, DbConstants.TODO_IN_PROGRESS)
	_status_option.add_item("Done", 2)
	_status_option.set_item_metadata(2, DbConstants.TODO_DONE)
	_status_option.add_item("Cancelled", 3)
	_status_option.set_item_metadata(3, DbConstants.TODO_CANCELLED)


func open_create() -> void:
	_editing_item = null
	title = "New todo"
	_delete_button.visible = false
	_title_field.text = ""
	_notes_field.text = ""
	_status_option.select(0)
	popup_centered(Vector2i(560, 400))


func open_edit(item: TodoItem) -> void:
	_editing_item = item
	title = "Edit todo"
	_delete_button.visible = true
	_title_field.text = item.title
	_notes_field.text = item.notes
	_select_status(item.status)
	popup_centered(Vector2i(560, 400))


func _select_status(status: String) -> void:
	for i in _status_option.item_count:
		if _status_option.get_item_metadata(i) == status:
			_status_option.select(i)
			return
	_status_option.select(0)


func _selected_status() -> String:
	var idx := _status_option.selected
	return str(_status_option.get_item_metadata(idx))


func _on_confirmed() -> void:
	var todo_title := _title_field.text.strip_edges()
	if todo_title.is_empty():
		return
	var todo_notes := _notes_field.text.strip_edges()
	var todo_status := _selected_status()
	if _editing_item == null:
		var created := TodoService.create_todo(todo_title, todo_notes, todo_status)
		if created:
			saved.emit(created)
	else:
		_editing_item.title = todo_title
		_editing_item.notes = todo_notes
		_editing_item.status = todo_status
		if TodoService.save_todo(_editing_item):
			saved.emit(_editing_item)


func _on_delete_pressed() -> void:
	if _editing_item == null:
		return
	var todo_id := _editing_item.id
	if TodoService.delete_todo(todo_id):
		deleted.emit(todo_id)
		hide()
