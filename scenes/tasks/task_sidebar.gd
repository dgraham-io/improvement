## Task list, inline editor, progress header, and top-task pomodoro.
extends PanelContainer

const TASK_ROW_SCENE := preload("res://scenes/tasks/task_row.tscn")
const _TaskStatusOptions := preload("res://scripts/ui/task_status_options.gd")
const _TaskComposerLogic := preload("res://scripts/tasks/task_composer_logic.gd")
const TASK_SPLIT_OPEN_OFFSET := 180
const _AppMessage := preload("res://scripts/ui/app_message.gd")
const _ComposerDraft := preload("res://scripts/ui/composer_draft.gd")

signal composer_focus_requested

var _editing_task: TaskItem = null
var _parked_draft: Dictionary = {}
var _tracked_top_task_id: int = 0

@onready var _task_progress_bar: ProgressBar = %TaskProgressBar
@onready var _task_progress_label: Label = %TaskProgressLabel
@onready var _new_task_button: Button = %NewTaskButton
@onready var _task_composer_panel: PanelContainer = %TaskComposerPanel
@onready var _composer_title_field: LineEdit = %TaskTitleField
@onready var _composer_notes_field: TextEdit = %TaskNotesField
@onready var _composer_tag_picker: TagPicker = %TaskTagPicker
@onready var _composer_status_option: OptionButton = %TaskStatusOption
@onready var _composer_save_button: Button = %TaskSaveButton
@onready var _composer_delete_button: Button = %TaskDeleteButton
@onready var _composer_cancel_button: Button = %TaskCancelButton
@onready var _task_pomodoro: PomodoroTimerWidget = %TaskPomodoro
@onready var _task_split: VSplitContainer = %TaskSplit
@onready var _task_vbox = %TaskEntriesVBox
@onready var _task_empty_label: Label = %TaskEmptyLabel


func initialize() -> void:
	_connect_ui()
	_connect_services()
	_TaskStatusOptions.populate(_composer_status_option)
	_close_task_composer()
	_task_pomodoro.bind(DbConstants.TARGET_NONE, 0, false)
	refresh_list()


func _connect_ui() -> void:
	_new_task_button.pressed.connect(_on_new_task_pressed)
	_composer_cancel_button.pressed.connect(_on_composer_cancel_pressed)
	_composer_delete_button.pressed.connect(_on_composer_delete_pressed)
	_composer_save_button.pressed.connect(_on_composer_save_pressed)
	_composer_title_field.text_submitted.connect(_on_composer_title_submitted)
	_task_vbox.reorder_to_index.connect(_on_task_reorder_to_index)
	_task_vbox.reorder_drag_started.connect(_on_reorder_drag_started)
	_task_vbox.reorder_drag_ended.connect(_on_reorder_drag_ended)


func _connect_services() -> void:
	TaskService.task_created.connect(_on_task_service_changed)
	TaskService.task_updated.connect(_on_task_service_changed)
	TaskService.task_stats_changed.connect(_on_task_stats_changed)
	TaskService.task_reordered.connect(refresh_list_deferred)
	TaskService.task_deleted.connect(_on_task_deleted)
	TagService.task_tags_changed.connect(_on_task_tags_changed)
	PomodoroService.state_changed.connect(_on_pomodoro_state_changed)


func refresh_list_deferred() -> void:
	call_deferred("refresh_list")


func refresh_list() -> void:
	_task_vbox.clear_rows()
	var items := TaskService.list_tasks()
	var work_stats_map := TaskService.get_work_stats_map()
	var tags_map := TagService.get_task_tags_map()
	_task_empty_label.visible = items.is_empty()
	for item in items:
		var row = TASK_ROW_SCENE.instantiate()
		_task_vbox.add_child(row)
		row.edit_requested.connect(_on_task_edit_requested)
		var stats: Dictionary = work_stats_map.get(item.id, {"completed_pomodoros": 0, "total_work_sec": 0})
		var item_tags: Array = tags_map.get(item.id, [])
		row.setup(item, stats, item_tags)
	_update_task_progress(items)
	_update_task_pomodoro_target()
	_apply_task_active_leds()


func on_pomodoro_session_ended(target_type: String, target_id: int) -> void:
	if target_type == DbConstants.TARGET_TASK and target_id > 0:
		_refresh_task_work_stats(target_id)


func _refresh_task_work_stats(task_id: int) -> void:
	var stats := TaskService.get_work_stats(task_id)
	for child in _task_vbox.get_children():
		if child == _task_empty_label:
			continue
		if child is Control and (child as Control).has_method("update_work_stats"):
			var row = child
			if row.item != null and row.item.id == task_id:
				row.update_work_stats(stats)
				return


func _on_pomodoro_state_changed() -> void:
	_update_task_pomodoro_target()
	_apply_task_active_leds()


func _on_reorder_drag_started() -> void:
	_set_reorder_header_passthrough(true)


func _on_reorder_drag_ended() -> void:
	_set_reorder_header_passthrough(false)


func _set_reorder_header_passthrough(active: bool) -> void:
	var controls: Array[Control] = [_new_task_button]
	for ctrl in controls:
		if ctrl == null:
			continue
		if active:
			if not ctrl.has_meta("_saved_mouse_filter"):
				ctrl.set_meta("_saved_mouse_filter", ctrl.mouse_filter)
			ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif ctrl.has_meta("_saved_mouse_filter"):
			ctrl.mouse_filter = int(ctrl.get_meta("_saved_mouse_filter"))
			ctrl.remove_meta("_saved_mouse_filter")


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.has("task_id"):
		_task_vbox.hide_gap()
		return true
	return false


func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	pass


func _on_task_service_changed(item) -> void:
	if _editing_task != null and item.id == _editing_task.id and item.is_done():
		_close_task_composer()
	refresh_list_deferred()


func _on_task_stats_changed() -> void:
	_update_task_progress(TaskService.list_tasks())


func _on_task_tags_changed(_task_id: int) -> void:
	refresh_list_deferred()


func _on_task_deleted(task_id: int) -> void:
	if _editing_task != null and _editing_task.id == task_id:
		_close_task_composer()
	if PomodoroService.has_active_task_session() and PomodoroService.active_target_id == task_id:
		PomodoroService.stop(false)
	refresh_list_deferred()


func park_composer() -> void:
	if not _task_composer_panel.visible:
		return
	_parked_draft = _snapshot_composer()
	_hide_task_composer_without_reset()


func has_parked_draft() -> bool:
	return not _parked_draft.is_empty()


func _on_new_task_pressed() -> void:
	composer_focus_requested.emit()
	if has_parked_draft():
		_restore_from_snapshot(_parked_draft)
		_parked_draft = {}
		_show_task_composer()
		_composer_title_field.grab_focus()
		return
	_reset_task_composer()
	_show_task_composer()
	_composer_tag_picker.refresh()
	_composer_title_field.grab_focus()


func _show_task_composer() -> void:
	_task_composer_panel.visible = true
	_task_composer_panel.custom_minimum_size.y = 140
	_task_split.split_offset = TASK_SPLIT_OPEN_OFFSET


func _hide_task_composer() -> void:
	_hide_task_composer_without_reset()


func _hide_task_composer_without_reset() -> void:
	_task_composer_panel.visible = false
	_task_composer_panel.custom_minimum_size.y = 0
	_task_split.split_offset = 0


func _close_task_composer() -> void:
	_parked_draft = {}
	_reset_task_composer()
	_hide_task_composer()


func _reset_task_composer() -> void:
	_editing_task = null
	_composer_title_field.text = ""
	_composer_notes_field.text = ""
	_composer_tag_picker.clear()
	_composer_tag_picker.refresh()
	_composer_status_option.select(0)
	_composer_save_button.text = "Save"  # standardized to "Save" (matches journal composer + Settings; was "Save task" only for new)
	_composer_delete_button.visible = false
	_composer_cancel_button.visible = true


func _load_task_into_composer(item: TaskItem) -> void:
	composer_focus_requested.emit()
	_parked_draft = {}
	_show_task_composer()
	_editing_task = item
	_composer_title_field.text = item.title
	_composer_notes_field.text = item.notes
	_composer_tag_picker.refresh()
	_composer_tag_picker.set_selected_tags(TagService.get_tags_for_task(item.id))
	_TaskStatusOptions.select_status(_composer_status_option, item.status)
	_composer_save_button.text = "Save"  # standardized to "Save" (matches journal composer + Settings; was "Save task" only for new)
	_composer_delete_button.visible = true
	_composer_cancel_button.visible = true
	_composer_title_field.grab_focus()


func _on_composer_cancel_pressed() -> void:
	_close_task_composer()


func _on_composer_title_submitted(_new_text: String) -> void:
	_try_save_composer()


func _on_composer_save_pressed() -> void:
	_try_save_composer()


func _try_save_composer() -> bool:
	var tag_ids := _composer_tag_picker.get_selected_tag_ids()
	var result: _TaskComposerLogic.SaveResult = _TaskComposerLogic.try_save(
		_editing_task,
		_composer_title_field.text,
		_composer_notes_field.text,
		_TaskStatusOptions.selected_status(_composer_status_option)
	)
	if not result.ok:
		if _composer_title_field.text.strip_edges().is_empty():
			_AppMessage.show_error(self, "Cannot save task", "Enter a title.")
		else:
			_AppMessage.show_save_failed(self, "task")
		return false
	var task_id := 0
	if result.created and result.created_item != null:
		task_id = result.created_item.id
	elif _editing_task != null:
		task_id = _editing_task.id
	if task_id > 0 and not TagService.set_task_tags(task_id, tag_ids):
		_AppMessage.show_save_failed(self, "task tags")
		return false
	if result.created:
		_close_task_composer()
		_update_task_pomodoro_target()
		return true
	_close_task_composer()
	return true


func _on_composer_delete_pressed() -> void:
	if _editing_task == null:
		return
	if not TaskService.delete_task(_editing_task.id):
		_AppMessage.show_delete_failed(self, "task")


func _update_task_pomodoro_target() -> void:
	var top_task := TaskService.get_top_task()
	if top_task == null:
		_tracked_top_task_id = 0
		_task_pomodoro.bind(DbConstants.TARGET_NONE, 0, false)
		return
	var top_id := top_task.id
	if (
		PomodoroService.has_active_task_session()
		and _tracked_top_task_id > 0
		and top_id != _tracked_top_task_id
	):
		PomodoroService.stop(false)
	_tracked_top_task_id = top_id
	_task_pomodoro.bind(DbConstants.TARGET_TASK, top_id, true)


func _apply_task_active_leds() -> void:
	var active_id := 0
	if PomodoroService.has_active_task_session() and PomodoroService.is_running:
		active_id = PomodoroService.active_target_id
	for child in _task_vbox.get_children():
		if child == _task_empty_label:
			continue
		if child is Control and (child as Control).has_method("set_task_active"):
			var row = child
			row.set_task_active(row.item != null and row.item.id == active_id)


func _update_task_progress(items: Array[TaskItem]) -> void:
	var total := items.size()
	var done := 0
	for item in items:
		if item.is_done():
			done += 1
	_task_progress_label.text = "%d / %d complete" % [done, total]
	if total > 0:
		_task_progress_bar.max_value = float(total)
		_task_progress_bar.value = float(done)
	else:
		_task_progress_bar.max_value = 1.0
		_task_progress_bar.value = 0.0


func _on_task_reorder_to_index(dragged_id: int, insert_index: int) -> void:
	if not TaskService.move_task_to_index(dragged_id, insert_index):
		_AppMessage.show_save_failed(self, "task order")
		refresh_list_deferred()


func _snapshot_composer() -> Dictionary:
	var task_id := _editing_task.id if _editing_task != null else 0
	return _ComposerDraft.task_from_fields(
		_composer_title_field.text,
		_composer_notes_field.text,
		_composer_tag_picker.get_selected_tag_ids(),
		_TaskStatusOptions.selected_status(_composer_status_option),
		task_id,
		_composer_save_button.text,
		_composer_delete_button.visible
	)


func _restore_from_snapshot(draft: Dictionary) -> void:
	if draft.is_empty():
		return
	var task_id := int(draft.get("editing_task_id", 0))
	if task_id > 0:
		_editing_task = TaskService.get_task(task_id)
	else:
		_editing_task = null
	_composer_title_field.text = str(draft.get("title", ""))
	_composer_notes_field.text = str(draft.get("notes", ""))
	_composer_tag_picker.refresh()
	_composer_tag_picker.set_selected_tags(_ComposerDraft.tags_from_ids(draft.get("tag_ids", [])))
	var status := str(draft.get("status", DbConstants.TASK_PENDING))
	_TaskStatusOptions.select_status(_composer_status_option, status)
	_composer_save_button.text = str(draft.get("save_button_text", "Save"))  # standardized "Save" default (see journal_area.gd too)
	_composer_delete_button.visible = bool(draft.get("delete_visible", false))


func _on_task_edit_requested(item: TaskItem) -> void:
	_load_task_into_composer(item)
