## Pure save logic for the inline task editor (no UI nodes).
extends RefCounted


class SaveResult:
	var ok: bool = false
	var created: bool = false
	var created_item: TaskItem = null


static func try_save(
	editing_task: TaskItem,
	title: String,
	notes: String,
	status: String
) -> SaveResult:
	var result := SaveResult.new()
	var task_title := title.strip_edges()
	if task_title.is_empty():
		return result
	var task_notes := notes.strip_edges()
	if not DbConstants.task_status_values().has(status):
		status = DbConstants.TASK_PENDING
	if editing_task == null:
		var created := TaskService.create_task(task_title, task_notes, status)
		if created:
			result.ok = true
			result.created = true
			result.created_item = created
		return result
	editing_task.title = task_title
	editing_task.notes = task_notes
	editing_task.status = status
	result.ok = TaskService.save_task(editing_task)
	return result
