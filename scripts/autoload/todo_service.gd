## Autoload: task list CRUD. Emits signals for UI refresh.
extends Node

const _TodoListOrder := preload("res://scripts/todos/todo_list_order.gd")
const _TodoDayCleanup := preload("res://scripts/todos/todo_day_cleanup.gd")

signal todo_created(item: TodoItem)
signal todo_updated(item: TodoItem)
signal todo_deleted(todo_id: int)
## Emitted when a todo is saved without todo_updated (e.g. checkbox toggle) so UI can refresh counts.
signal todo_stats_changed
signal todo_reordered

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
	_tracked_day_key = _TodoDayCleanup.today_day_key(int(Time.get_unix_time_from_system()))


func _on_day_check_timer() -> void:
	var today_key := _TodoDayCleanup.today_day_key(int(Time.get_unix_time_from_system()))
	if today_key == _tracked_day_key:
		return
	_tracked_day_key = today_key
	_run_day_cleanup_if_needed()


func _run_startup_maintenance() -> void:
	normalize_list_order()
	_run_day_cleanup_if_needed()


func _run_day_cleanup_if_needed() -> void:
	var now := int(Time.get_unix_time_from_system())
	var last_key := Database.get_setting(DbConstants.SETTING_TODO_CLEANUP_DAY_KEY, "")
	if not _TodoDayCleanup.should_run_cleanup(last_key, now):
		return
	purge_completed_before_today()
	Database.set_setting(DbConstants.SETTING_TODO_CLEANUP_DAY_KEY, _TodoDayCleanup.today_day_key(now))


func get_todo_count() -> int:
	return Database.count_todos()


func list_todos() -> Array[TodoItem]:
	var rows := Database.fetch_todos()
	var result: Array[TodoItem] = []
	for row in rows:
		result.append(TodoItem.from_row(row))
	return result


## First non-done mission in list order (top of the active task list).
func get_top_todo() -> TodoItem:
	for item in list_todos():
		if not item.is_done():
			return item
	return null


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
	if status == DbConstants.TODO_DONE:
		normalize_list_order()
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
	normalize_list_order()
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
	for i in items.size():
		items[i].sort_order = i
		if not Database.update_todo(items[i]):
			return false
	normalize_list_order()
	return true


func delete_todo(todo_id: int) -> bool:
	if not Database.soft_delete_todo(todo_id):
		return false
	todo_deleted.emit(todo_id)
	return true


## Mark done, persist, and move completed missions to the bottom of the list.
func complete_todo(item: TodoItem) -> bool:
	if item == null or item.id <= 0 or item.is_done():
		return false
	item.status = DbConstants.TODO_DONE
	if not Database.update_todo(item):
		return false
	normalize_list_order()
	var updated := get_todo(item.id)
	if updated:
		todo_updated.emit(updated)
	return true


## Reorders missions so active items are on top and completed items are at the bottom.
func normalize_list_order() -> bool:
	var items := list_todos()
	var ordered := _TodoListOrder.ordered_active_first(items)
	if not _TodoListOrder.apply_sort_orders(ordered):
		return false
	var changed := false
	for item in ordered:
		if not Database.update_todo(item):
			return false
		changed = true
	if changed:
		todo_reordered.emit()
	return changed


## Soft-deletes completed missions from before today (local midnight). Runs once per calendar day.
func purge_completed_before_today() -> int:
	var today_start := TimeFormat.local_day_start(int(Time.get_unix_time_from_system()))
	var ids := Database.soft_delete_done_todos_before(today_start)
	for todo_id in ids:
		todo_deleted.emit(todo_id)
	if not ids.is_empty():
		normalize_list_order()
	return ids.size()
