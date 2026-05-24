## Mission list, inline editor, progress header, and top-mission pomodoro.
class_name MissionSidebar
extends PanelContainer

const TODO_ROW_SCENE := preload("res://scenes/todos/todo_row.tscn")
const _VBoxListUtil := preload("res://scripts/ui/vbox_list_util.gd")
const _MissionStatusOptions := preload("res://scripts/ui/mission_status_options.gd")
const _MissionComposerLogic := preload("res://scripts/todos/mission_composer_logic.gd")

var _editing_todo: TodoItem = null
var _tracked_top_todo_id: int = 0

@onready var _todo_progress_bar: ProgressBar = %TodoProgressBar
@onready var _todo_progress_label: Label = %TodoProgressLabel
@onready var _new_todo_button: Button = %NewTodoButton
@onready var _todo_mission_panel: PanelContainer = %TodoMissionPanel
@onready var _mission_title_field: LineEdit = %MissionTitleField
@onready var _mission_notes_field: TextEdit = %MissionNotesField
@onready var _mission_tag_picker: TagPicker = %MissionTagPicker
@onready var _mission_status_option: OptionButton = %MissionStatusOption
@onready var _mission_save_button: Button = %MissionSaveButton
@onready var _mission_done_button: Button = %MissionDoneButton
@onready var _mission_delete_button: Button = %MissionDeleteButton
@onready var _mission_cancel_button: Button = %MissionCancelButton
@onready var _mission_edit_actions: VBoxContainer = %MissionEditActions
@onready var _mission_pomodoro: PomodoroTimerWidget = %MissionPomodoro
@onready var _todo_vbox: VBoxContainer = %TodoEntriesVBox
@onready var _todo_empty_label: Label = %TodoEmptyLabel


func initialize() -> void:
	_connect_ui()
	_connect_services()
	_MissionStatusOptions.populate(_mission_status_option)
	_close_mission_composer()
	_mission_pomodoro.bind(DbConstants.TARGET_NONE, 0, false)
	refresh_list()


func _connect_ui() -> void:
	_new_todo_button.pressed.connect(_on_new_todo_pressed)
	_mission_cancel_button.pressed.connect(_on_mission_cancel_pressed)
	_mission_delete_button.pressed.connect(_on_mission_delete_pressed)
	_mission_done_button.pressed.connect(_on_mission_done_pressed)
	_mission_save_button.pressed.connect(_on_mission_save_pressed)
	_mission_title_field.text_submitted.connect(_on_mission_title_submitted)


func _connect_services() -> void:
	TodoService.todo_created.connect(_on_todo_service_changed)
	TodoService.todo_updated.connect(_on_todo_service_changed)
	TodoService.todo_stats_changed.connect(_on_todo_stats_changed)
	TodoService.todo_reordered.connect(refresh_list_deferred)
	TodoService.todo_deleted.connect(_on_todo_deleted)
	TagService.todo_tags_changed.connect(_on_todo_tags_changed)
	PomodoroService.state_changed.connect(_on_pomodoro_state_changed)


func refresh_list_deferred() -> void:
	call_deferred("refresh_list")


func refresh_list() -> void:
	_VBoxListUtil.clear_children_except(_todo_vbox, _todo_empty_label)
	var items := TodoService.list_todos()
	var work_stats_map := TodoService.get_work_stats_map()
	var tags_map := TagService.get_todo_tags_map()
	_todo_empty_label.visible = items.is_empty()
	for item in items:
		var row: TodoRow = TODO_ROW_SCENE.instantiate()
		_todo_vbox.add_child(row)
		row.edit_requested.connect(_on_todo_edit_requested)
		row.reorder_requested.connect(_on_todo_reorder_requested)
		var stats: Dictionary = work_stats_map.get(item.id, TodoRow.EMPTY_WORK_STATS)
		var item_tags: Array = tags_map.get(item.id, [])
		row.setup(item, stats, item_tags)
	_update_todo_progress(items)
	_update_mission_pomodoro_target()
	_apply_todo_active_leds()


func on_pomodoro_session_ended(target_type: String, target_id: int) -> void:
	if target_type == DbConstants.TARGET_TODO and target_id > 0:
		_refresh_todo_work_stats(target_id)


func _refresh_todo_work_stats(todo_id: int) -> void:
	var stats := TodoService.get_work_stats(todo_id)
	for child in _todo_vbox.get_children():
		if child == _todo_empty_label:
			continue
		if child is TodoRow:
			var row := child as TodoRow
			if row.item != null and row.item.id == todo_id:
				row.update_work_stats(stats)
				return


func _on_pomodoro_state_changed() -> void:
	_update_mission_pomodoro_target()
	_apply_todo_active_leds()


func _on_todo_service_changed(_item: TodoItem) -> void:
	refresh_list_deferred()


func _on_todo_stats_changed() -> void:
	_update_todo_progress(TodoService.list_todos())


func _on_todo_tags_changed(_todo_id: int) -> void:
	refresh_list_deferred()


func _on_todo_deleted(todo_id: int) -> void:
	if _editing_todo != null and _editing_todo.id == todo_id:
		_close_mission_composer()
	if PomodoroService.has_active_todo_session() and PomodoroService.active_target_id == todo_id:
		PomodoroService.stop(false)
	refresh_list_deferred()


func _on_new_todo_pressed() -> void:
	_reset_mission_composer()
	_show_mission_composer()
	_mission_tag_picker.refresh()
	_mission_title_field.grab_focus()


func _show_mission_composer() -> void:
	_todo_mission_panel.visible = true


func _hide_mission_composer() -> void:
	_todo_mission_panel.visible = false


func _close_mission_composer() -> void:
	_reset_mission_composer()
	_hide_mission_composer()


func _reset_mission_composer() -> void:
	_editing_todo = null
	_mission_title_field.text = ""
	_mission_notes_field.text = ""
	_mission_tag_picker.clear()
	_mission_tag_picker.refresh()
	_mission_status_option.select(0)
	_mission_save_button.text = "Save mission"
	_mission_edit_actions.visible = false
	_mission_cancel_button.visible = true


func _load_todo_into_mission_composer(item: TodoItem) -> void:
	_show_mission_composer()
	_editing_todo = item
	_mission_title_field.text = item.title
	_mission_notes_field.text = item.notes
	_mission_tag_picker.refresh()
	_mission_tag_picker.set_selected_tags(TagService.get_tags_for_todo(item.id))
	_MissionStatusOptions.select_status(_mission_status_option, item.status)
	_mission_save_button.text = "Save"
	_update_mission_edit_actions(item)
	_mission_cancel_button.visible = true
	_mission_title_field.grab_focus()


func _on_mission_cancel_pressed() -> void:
	_close_mission_composer()


func _on_mission_title_submitted(_new_text: String) -> void:
	_try_save_mission()


func _on_mission_save_pressed() -> void:
	_try_save_mission()


func _try_save_mission() -> bool:
	var tag_ids := _mission_tag_picker.get_selected_tag_ids()
	var result: _MissionComposerLogic.SaveResult = _MissionComposerLogic.try_save(
		_editing_todo,
		_mission_title_field.text,
		_mission_notes_field.text,
		_MissionStatusOptions.selected_status(_mission_status_option)
	)
	if not result.ok:
		return false
	var todo_id := 0
	if result.created and result.created_item != null:
		todo_id = result.created_item.id
	elif _editing_todo != null:
		todo_id = _editing_todo.id
	if todo_id > 0:
		TagService.set_todo_tags(todo_id, tag_ids)
	if result.created:
		_close_mission_composer()
		_update_mission_pomodoro_target()
		return true
	_close_mission_composer()
	return true


func _on_mission_delete_pressed() -> void:
	if _editing_todo == null:
		return
	TodoService.delete_todo(_editing_todo.id)


func _on_mission_done_pressed() -> void:
	if _editing_todo == null or _editing_todo.is_done():
		return
	_editing_todo.title = _mission_title_field.text.strip_edges()
	_editing_todo.notes = _mission_notes_field.text.strip_edges()
	if _editing_todo.title.is_empty():
		return
	if TodoService.complete_todo(_editing_todo):
		TagService.set_todo_tags(_editing_todo.id, _mission_tag_picker.get_selected_tag_ids())
		_close_mission_composer()


func _update_mission_edit_actions(item: TodoItem) -> void:
	_mission_edit_actions.visible = true
	_mission_done_button.visible = not item.is_done()
	_mission_delete_button.visible = true


func _update_mission_pomodoro_target() -> void:
	var top_todo := TodoService.get_top_todo()
	if top_todo == null:
		_tracked_top_todo_id = 0
		_mission_pomodoro.bind(DbConstants.TARGET_NONE, 0, false)
		return
	var top_id := top_todo.id
	if (
		PomodoroService.has_active_todo_session()
		and _tracked_top_todo_id > 0
		and top_id != _tracked_top_todo_id
	):
		PomodoroService.stop(false)
	_tracked_top_todo_id = top_id
	_mission_pomodoro.bind(DbConstants.TARGET_TODO, top_id, true)


func _apply_todo_active_leds() -> void:
	var active_id := 0
	if PomodoroService.has_active_todo_session() and PomodoroService.is_running:
		active_id = PomodoroService.active_target_id
	for child in _todo_vbox.get_children():
		if child == _todo_empty_label:
			continue
		if child is TodoRow:
			var row := child as TodoRow
			row.set_mission_active(row.item != null and row.item.id == active_id)


func _update_todo_progress(items: Array[TodoItem]) -> void:
	var total := items.size()
	var done := 0
	for item in items:
		if item.is_done():
			done += 1
	_todo_progress_label.text = "%d / %d complete" % [done, total]
	if total > 0:
		_todo_progress_bar.max_value = float(total)
		_todo_progress_bar.value = float(done)
	else:
		_todo_progress_bar.max_value = 1.0
		_todo_progress_bar.value = 0.0


func _on_todo_reorder_requested(dragged_id: int, target_id: int, insert_before: bool) -> void:
	TodoService.move_todo_relative_to(dragged_id, target_id, insert_before)


func _on_todo_edit_requested(item: TodoItem) -> void:
	_load_todo_into_mission_composer(item)
