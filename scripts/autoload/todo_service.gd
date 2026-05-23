## Autoload: task list CRUD. Emits signals for UI refresh.
extends Node

signal todo_created(item: TodoItem)
signal todo_updated(item: TodoItem)
signal todo_deleted(todo_id: int)
## Emitted when a todo is saved without todo_updated (e.g. checkbox toggle) so UI can refresh counts.
signal todo_stats_changed
signal todo_reordered


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


## First mission in list order (top of the task list).
func get_top_todo() -> TodoItem:
	var items := list_todos()
	if items.is_empty():
		return null
	return items[0]


func get_todo(todo_id: int) -> TodoItem:
	var row := Database.fetch_todo_by_id(todo_id)
	if row.is_empty():
		return null
	return TodoItem.from_row(row)


func get_work_stats_map() -> Dictionary:
	return Database.fetch_todo_pomodoro_work_stats_map()


func get_work_stats(todo_id: int) -> Dictionary:
	return Database.fetch_todo_pomodoro_work_stats(todo_id)


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


func save_todo(item: TodoItem, emit_updated: bool = true) -> bool:
	if item.id <= 0:
		return false
	if not DbConstants.todo_status_values().has(item.status):
		item.status = DbConstants.TODO_PENDING
	if not Database.update_todo(item):
		return false
	if emit_updated:
		var updated := get_todo(item.id)
		if updated:
			todo_updated.emit(updated)
	else:
		todo_stats_changed.emit()
	return true


func set_status(todo_id: int, status: String, emit_updated: bool = true) -> bool:
	var item := get_todo(todo_id)
	if item == null:
		return false
	item.status = status
	return save_todo(item, emit_updated)


func move_todo_relative_to(dragged_id: int, target_id: int, insert_before: bool) -> bool:
	var items := list_todos()
	var from_idx := -1
	var target_idx := -1
	for i in items.size():
		if items[i].id == dragged_id:
			from_idx = i
		if items[i].id == target_id:
			target_idx = i
	if from_idx < 0 or target_idx < 0 or from_idx == target_idx:
		return false
	var moved := items[from_idx]
	items.remove_at(from_idx)
	if from_idx < target_idx:
		target_idx -= 1
	var insert_idx := target_idx if insert_before else target_idx + 1
	insert_idx = clampi(insert_idx, 0, items.size())
	items.insert(insert_idx, moved)
	var changed := false
	for i in items.size():
		if items[i].sort_order != i:
			items[i].sort_order = i
			if not Database.update_todo(items[i]):
				return false
			changed = true
	if changed:
		todo_reordered.emit()
	return true


func delete_todo(todo_id: int) -> bool:
	if not Database.soft_delete_todo(todo_id):
		return false
	todo_deleted.emit(todo_id)
	return true
