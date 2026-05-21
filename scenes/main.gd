## Main shell: loads journal and todo lists from SQLite services.
extends Control

const JOURNAL_ROW_SCENE := preload("res://scenes/journal/journal_entry_row.tscn")
const TODO_ROW_SCENE := preload("res://scenes/todos/todo_row.tscn")

@export var scale_factor: float = 1.0

@onready var _journal_vbox: VBoxContainer = %JournalEntriesVBox
@onready var _journal_empty_label: Label = %JournalEmptyLabel
@onready var _todo_vbox: VBoxContainer = %TodoEntriesVBox
@onready var _todo_empty_label: Label = %TodoEmptyLabel
@onready var _journal_dialog: JournalEntryDialog = %JournalEntryDialog
@onready var _todo_dialog: TodoItemDialog = %TodoItemDialog


func _ready() -> void:
	if not Database.is_ready:
		await Database.ready_changed
	_apply_ui_scale()
	_connect_services()
	_connect_dialogs()
	_refresh_journal_list()
	_refresh_todo_list()
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
	JournalService.entry_deleted.connect(func(_id: int) -> void: _refresh_journal_list())
	TodoService.todo_created.connect(_on_todo_changed)
	TodoService.todo_updated.connect(_on_todo_changed)
	TodoService.todo_deleted.connect(func(_id: int) -> void: _refresh_todo_list())


func _connect_dialogs() -> void:
	_journal_dialog.saved.connect(func(_e: JournalEntry) -> void: _refresh_journal_list())
	_journal_dialog.deleted.connect(func(_id: int) -> void: _refresh_journal_list())
	_todo_dialog.saved.connect(func(_i: TodoItem) -> void: _refresh_todo_list())
	_todo_dialog.deleted.connect(func(_id: int) -> void: _refresh_todo_list())


func _on_journal_changed(_entry: JournalEntry) -> void:
	_refresh_journal_list()


func _on_todo_changed(_item: TodoItem) -> void:
	_refresh_todo_list()


func _on_new_journal_pressed() -> void:
	_journal_dialog.open_create()


func _on_new_todo_pressed() -> void:
	_todo_dialog.open_create()


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


func _clear_vbox(vbox: VBoxContainer, keep_node: Control) -> void:
	var to_remove: Array[Node] = []
	for child in vbox.get_children():
		if child != keep_node:
			to_remove.append(child)
	for child in to_remove:
		vbox.remove_child(child)
		child.free()


func _on_journal_edit_requested(entry: JournalEntry) -> void:
	_journal_dialog.open_edit(entry)


func _on_journal_delete_requested(entry_id: int) -> void:
	JournalService.delete_entry(entry_id)


func _on_todo_edit_requested(item: TodoItem) -> void:
	_todo_dialog.open_edit(item)


func _on_todo_delete_requested(todo_id: int) -> void:
	TodoService.delete_todo(todo_id)
