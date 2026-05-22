## First-run overlay: pick the folder where improvement.db will live.
class_name InitialSetupDialog
extends CanvasLayer

signal directory_confirmed(db_directory: String)
signal canceled

@onready var _path_field: LineEdit = %PathField
@onready var _hint_label: Label = %HintLabel
@onready var _error_label: Label = %ErrorLabel
@onready var _folder_dialog: FileDialog = %FolderDialog


func _ready() -> void:
	_folder_dialog.dir_selected.connect(_on_folder_selected)
	var suggested := AppConfig.suggested_dropbox_directory()
	if suggested.is_empty():
		_path_field.text = AppConfig.default_local_directory()
		_hint_label.text = "Choose a folder. improvement.db will be created inside it."
	else:
		_path_field.text = suggested
		_hint_label.text = (
			"Tip: a folder under Dropbox keeps your journal in sync across devices."
		)
	_error_label.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		canceled.emit()
		get_viewport().set_input_as_handled()


func _on_browse_pressed() -> void:
	_error_label.text = ""
	var start_dir := _path_field.text.strip_edges()
	if start_dir.is_empty():
		start_dir = AppConfig.suggested_dropbox_directory()
	if start_dir.is_empty():
		start_dir = AppConfig.default_local_directory()
	_folder_dialog.current_dir = start_dir
	_folder_dialog.popup_centered(Vector2i(700, 500))


func _on_folder_selected(dir: String) -> void:
	_path_field.text = AppConfig.normalize_directory(dir)
	_error_label.text = ""


func _on_local_pressed() -> void:
	_path_field.text = AppConfig.default_local_directory()
	_error_label.text = ""


func _on_continue_pressed() -> void:
	var directory := AppConfig.normalize_directory(_path_field.text)
	var err := _validate_directory(directory)
	if not err.is_empty():
		_error_label.text = err
		return
	_error_label.text = ""
	directory_confirmed.emit(directory)
	queue_free()


func _validate_directory(directory: String) -> String:
	if directory.is_empty():
		return "Enter or browse to a folder."
	if not DirAccess.dir_exists_absolute(directory):
		var err_code := DirAccess.make_dir_recursive_absolute(directory)
		if err_code != OK:
			return "Could not create folder (error %d)." % err_code
	var probe := directory.path_join(".improvement_write_test")
	var file := FileAccess.open(probe, FileAccess.WRITE)
	if file == null:
		return "Folder is not writable. Choose another location."
	file.store_string("ok")
	file.close()
	DirAccess.remove_absolute(probe)
	return ""
