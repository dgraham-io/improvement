## Persists OS window size (and position) to app_settings for exported/desktop runs.
extends Node

const _WindowLayoutLogic := preload("res://scripts/ui/window_layout_logic.gd")

const MIN_WIDTH := 800
const MIN_HEIGHT := 600
const SAVE_DELAY_SEC := 0.4

var _save_timer: Timer
var _restoring := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not Database.is_ready:
		await Database.ready_changed
	if not Database.is_ready:
		return
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY_SEC
	_save_timer.timeout.connect(_save_window_layout)
	add_child(_save_timer)
	await get_tree().process_frame
	_restore_window_layout()
	var win := _get_root_window()
	if win == null:
		return
	win.size_changed.connect(_on_window_size_changed)
	win.close_requested.connect(_save_window_layout)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_save_window_layout()


func _get_root_window() -> Window:
	var root := get_tree().root
	return root as Window if root is Window else null


func _restore_window_layout() -> void:
	var win := _get_root_window()
	if win == null:
		return
	var width_str := Database.get_setting(DbConstants.SETTING_WINDOW_WIDTH, "")
	var height_str := Database.get_setting(DbConstants.SETTING_WINDOW_HEIGHT, "")
	if width_str.is_empty() or height_str.is_empty():
		return
	_restoring = true
	var width := maxi(MIN_WIDTH, int(width_str))
	var height := maxi(MIN_HEIGHT, int(height_str))
	var mode_str := Database.get_setting(DbConstants.SETTING_WINDOW_MODE, "")
	if not mode_str.is_empty():
		var saved_mode := int(mode_str) as Window.Mode
		win.mode = _WindowLayoutLogic.restore_mode(saved_mode)
	if win.mode == Window.MODE_WINDOWED:
		win.size = Vector2i(width, height)
		var x_str := Database.get_setting(DbConstants.SETTING_WINDOW_X, "")
		var y_str := Database.get_setting(DbConstants.SETTING_WINDOW_Y, "")
		if not x_str.is_empty() and not y_str.is_empty():
			var pos := Vector2i(int(x_str), int(y_str))
			var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			win.position = _WindowLayoutLogic.clamp_position_to_screen(pos, win.size, screen)
	_restoring = false


func _on_window_size_changed() -> void:
	if _restoring:
		return
	_save_timer.start()


func _save_window_layout() -> void:
	var win := _get_root_window()
	if win == null:
		return
	Database.set_setting(
		DbConstants.SETTING_WINDOW_MODE,
		str(_WindowLayoutLogic.persistable_mode(win.mode))
	)
	if win.mode == Window.MODE_WINDOWED:
		Database.set_setting(DbConstants.SETTING_WINDOW_WIDTH, str(win.size.x))
		Database.set_setting(DbConstants.SETTING_WINDOW_HEIGHT, str(win.size.y))
		Database.set_setting(DbConstants.SETTING_WINDOW_X, str(win.position.x))
		Database.set_setting(DbConstants.SETTING_WINDOW_Y, str(win.position.y))
