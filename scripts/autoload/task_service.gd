## Autoload: task list CRUD. Emits signals for UI refresh.
extends Node

const _TaskListOrder := preload("res://scripts/tasks/task_list_order.gd")
const _TaskDayCleanup := preload("res://scripts/tasks/task_day_cleanup.gd")
const _TaskItem := preload("res://scripts/models/task_item.gd")

signal task_created(item: TaskItem)
signal task_updated(item: TaskItem)
signal task_deleted(task_id: int)
## Emitted when a task is saved without task_updated (e.g. checkbox toggle) so UI can refresh counts.
signal task_stats_changed
signal task_reordered

var _day_check_timer: Timer
var _tracked_day_key: String = ""


func _ready() -> void:
	if not Database.is_ready:
		await Database.ready_changed
	if not Database.is_ready:
		return
	_run_startup_maintenance()
	_start_day_check_timer()


func _start_day_check_timer() -> void:
	_day_check_timer = Timer.new()
	_day_check_timer.wait_time = 60.0
	_day_check_timer.autostart = true
	_day_check_timer.timeout.connect(_on_day_check_timer)
	add_child(_day_check_timer)
	_tracked_day_key = _TaskDayCleanup.today_day_key(int(Time.get_unix_time_from_system()))


func _on_day_check_timer() -> void:
	var today_key := _TaskDayCleanup.today_day_key(int(Time.get_unix_time_from_system()))
	if today_key == _tracked_day_key:
		return
	_tracked_day_key = today_key
	_run_day_cleanup_if_needed()


func _run_startup_maintenance() -> void:
	normalize_list_order()
	_run_day_cleanup_if_needed()


func _run_day_cleanup_if_needed() -> void:
	var now := int(Time.get_unix_time_from_system())
	var last_key := Database.get_setting(DbConstants.SETTING_TASK_CLEANUP_DAY_KEY, "")
	if not _TaskDayCleanup.should_run_cleanup(last_key, now):
		return
	purge_completed_before_today()
	Database.set_setting(DbConstants.SETTING_TASK_CLEANUP_DAY_KEY, _TaskDayCleanup.today_day_key(now))


func get_task_count() -> int:
	return Database.count_tasks()


func list_tasks() -> Array[TaskItem]:
	var rows := Database.fetch_tasks()
	var result: Array[TaskItem] = []
	for row in rows:
		result.append(_TaskItem.from_row(row))
	return result


## First non-done task in list order (top of the active task list).
func get_top_task() -> TaskItem:
	for item in list_tasks():
		if not item.is_done():
			return item
	return null


func get_task(task_id: int) -> TaskItem:
	var row := Database.fetch_task_by_id(task_id)
	if row.is_empty():
		return null
	return _TaskItem.from_row(row)


func get_work_stats_map() -> Dictionary:
	return Database.fetch_task_pomodoro_work_stats_map()


func get_work_stats(task_id: int) -> Dictionary:
	return Database.fetch_task_pomodoro_work_stats(task_id)


func create_task(
	title: String,
	notes: String = "",
	status: String = DbConstants.TASK_PENDING,
	priority: int = 0,
	due_at: int = 0,
	journal_entry_id: int = 0
) -> TaskItem:
	if not DbConstants.task_status_values().has(status):
		status = DbConstants.TASK_PENDING
	var id := Database.insert_task(title, notes, status, priority, due_at, journal_entry_id)
	if id < 0:
		return null
	if status == DbConstants.TASK_DONE:
		normalize_list_order()
	var item := get_task(id)
	if item:
		task_created.emit(item)
	return item


func save_task(item: TaskItem, emit_updated: bool = true) -> bool:
	if item.id <= 0:
		return false
	if not DbConstants.task_status_values().has(item.status):
		item.status = DbConstants.TASK_PENDING
	if not Database.update_task(item):
		return false
	normalize_list_order()
	if emit_updated:
		var updated := get_task(item.id)
		if updated:
			task_updated.emit(updated)
	else:
		task_stats_changed.emit()
	return true


func set_status(task_id: int, status: String, emit_updated: bool = true) -> bool:
	var item := get_task(task_id)
	if item == null:
		return false
	item.status = status
	return save_task(item, emit_updated)


func move_task_relative_to(dragged_id: int, target_id: int, insert_before: bool) -> bool:
	var items := list_tasks()
	var target_idx := -1
	for i in items.size():
		if items[i].id == target_id:
			target_idx = i
			break
	if target_idx < 0:
		return false
	var insert_idx := target_idx if insert_before else target_idx + 1
	return move_task_to_index(dragged_id, insert_idx)


## Insert [param dragged_id] at [param insert_index] in the current list order (0 = top).
func move_task_to_index(dragged_id: int, insert_index: int) -> bool:
	var items := list_tasks()
	var from_idx := -1
	for i in items.size():
		if items[i].id == dragged_id:
			from_idx = i
			break
	if from_idx < 0:
		return false
	var moved := items[from_idx]
	items.remove_at(from_idx)
	insert_index = clampi(insert_index, 0, items.size())
	if from_idx < insert_index:
		insert_index -= 1
	items.insert(insert_index, moved)
	for i in items.size():
		items[i].sort_order = i
		if not Database.update_task(items[i]):
			return false
	normalize_list_order()
	task_reordered.emit()
	return true


func delete_task(task_id: int) -> bool:
	if not Database.soft_delete_task(task_id):
		return false
	task_deleted.emit(task_id)
	return true


## Mark done, persist, and move completed tasks to the bottom of the list.
func complete_task(item: TaskItem) -> bool:
	if item == null or item.id <= 0 or item.is_done():
		return false
	item.status = DbConstants.TASK_DONE
	if not Database.update_task(item):
		return false
	normalize_list_order()
	var updated := get_task(item.id)
	if updated:
		task_updated.emit(updated)
	return true


## Reorders tasks so active items are on top and completed items are at the bottom.
func normalize_list_order() -> bool:
	var items := list_tasks()
	var ordered := _TaskListOrder.ordered_active_first(items)
	if not _TaskListOrder.apply_sort_orders(ordered):
		return false
	var changed := false
	for item in ordered:
		if not Database.update_task(item):
			return false
		changed = true
	if changed:
		task_reordered.emit()
	return changed


## Soft-deletes completed tasks from before today (local midnight). Runs once per calendar day.
func purge_completed_before_today() -> int:
	var today_start := TimeFormat.local_day_start(int(Time.get_unix_time_from_system()))
	var ids := Database.soft_delete_done_tasks_before(today_start)
	for task_id in ids:
		task_deleted.emit(task_id)
	if not ids.is_empty():
		normalize_list_order()
	return ids.size()
