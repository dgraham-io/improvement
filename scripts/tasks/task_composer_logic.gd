## Pure save logic for the inline task editor (no UI nodes).
extends RefCounted


class SaveResult:
	var ok: bool = false
	var created: bool = false
	var created_item: TodoItem = null


static func try_save(
	editing_todo: TodoItem,
	title: String,
	notes: String,
	status: String
) -> SaveResult:
	var result := SaveResult.new()
	var todo_title := title.strip_edges()
	if todo_title.is_empty():
		return result
	var todo_notes := notes.strip_edges()
	if not DbConstants.task_status_values().has(status):
		status = DbConstants.TASK_PENDING
	if editing_todo == null:
		var created := TaskService.create_todo(todo_title, todo_notes, status)
		if created:
			result.ok = true
			result.created = true
			result.created_item = created
		return result
	editing_todo.title = todo_title
	editing_todo.notes = todo_notes
	editing_todo.status = status
	result.ok = TaskService.save_todo(editing_todo)
	return result
