## Main shell: resizable journal composer and mission sidebar.
extends Control

const JOURNAL_ROW_SCENE := preload("res://scenes/journal/journal_entry_row.tscn")
const TODO_ROW_SCENE := preload("res://scenes/todos/todo_row.tscn")

@export var scale_factor: float = 1.0

var _editing_entry: JournalEntry = null
var _editing_todo: TodoItem = null
var _tracked_top_todo_id: int = 0
@onready var _journal_vbox: VBoxContainer = %JournalEntriesVBox
@onready var _journal_empty_label: Label = %JournalEmptyLabel
@onready var _todo_vbox: VBoxContainer = %TodoEntriesVBox
@onready var _todo_empty_label: Label = %TodoEmptyLabel
@onready var _todo_mission_panel: PanelContainer = %TodoMissionPanel
@onready var _mission_title_field: LineEdit = %MissionTitleField
@onready var _mission_notes_field: TextEdit = %MissionNotesField
@onready var _mission_status_option: OptionButton = %MissionStatusOption
@onready var _mission_save_button: Button = %MissionSaveButton
@onready var _mission_delete_button: Button = %MissionDeleteButton
@onready var _mission_cancel_button: Button = %MissionCancelButton
@onready var _composer_panel: PanelContainer = %ComposerPanel
@onready var _composer_field: TextEdit = %ComposerField
@onready var _composer_timestamps: Label = %ComposerTimestamps
@onready var _composer_save_button: Button = %ComposerSaveButton
@onready var _composer_delete_button: Button = %ComposerDeleteButton
@onready var _composer_cancel_button: Button = %ComposerCancelButton
@onready var _new_journal_button: Button = %NewJournalButton
@onready var _journal_pomodoro: PomodoroTimerWidget = %JournalPomodoro
@onready var _mission_pomodoro: PomodoroTimerWidget = %MissionPomodoro
@onready var _todo_progress_bar: ProgressBar = %TodoProgressBar
@onready var _todo_progress_label: Label = %TodoProgressLabel
@onready var _entry_count_label: Label = %EntryCountLabel
@onready var _xp_label: Label = %XpLabel


func _ready() -> void:
	if not Database.is_ready:
		await Database.ready_changed
	_apply_ui_scale()
	_setup_mission_status_option()
	_connect_services()
	_close_composer()
	_close_mission_composer()
	_mission_pomodoro.bind(DbConstants.TARGET_NONE, 0, false)
	_refresh_journal_list()
	_refresh_todo_list()
	_update_mission_pomodoro_target()
	_update_gamification_placeholders()
	if OS.is_debug_build():
		print(
			"Improvement ready — journal: %d, todos: %d"
			% [JournalService.get_entry_count(), TodoService.get_todo_count()]
		)


func _apply_ui_scale() -> void:
	var ui_scale := scale_factor
	var stored := Database.get_setting(DbConstants.SETTING_UI_SCALE, "")
	if not stored.is_empty():
		ui_scale = float(stored)
	get_tree().root.content_scale_factor = ui_scale


func _connect_services() -> void:
	JournalService.entry_created.connect(_on_journal_changed)
	JournalService.entry_updated.connect(_on_journal_changed)
	JournalService.entry_deleted.connect(_on_journal_entry_deleted)
	TodoService.todo_created.connect(_on_todo_changed)
	TodoService.todo_updated.connect(_on_todo_changed)
	TodoService.todo_stats_changed.connect(_on_todo_stats_changed)
	TodoService.todo_reordered.connect(_refresh_todo_list_deferred)
	TodoService.todo_deleted.connect(_on_todo_deleted)
	PomodoroService.state_changed.connect(_on_pomodoro_state_changed)


func _setup_mission_status_option() -> void:
	_mission_status_option.clear()
	_mission_status_option.add_item("Pending", 0)
	_mission_status_option.set_item_metadata(0, DbConstants.TODO_PENDING)
	_mission_status_option.add_item("In progress", 1)
	_mission_status_option.set_item_metadata(1, DbConstants.TODO_IN_PROGRESS)
	_mission_status_option.add_item("Done", 2)
	_mission_status_option.set_item_metadata(2, DbConstants.TODO_DONE)
	_mission_status_option.add_item("Cancelled", 3)
	_mission_status_option.set_item_metadata(3, DbConstants.TODO_CANCELLED)
	_mission_title_field.text_submitted.connect(_on_mission_title_submitted)


func _on_journal_changed(_entry: JournalEntry) -> void:
	_refresh_journal_list_deferred()


func _on_journal_entry_deleted(entry_id: int) -> void:
	if _editing_entry != null and _editing_entry.id == entry_id:
		_close_composer()
	_refresh_journal_list_deferred()


func _on_todo_changed(_item: TodoItem) -> void:
	_refresh_todo_list_deferred()


func _on_todo_stats_changed() -> void:
	_update_todo_progress(TodoService.list_todos())


func _on_todo_deleted(todo_id: int) -> void:
	if _editing_todo != null and _editing_todo.id == todo_id:
		_close_mission_composer()
	if PomodoroService.has_active_todo_session() and PomodoroService.active_target_id == todo_id:
		PomodoroService.stop(false)
	_refresh_todo_list_deferred()


func _on_pomodoro_state_changed() -> void:
	_update_mission_pomodoro_target()
	_apply_todo_pomodoro_highlights()


func _refresh_journal_list_deferred() -> void:
	call_deferred("_refresh_journal_list")


func _refresh_todo_list_deferred() -> void:
	call_deferred("_refresh_todo_list")


func _on_new_todo_pressed() -> void:
	_reset_mission_composer()
	_show_mission_composer()
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
	_mission_status_option.select(0)
	_mission_save_button.text = "Save mission"
	_mission_delete_button.visible = false
	_mission_cancel_button.visible = true


func _load_todo_into_mission_composer(item: TodoItem) -> void:
	_show_mission_composer()
	_editing_todo = item
	_mission_title_field.text = item.title
	_mission_notes_field.text = item.notes
	_select_mission_status(item.status)
	_mission_save_button.text = "Save changes"
	_mission_delete_button.visible = true
	_mission_cancel_button.visible = true
	_mission_title_field.grab_focus()


func _select_mission_status(status: String) -> void:
	for i in _mission_status_option.item_count:
		if _mission_status_option.get_item_metadata(i) == status:
			_mission_status_option.select(i)
			return
	_mission_status_option.select(0)


func _selected_mission_status() -> String:
	var idx := _mission_status_option.selected
	return str(_mission_status_option.get_item_metadata(idx))


func _on_mission_cancel_pressed() -> void:
	_close_mission_composer()


func _on_mission_title_submitted(_new_text: String) -> void:
	_try_save_mission()


func _on_mission_save_pressed() -> void:
	_try_save_mission()


func _try_save_mission() -> bool:
	var todo_title := _mission_title_field.text.strip_edges()
	if todo_title.is_empty():
		return false
	var todo_notes := _mission_notes_field.text.strip_edges()
	var todo_status := _selected_mission_status()
	if _editing_todo == null:
		var created := TodoService.create_todo(todo_title, todo_notes, todo_status)
		if created:
			_close_mission_composer()
			_update_mission_pomodoro_target()
			return true
		return false
	_editing_todo.title = todo_title
	_editing_todo.notes = todo_notes
	_editing_todo.status = todo_status
	TodoService.save_todo(_editing_todo)
	return true


func _on_mission_delete_pressed() -> void:
	if _editing_todo == null:
		return
	TodoService.delete_todo(_editing_todo.id)


func _on_new_journal_pressed() -> void:
	_reset_composer()
	_show_composer()
	_composer_field.grab_focus()


func _show_composer() -> void:
	_composer_panel.visible = true
	_update_journal_pomodoro_target()


func _hide_composer() -> void:
	_composer_panel.visible = false
	_journal_pomodoro.bind(DbConstants.TARGET_NONE, 0, false)


func _close_composer(stop_timer: bool = true) -> void:
	if stop_timer:
		PomodoroService.stop_if_journal()
	_hide_composer()
	_reset_composer()


func _reset_composer() -> void:
	_editing_entry = null
	_composer_field.text = ""
	_composer_timestamps.text = "New entry — timestamps are set when you save."
	_composer_save_button.text = "Save entry"
	_composer_delete_button.visible = false
	_composer_cancel_button.visible = true


func _load_entry_into_composer(entry: JournalEntry) -> void:
	_show_composer()
	_editing_entry = entry
	_composer_field.text = entry.body
	_composer_timestamps.text = TimeFormat.format_journal_timestamps(
		entry.created_at,
		entry.updated_at
	)
	_composer_save_button.text = "Save changes"
	_composer_delete_button.visible = true
	_composer_cancel_button.visible = true
	_composer_field.grab_focus()
	_update_journal_pomodoro_target()


func _update_journal_pomodoro_target() -> void:
	if not _composer_panel.visible:
		_journal_pomodoro.bind(DbConstants.TARGET_NONE, 0, false)
		return
	var entry_id := _editing_entry.id if _editing_entry != null else 0
	_journal_pomodoro.bind(DbConstants.TARGET_JOURNAL, entry_id, true)


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


func _apply_todo_pomodoro_highlights() -> void:
	var focus_id := 0
	if PomodoroService.has_active_todo_session() and PomodoroService.is_running:
		focus_id = PomodoroService.active_target_id
	for child in _todo_vbox.get_children():
		if child == _todo_empty_label:
			continue
		if child is TodoRow:
			var row := child as TodoRow
			row.set_pomodoro_focus(row.item != null and row.item.id == focus_id)


func _on_composer_cancel_pressed() -> void:
	_close_composer()


func _on_composer_save_pressed() -> void:
	var body := _composer_field.text.strip_edges()
	if body.is_empty():
		return
	if _editing_entry == null:
		var created := JournalService.create_entry(body)
		if created:
			PomodoroService.attach_target(DbConstants.TARGET_JOURNAL, created.id)
			_close_composer(false)
	else:
		_editing_entry.body = body
		JournalService.save_entry(_editing_entry)


func _on_composer_delete_pressed() -> void:
	if _editing_entry == null:
		return
	JournalService.delete_entry(_editing_entry.id)


func _refresh_journal_list() -> void:
	_clear_vbox(_journal_vbox, _journal_empty_label)
	var entries := JournalService.list_entries()
	_journal_empty_label.visible = entries.is_empty()
	for entry in entries:
		var row: JournalEntryRow = JOURNAL_ROW_SCENE.instantiate()
		_journal_vbox.add_child(row)
		row.edit_requested.connect(_on_journal_edit_requested)
		row.delete_requested.connect(_on_journal_delete_requested)
		row.setup(entry)
	_update_gamification_placeholders()


func _refresh_todo_list() -> void:
	_clear_vbox(_todo_vbox, _todo_empty_label)
	var items := TodoService.list_todos()
	_todo_empty_label.visible = items.is_empty()
	for item in items:
		var row: TodoRow = TODO_ROW_SCENE.instantiate()
		_todo_vbox.add_child(row)
		row.edit_requested.connect(_on_todo_edit_requested)
		row.delete_requested.connect(_on_todo_delete_requested)
		row.reorder_requested.connect(_on_todo_reorder_requested)
		row.setup(item)
	_update_todo_progress(items)
	_update_mission_pomodoro_target()
	_apply_todo_pomodoro_highlights()


func _update_gamification_placeholders() -> void:
	var entry_count := JournalService.get_entry_count()
	_entry_count_label.text = "%d %s" % [entry_count, "entry" if entry_count == 1 else "entries"]
	_xp_label.text = "XP %d" % entry_count


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


func _clear_vbox(vbox: VBoxContainer, keep_node: Control) -> void:
	var to_remove: Array[Node] = []
	for child in vbox.get_children():
		if child != keep_node:
			to_remove.append(child)
	for child in to_remove:
		child.queue_free()


func _on_journal_edit_requested(entry: JournalEntry) -> void:
	_load_entry_into_composer(entry)


func _on_journal_delete_requested(entry_id: int) -> void:
	JournalService.delete_entry(entry_id)


func _on_todo_reorder_requested(dragged_id: int, target_id: int, insert_before: bool) -> void:
	TodoService.move_todo_relative_to(dragged_id, target_id, insert_before)


func _on_todo_edit_requested(item: TodoItem) -> void:
	_load_todo_into_mission_composer(item)


func _on_todo_delete_requested(todo_id: int) -> void:
	TodoService.delete_todo(todo_id)
