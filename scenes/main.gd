## Main shell: hosts journal and mission panels, applies global UI scale.
extends Control

## Fixed at 1.0 until Settings UI can adjust `app_settings.ui_scale` (see docs).
const UI_SCALE := 1.0

@onready var _journal_area: JournalArea = %JournalArea
@onready var _mission_sidebar: MissionSidebar = %TodoSidebar


func _ready() -> void:
	if not Database.is_ready:
		await Database.ready_changed
	if not Database.is_ready:
		return
	_apply_ui_scale()
	_journal_area.initialize()
	_mission_sidebar.initialize()
	PomodoroService.session_ended.connect(_on_pomodoro_session_ended)
	if OS.is_debug_build():
		print(
			"Improvement ready — journal: %d, todos: %d"
			% [JournalService.get_entry_count(), TodoService.get_todo_count()]
		)


func _apply_ui_scale() -> void:
	get_tree().root.content_scale_factor = UI_SCALE


func _on_pomodoro_session_ended(target_type: String, target_id: int, _completed: bool) -> void:
	_mission_sidebar.on_pomodoro_session_ended(target_type, target_id)
	_journal_area.refresh_list_deferred()
