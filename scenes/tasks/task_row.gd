## One task card with priority strip, pomodoro work time, and progress bar.
extends PanelContainer

const _TagDisplay := preload("res://scripts/ui/tag_display.gd")
const _TaskTitleFormat := preload("res://scripts/tasks/task_title_format.gd")
const _DragHandleScript := preload("res://scenes/tasks/task_drag_handle.gd")
const _AppMessage := preload("res://scripts/ui/app_message.gd")

signal edit_requested(item: TaskItem)

const PRIORITY_COLORS := [
	Color(0.45, 0.5, 0.62, 0.7),
	Color(0.133333, 0.866667, 1, 0.9),
	Color(0.658824, 0.333333, 0.968627, 0.9),
	Color(0.92549, 0.282353, 0.6, 0.95),
]
const EMPTY_WORK_STATS := {"completed_pomodoros": 0, "total_work_sec": 0}

var item: TaskItem

@onready var _active_led: Control = %TaskActiveLed
@onready var _done_button: Button = %DoneButton
@onready var _title_label: RichTextLabel = %TitleLabel
@onready var _notes_label: Label = %NotesLabel
@onready var _tags_label: Label = %TagsLabel
@onready var _work_time_label: Label = %WorkTimeLabel
@onready var _priority_strip: ColorRect = %PriorityStrip
@onready var _progress_bar: ProgressBar = %TaskProgressBar

var _work_stats: Dictionary = EMPTY_WORK_STATS


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null:
		return null
	set_reorder_drag_active(true)
	var preview := Label.new()
	preview.text = item.title
	preview.add_theme_font_size_override("font_size", 16)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	var payload := {"task_id": item.id}
	var list = _find_list_drop_target()
	if list != null:
		var global_pos := get_global_transform() * _at_position
		var list_local: Vector2 = list.get_global_transform().affine_inverse() * global_pos
		payload["list_anchor_y"] = list_local.y
	return payload


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return _forward_drop_to_list(at_position, data)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_forward_drop_to_list(at_position, data, true)


func set_reorder_drag_active(active: bool) -> void:
	for child in get_children():
		_apply_drag_passthrough(child, active)


func _apply_drag_passthrough(node: Node, active: bool) -> void:
	if node.get_script() == _DragHandleScript:
		return
	if node is Control:
		var control := node as Control
		if active:
			if not control.has_meta("_saved_mouse_filter"):
				control.set_meta("_saved_mouse_filter", control.mouse_filter)
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif control.has_meta("_saved_mouse_filter"):
			control.mouse_filter = int(control.get_meta("_saved_mouse_filter"))
			control.remove_meta("_saved_mouse_filter")
	for child in node.get_children():
		_apply_drag_passthrough(child, active)


func _forward_drop_to_list(at_position: Vector2, data: Variant, apply_drop: bool = false) -> bool:
	var list = _find_list_drop_target()
	if list == null:
		return false
	var global_pos := get_global_transform() * at_position
	var local_in_list: Vector2 = list.get_global_transform().affine_inverse() * global_pos
	if apply_drop:
		list.handle_drop(local_in_list, data)
		return true
	return list.handle_can_drop(local_in_list, data)


const _TaskListDropTargetScript := preload("res://scenes/tasks/task_list_drop_target.gd")


func _find_list_drop_target():
	var node: Node = get_parent()
	while node != null:
		if node is Control and (node as Control).get_script() == _TaskListDropTargetScript:
			return node
		node = node.get_parent()
	return null


func setup(task_item, work_stats: Dictionary = EMPTY_WORK_STATS, tags: Array = []) -> void:
	item = task_item
	_work_stats = work_stats
	_active_led.set_active(false)
	_apply_title(task_item)
	_notes_label.text = task_item.notes.strip_edges()
	_notes_label.visible = not _notes_label.text.is_empty()
	var tag_text := _TagDisplay.format_tag_names(tags)
	_tags_label.text = tag_text
	_tags_label.visible = not tag_text.is_empty()
	_apply_priority_strip(task_item.priority)
	_apply_work_stats(work_stats)
	_apply_progress(task_item, work_stats)
	_apply_done_style(task_item.is_done())
	_update_action_buttons(task_item)


func update_work_stats(work_stats: Dictionary) -> void:
	_work_stats = work_stats
	if item == null:
		return
	_apply_work_stats(work_stats)
	_apply_progress(item, work_stats)


func set_task_active(active: bool) -> void:
	if item != null and item.is_done():
		active = false
	_active_led.set_active(active)


func _apply_title(task_item) -> void:
	_title_label.text = _TaskTitleFormat.display_text(task_item.title, task_item.is_done())


func _update_action_buttons(task_item) -> void:
	_done_button.visible = not task_item.is_done()


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


func _apply_progress(task_item, work_stats: Dictionary) -> void:
	var completed := int(work_stats.get("completed_pomodoros", 0))
	if task_item.is_done():
		_progress_bar.value = 1.0
	elif completed > 0:
		_progress_bar.value = clampf(float(completed) * 0.2, 0.2, 0.85)
	elif task_item.status == DbConstants.TASK_IN_PROGRESS:
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
	if item != null:
		_apply_title(item)


func _on_done_pressed() -> void:
	if item == null or item.is_done():
		return
	if (
		PomodoroService.has_active_task_session()
		and PomodoroService.active_target_id == item.id
	):
		PomodoroService.stop(false)
	if not TaskService.complete_task(item):
		_AppMessage.show_save_failed(self, "task")


func _on_edit_pressed() -> void:
	if item:
		edit_requested.emit(item)
