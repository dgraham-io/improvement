## Main shell: resizable journal composer and mission sidebar.
extends Control

const JOURNAL_ROW_SCENE := preload("res://scenes/journal/journal_entry_row.tscn")
const TODO_ROW_SCENE := preload("res://scenes/todos/todo_row.tscn")

@export var scale_factor: float = 1.0

var _editing_entry: JournalEntry = null

@onready var _journal_vbox: VBoxContainer = %JournalEntriesVBox
@onready var _journal_empty_label: Label = %JournalEmptyLabel
@onready var _todo_vbox: VBoxContainer = %TodoEntriesVBox
@onready var _todo_empty_label: Label = %TodoEmptyLabel
@onready var _todo_dialog: TodoItemDialog = %TodoItemDialog
@onready var _composer_field: TextEdit = %ComposerField
@onready var _composer_timestamps: Label = %ComposerTimestamps
@onready var _composer_save_button: Button = %ComposerSaveButton
@onready var _composer_delete_button: Button = %ComposerDeleteButton
@onready var _composer_new_button: Button = %ComposerNewButton
@onready var _todo_progress_bar: ProgressBar = %TodoProgressBar
@onready var _todo_progress_label: Label = %TodoProgressLabel
@onready var _entry_count_label: Label = %EntryCountLabel
@onready var _xp_label: Label = %XpLabel


func _ready() -> void:
	if not Database.is_ready:
		await Database.ready_changed
	_apply_ui_scale()
	_connect_services()
	_connect_todo_dialog()
	_reset_composer()
	_refresh_journal_list()
	_refresh_todo_list()
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
	TodoService.todo_deleted.connect(func(_id: int) -> void: _refresh_todo_list_deferred())


func _connect_todo_dialog() -> void:
	_todo_dialog.saved.connect(func(_i: TodoItem) -> void: _refresh_todo_list())
	_todo_dialog.deleted.connect(func(_id: int) -> void: _refresh_todo_list())


func _on_journal_changed(_entry: JournalEntry) -> void:
	_refresh_journal_list_deferred()


func _on_journal_entry_deleted(entry_id: int) -> void:
	if _editing_entry != null and _editing_entry.id == entry_id:
		_reset_composer()
	_refresh_journal_list_deferred()


func _on_todo_changed(_item: TodoItem) -> void:
	_refresh_todo_list_deferred()


func _refresh_journal_list_deferred() -> void:
	call_deferred("_refresh_journal_list")


func _refresh_todo_list_deferred() -> void:
	call_deferred("_refresh_todo_list")


func _on_new_todo_pressed() -> void:
	_todo_dialog.open_create()


func _reset_composer() -> void:
	_editing_entry = null
	_composer_field.text = ""
	_composer_timestamps.text = "New entry — timestamps are set when you save."
	_composer_save_button.text = "Save entry"
	_composer_delete_button.visible = false
	_composer_new_button.visible = false


func _load_entry_into_composer(entry: JournalEntry) -> void:
	_editing_entry = entry
	_composer_field.text = entry.body
	_composer_timestamps.text = TimeFormat.format_journal_timestamps(
		entry.created_at,
		entry.updated_at
	)
	_composer_save_button.text = "Save changes"
	_composer_delete_button.visible = true
	_composer_new_button.visible = true
	_composer_field.grab_focus()


func _on_composer_new_pressed() -> void:
	_reset_composer()
	_composer_field.grab_focus()


func _on_composer_save_pressed() -> void:
	var body := _composer_field.text.strip_edges()
	if body.is_empty():
		return
	if _editing_entry == null:
		var created := JournalService.create_entry(body)
		if created:
			_reset_composer()
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
		row.setup(item)
	_update_todo_progress(items)


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


func _on_todo_edit_requested(item: TodoItem) -> void:
	_todo_dialog.open_edit(item)


func _on_todo_delete_requested(todo_id: int) -> void:
	TodoService.delete_todo(todo_id)
