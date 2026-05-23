## First-run setup: choose folder for improvement.db (e.g. Dropbox) before Database opens.
extends Node

signal setup_completed(db_directory: String)

var _dialog: InitialSetupDialog = null


func _ready() -> void:
	if AppConfig.is_configured():
		return
	call_deferred("_present_setup")


func _present_setup() -> void:
	if _dialog != null:
		return
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	_dialog = preload("res://scenes/setup/initial_setup_dialog.tscn").instantiate()
	tree.root.add_child(_dialog)
	_dialog.directory_confirmed.connect(_on_directory_confirmed, CONNECT_ONE_SHOT)
	_dialog.canceled.connect(_on_canceled, CONNECT_ONE_SHOT)


func _on_directory_confirmed(db_directory: String) -> void:
	if not AppConfig.write_db_directory(db_directory):
		push_error("AppSetup: failed to save app_config.json")
		return
	_dialog = null
	setup_completed.emit(db_directory)


func _on_canceled() -> void:
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null
	call_deferred("_present_setup")


func request_open_retry(error_message: String, attempted_directory: String) -> String:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return attempted_directory
	var dialog := preload("res://scenes/setup/initial_setup_dialog.tscn").instantiate()
	dialog.configure_as_open_failure(error_message, attempted_directory)
	tree.root.add_child(dialog)
	var db_directory: String = await dialog.directory_confirmed
	return db_directory
