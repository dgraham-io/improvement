## One mission card with priority strip and progress placeholder for gamification.
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

var item: TodoItem

@onready var _check_box: MissionLedCheck = %DoneCheckBox
@onready var _title_label: Label = %TitleLabel
@onready var _notes_label: Label = %NotesLabel
@onready var _priority_label: Label = %PriorityLabel
@onready var _priority_strip: ColorRect = %PriorityStrip
@onready var _progress_bar: ProgressBar = %MissionProgressBar


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


func setup(todo_item: TodoItem) -> void:
	item = todo_item
	_check_box.set_block_signals(true)
	_check_box.button_pressed = todo_item.is_done()
	_check_box.set_block_signals(false)
	_check_box.queue_redraw()
	_title_label.text = todo_item.title
	_notes_label.text = todo_item.notes.strip_edges()
	_notes_label.visible = not _notes_label.text.is_empty()
	_apply_priority_visuals(todo_item.priority)
	_apply_progress_placeholder(todo_item)
	_apply_done_style(todo_item.is_done())
	set_pomodoro_focus(false)


func set_pomodoro_focus(focused: bool) -> void:
	if focused:
		add_theme_stylebox_override("panel", POMODORO_FOCUS_STYLE)
	else:
		remove_theme_stylebox_override("panel")


func _apply_priority_visuals(priority: int) -> void:
	var tier := clampi(priority, 0, PRIORITY_COLORS.size() - 1)
	_priority_label.text = "P%d" % priority
	_priority_strip.color = PRIORITY_COLORS[tier]


func _apply_progress_placeholder(todo_item: TodoItem) -> void:
	# Reserved for sub-task / XP progress; completion drives the bar for now.
	var value := 1.0 if todo_item.is_done() else 0.15
	if todo_item.status == DbConstants.TODO_IN_PROGRESS:
		value = 0.55
	_progress_bar.value = value


func _apply_done_style(done: bool) -> void:
	if done:
		_title_label.modulate = Color(0.55, 0.58, 0.68, 1.0)
		_priority_label.modulate = Color(0.5, 0.5, 0.55, 1.0)
	else:
		_title_label.modulate = Color(1, 1, 1, 1)
		_priority_label.modulate = Color(1, 1, 1, 1)


func _on_done_toggled(toggled_on: bool) -> void:
	if item == null:
		return
	var new_status := DbConstants.TODO_DONE if toggled_on else DbConstants.TODO_PENDING
	if item.status == new_status:
		return
	item.status = new_status
	_apply_done_style(toggled_on)
	_apply_progress_placeholder(item)
	TodoService.save_todo(item, false)


func _on_edit_pressed() -> void:
	if item:
		edit_requested.emit(item)


func _on_delete_pressed() -> void:
	if item:
		delete_requested.emit(item.id)
