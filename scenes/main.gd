## Main shell: hosts journal and task panels, applies global UI scale.
extends Control

@onready var _journal_area: JournalArea = %JournalArea
@onready var _task_sidebar = %TaskSidebar
@onready var _settings_button: Button = %SettingsButton


func _ready() -> void:
	if not Database.is_ready:
		await Database.ready_changed
	if not Database.is_ready:
		return
	UiScaleSettings.apply_to_viewport(get_tree())
	_journal_area.initialize()
	_task_sidebar.initialize()
	PomodoroService.session_ended.connect(_on_pomodoro_session_ended)
	Database.other_instance_detected.connect(_on_other_instance_detected)
	Database.existing_database_detected.connect(_on_existing_database_detected)
	_settings_button.pressed.connect(_on_settings_pressed)

	if OS.is_debug_build():
		var scale_info: Dictionary = UiScaleSettings.resolve()
		print(
			"UI Scale: %.2f  (source: %s)"
			% [scale_info.get("scale", 1.0), scale_info.get("source", "")]
		)
		print(
			"Improvement ready — journal: %d, tasks: %d"
			% [JournalService.get_entry_count(), TaskService.get_task_count()]
		)
		_log_other_instance_status()


func _on_pomodoro_session_ended(target_type: String, target_id: int, _completed: bool) -> void:
	_task_sidebar.on_pomodoro_session_ended(target_type, target_id)
	_journal_area.refresh_list_deferred()


func _on_other_instance_detected(machine_path: String, last_heartbeat_at: int) -> void:
	if OS.is_debug_build():
		print("Other Improvement instance detected — path: %s (last heartbeat: %d)" % [machine_path, last_heartbeat_at])


func _log_other_instance_status() -> void:
	var info: Dictionary = Database.get_other_instance_info()
	if info.get("active", false):
		print("Other instance status: ACTIVE on %s (seen %s sec ago, session %s)" % [
			info.get("machine_path", "?"),
			info.get("seconds_ago", -1),
			info.get("session", "")
		])
	else:
		print("Other instance status: none (or same machine)")


func _on_existing_database_detected(db_path: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Existing Database Detected"
	dialog.dialog_text = (
		"An existing Improvement database was found at:\n\n" +
		db_path + "\n\n" +
		"Your journal entries, tasks, pomodoros, and history will be used.\n" +
		"No data will be overwritten or lost.\n\n" +
		"(Safe to use with Dropbox-synced folders.)"
	)
	dialog.ok_button_text = "Continue"
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


func _on_settings_pressed() -> void:
	const SettingsDialogScene := preload("res://scenes/ui/settings_dialog.tscn")
	var dialog := SettingsDialogScene.instantiate()
	get_tree().root.add_child(dialog)
	dialog.settings_applied.connect(_on_settings_applied)
	dialog.closed.connect(func(): pass)  # dialog cleans itself up


func _on_settings_applied() -> void:
	UiScaleSettings.apply_to_viewport(get_tree())
	if OS.is_debug_build():
		var scale_info: Dictionary = UiScaleSettings.resolve()
		print(
			"UI Scale: %.2f  (source: %s)"
			% [scale_info.get("scale", 1.0), scale_info.get("source", "")]
		)
