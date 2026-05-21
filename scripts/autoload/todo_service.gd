## Autoload: task list CRUD. Emits signals for UI refresh.
extends Node

signal todo_created(item: TodoItem)
signal todo_updated(item: TodoItem)
signal todo_deleted(todo_id: int)


func _ready() -> void:
	if not Database.is_ready:
		await Database.ready_changed


func get_todo_count() -> int:
	return Database.count_todos()


func list_todos() -> Array[TodoItem]:
	var rows := Database.fetch_todos()
	var result: Array[TodoItem] = []
	for row in rows:
		result.append(TodoItem.from_row(row))
	return result


func get_todo(todo_id: int) -> TodoItem:
	var row := Database.fetch_todo_by_id(todo_id)
	if row.is_empty():
		return null
	return TodoItem.from_row(row)


func create_todo(
	title: String,
	notes: String = "",
	status: String = DbConstants.TODO_PENDING,
	priority: int = 0,
	due_at: int = 0,
	journal_entry_id: int = 0
) -> TodoItem:
	if not DbConstants.todo_status_values().has(status):
		status = DbConstants.TODO_PENDING
	var id := Database.insert_todo(title, notes, status, priority, due_at, journal_entry_id)
	if id < 0:
		return null
	var item := get_todo(id)
	if item:
		todo_created.emit(item)
	return item


func save_todo(item: TodoItem) -> bool:
	if item.id <= 0:
		return false
	if not DbConstants.todo_status_values().has(item.status):
		item.status = DbConstants.TODO_PENDING
	if not Database.update_todo(item):
		return false
	var updated := get_todo(item.id)
	if updated:
		todo_updated.emit(updated)
	return true


func set_status(todo_id: int, status: String) -> bool:
	var item := get_todo(todo_id)
	if item == null:
		return false
	item.status = status
	return save_todo(item)


func delete_todo(todo_id: int) -> bool:
	if not Database.soft_delete_todo(todo_id):
		return false
	todo_deleted.emit(todo_id)
	return true
