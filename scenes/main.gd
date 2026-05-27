## Main shell: hosts journal and mission panels, applies global UI scale.
extends Control

@onready var _journal_area: JournalArea = %JournalArea
@onready var _mission_sidebar = %TodoSidebar
@onready var _settings_button: Button = %SettingsButton


func _ready() -> void:
	if not Database.is_ready:
		await Database.ready_changed
	if not Database.is_ready:
		return
	_apply_ui_scale()
	_journal_area.initialize()
	_mission_sidebar.initialize()
	PomodoroService.session_ended.connect(_on_pomodoro_session_ended)
	Database.other_instance_detected.connect(_on_other_instance_detected)
	Database.existing_database_detected.connect(_on_existing_database_detected)
	_settings_button.pressed.connect(_on_settings_pressed)

	if OS.is_debug_build():
		print(
			"Improvement ready — journal: %d, tasks: %d"
			% [JournalService.get_entry_count(), TaskService.get_todo_count()]
		)
		_log_other_instance_status()


func _apply_ui_scale() -> void:
	var scale := 1.0
	var source := "default"
	
	# 1. Check if the user has explicitly set a scale in settings (future Settings UI)
	var stored := Database.get_setting(DbConstants.SETTING_UI_SCALE, "")
	if not stored.is_empty():
		var parsed := stored.to_float()
		if parsed > 0.25 and abs(parsed - 1.0) > 0.01:   # treat 1.0 as "not overridden"
			scale = parsed
			source = "stored setting"
	
	# 2. If no explicit user override, run system detection with fallbacks
	if source == "default":
		var detection := UiScaleDetector.detect()
		scale = detection.scale
		source = detection.source
	
	# Safety clamp
	scale = clamp(scale, 0.5, 4.0)
	
	get_tree().root.content_scale_factor = scale
	
	if OS.is_debug_build():
		print("UI Scale: %.2f  (source: %s)" % [scale, source])
		if source == "default":
			var detection := UiScaleDetector.detect()
			print("   Raw system detection → scale: %.2f, source: %s" % [detection.scale, detection.source])




func _on_pomodoro_session_ended(target_type: String, target_id: int, _completed: bool) -> void:
	_mission_sidebar.on_pomodoro_session_ended(target_type, target_id)
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
	dialog.closed.connect(func(): pass)  # dialog cleans itself up
