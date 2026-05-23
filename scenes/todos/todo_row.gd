## One mission card with priority strip, pomodoro work time, and progress bar.
class_name TodoRow
extends PanelContainer

signal edit_requested(item: TodoItem)
signal delete_requested(todo_id: int)
signal reorder_requested(dragged_id: int, target_id: int, insert_before: bool)

const PRIORITY_COLORS := [
	Color(0.45, 0.5, 0.62, 0.7),
	Color(0.133333, 0.866667, 1, 0.9),
	Color(0.658824, 0.333333, 0.968627, 0.9),
	Color(0.92549, 0.282353, 0.6, 0.95),
]
const POMODORO_FOCUS_STYLE := preload("res://assets/themes/styleboxes/panel_pomodoro_focus.tres")
const EMPTY_WORK_STATS := {"completed_pomodoros": 0, "total_work_sec": 0}

var item: TodoItem

@onready var _check_box: MissionLedCheck = %DoneCheckBox
@onready var _title_label: Label = %TitleLabel
@onready var _notes_label: Label = %NotesLabel
@onready var _work_time_label: Label = %WorkTimeLabel
@onready var _priority_strip: ColorRect = %PriorityStrip
@onready var _progress_bar: ProgressBar = %MissionProgressBar

var _work_stats: Dictionary = EMPTY_WORK_STATS


func create_drag_data() -> Variant:
	if item == null:
		return null
	var preview := Label.new()
	preview.text = item.title
	preview.add_theme_font_size_override("font_size", 16)
	set_drag_preview(preview)
	return {"todo_id": item.id}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if item == null or not data is Dictionary:
		return false
	var dragged_id: int = int(data.get("todo_id", 0))
	return dragged_id > 0 and dragged_id != item.id


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var dragged_id: int = int(data.get("todo_id", 0))
	if dragged_id <= 0 or item == null or dragged_id == item.id:
		return
	var insert_before := at_position.y < size.y * 0.5
	reorder_requested.emit(dragged_id, item.id, insert_before)


func setup(todo_item: TodoItem, work_stats: Dictionary = EMPTY_WORK_STATS) -> void:
	item = todo_item
	_work_stats = work_stats
	_check_box.set_block_signals(true)
	_check_box.button_pressed = todo_item.is_done()
	_check_box.set_block_signals(false)
	_check_box.queue_redraw()
	_title_label.text = todo_item.title
	_notes_label.text = todo_item.notes.strip_edges()
	_notes_label.visible = not _notes_label.text.is_empty()
	_apply_priority_strip(todo_item.priority)
	_apply_work_stats(work_stats)
	_apply_progress(todo_item, work_stats)
	_apply_done_style(todo_item.is_done())
	set_pomodoro_focus(false)


func update_work_stats(work_stats: Dictionary) -> void:
	_work_stats = work_stats
	if item == null:
		return
	_apply_work_stats(work_stats)
	_apply_progress(item, work_stats)


func set_pomodoro_focus(focused: bool) -> void:
	if focused:
		add_theme_stylebox_override("panel", POMODORO_FOCUS_STYLE)
	else:
		remove_theme_stylebox_override("panel")


func _apply_priority_strip(priority: int) -> void:
	var tier := clampi(priority, 0, PRIORITY_COLORS.size() - 1)
	_priority_strip.color = PRIORITY_COLORS[tier]


func _apply_work_stats(work_stats: Dictionary) -> void:
	var total_sec := int(work_stats.get("total_work_sec", 0))
	var pomodoros := int(work_stats.get("completed_pomodoros", 0))
	if total_sec <= 0:
		_work_time_label.text = ""
		_work_time_label.tooltip_text = ""
		_work_time_label.visible = false
		return
	_work_time_label.text = TimeFormat.format_work_duration(total_sec)
	if pomodoros == 1:
		_work_time_label.tooltip_text = "1 pomodoro"
	else:
		_work_time_label.tooltip_text = "%d pomodoros" % pomodoros
	_work_time_label.visible = true


func _apply_progress(todo_item: TodoItem, work_stats: Dictionary) -> void:
	var completed := int(work_stats.get("completed_pomodoros", 0))
	if todo_item.is_done():
		_progress_bar.value = 1.0
	elif completed > 0:
		_progress_bar.value = clampf(float(completed) * 0.2, 0.2, 0.85)
	elif todo_item.status == DbConstants.TODO_IN_PROGRESS:
		_progress_bar.value = 0.55
	else:
		_progress_bar.value = 0.15


func _apply_done_style(done: bool) -> void:
	if done:
		_title_label.modulate = Color(0.55, 0.58, 0.68, 1.0)
		_work_time_label.modulate = Color(0.5, 0.5, 0.55, 1.0)
	else:
		_title_label.modulate = Color(1, 1, 1, 1)
		_work_time_label.modulate = Color(1, 1, 1, 1)


func _on_done_toggled(toggled_on: bool) -> void:
	if item == null:
		return
	var new_status := DbConstants.TODO_DONE if toggled_on else DbConstants.TODO_PENDING
	if not toggled_on and int(_work_stats.get("completed_pomodoros", 0)) > 0:
		new_status = DbConstants.TODO_IN_PROGRESS
	if item.status == new_status:
		return
	item.status = new_status
	_apply_done_style(toggled_on)
	_apply_progress(item, _work_stats)
	TodoService.save_todo(item, false)


func _on_edit_pressed() -> void:
	if item:
		edit_requested.emit(item)


func _on_delete_pressed() -> void:
	if item:
		delete_requested.emit(item.id)
