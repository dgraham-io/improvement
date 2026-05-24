## Journal timeline, inline composer, and header stats.
class_name JournalArea
extends VBoxContainer

const JOURNAL_ROW_SCENE := preload("res://scenes/journal/journal_entry_row.tscn")
const JOURNAL_DAILY_METRICS_SCENE := preload("res://scenes/journal/journal_daily_metrics_row.tscn")
const _TimelineLayout := preload("res://scripts/journal/journal_timeline_layout.gd")
const _VBoxListUtil := preload("res://scripts/ui/vbox_list_util.gd")

var _editing_entry: JournalEntry = null

@onready var _entry_count_label: Label = %EntryCountLabel
@onready var _xp_label: Label = %XpLabel
@onready var _new_journal_button: Button = %NewJournalButton
@onready var _composer_panel: PanelContainer = %ComposerPanel
@onready var _composer_field: TextEdit = %ComposerField
@onready var _composer_tag_picker: TagPicker = %ComposerTagPicker
@onready var _composer_timestamps: Label = %ComposerTimestamps
@onready var _composer_save_button: Button = %ComposerSaveButton
@onready var _composer_delete_button: Button = %ComposerDeleteButton
@onready var _composer_cancel_button: Button = %ComposerCancelButton
@onready var _journal_pomodoro: PomodoroTimerWidget = %JournalPomodoro
@onready var _journal_vbox: VBoxContainer = %JournalEntriesVBox
@onready var _journal_empty_label: Label = %JournalEmptyLabel


func initialize() -> void:
	_connect_ui()
	_connect_services()
	_close_composer()
	refresh_list()


func _connect_ui() -> void:
	_new_journal_button.pressed.connect(_on_new_journal_pressed)
	_composer_cancel_button.pressed.connect(_on_composer_cancel_pressed)
	_composer_delete_button.pressed.connect(_on_composer_delete_pressed)
	_composer_save_button.pressed.connect(_on_composer_save_pressed)


func _connect_services() -> void:
	JournalService.entry_created.connect(_on_journal_service_changed)
	JournalService.entry_updated.connect(_on_journal_service_changed)
	JournalService.entry_deleted.connect(_on_journal_entry_deleted)
	TagService.entry_tags_changed.connect(_on_entry_tags_changed)


func refresh_list_deferred() -> void:
	call_deferred("refresh_list")


func refresh_list() -> void:
	_VBoxListUtil.clear_children_except(_journal_vbox, _journal_empty_label)
	var entries := JournalService.list_entries()
	var tags_map := TagService.get_entry_tags_map()
	_journal_empty_label.visible = entries.is_empty()
	if entries.is_empty():
		_update_header_stats()
		return
	for block in _TimelineLayout.build_day_blocks(entries):
		var day_start: int = block["day_start"]
		var day_entries: Array = block["entries"]
		for entry in day_entries:
			var row: JournalEntryRow = JOURNAL_ROW_SCENE.instantiate()
			_journal_vbox.add_child(row)
			row.edit_requested.connect(_on_journal_edit_requested)
			var entry_tags: Array = tags_map.get(entry.id, [])
			row.setup(entry, entry_tags)
		var metrics: JournalDailyMetricsRow = JOURNAL_DAILY_METRICS_SCENE.instantiate()
		_journal_vbox.add_child(metrics)
		metrics.setup(PomodoroService.get_daily_work_stats(day_start))
	_update_header_stats()


func _update_header_stats() -> void:
	var entry_count := JournalService.get_entry_count()
	_entry_count_label.text = "%d %s" % [entry_count, "entry" if entry_count == 1 else "entries"]
	_xp_label.text = "XP %d" % entry_count


func _on_journal_service_changed(_entry: JournalEntry) -> void:
	refresh_list_deferred()


func _on_journal_entry_deleted(entry_id: int) -> void:
	if _editing_entry != null and _editing_entry.id == entry_id:
		_close_composer()
	refresh_list_deferred()


func _on_entry_tags_changed(_entry_id: int) -> void:
	refresh_list_deferred()


func _on_new_journal_pressed() -> void:
	_reset_composer()
	_show_composer()
	_composer_tag_picker.refresh()
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
	_composer_tag_picker.clear()
	_composer_tag_picker.refresh()
	_composer_timestamps.text = "New entry — timestamps are set when you save."
	_composer_save_button.text = "Save"
	_composer_delete_button.visible = false
	_composer_cancel_button.visible = true


func _load_entry_into_composer(entry: JournalEntry) -> void:
	_show_composer()
	_editing_entry = entry
	_composer_field.text = entry.body
	_composer_tag_picker.refresh()
	_composer_tag_picker.set_selected_tags(TagService.get_tags_for_entry(entry.id))
	_composer_timestamps.text = TimeFormat.format_journal_timestamps(
		entry.created_at,
		entry.updated_at
	)
	_composer_save_button.text = "Save"
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


func _on_composer_cancel_pressed() -> void:
	_close_composer()


func _on_composer_save_pressed() -> void:
	var body := _composer_field.text.strip_edges()
	if body.is_empty():
		return
	var tag_ids := _composer_tag_picker.get_selected_tag_ids()
	if _editing_entry == null:
		var created := JournalService.create_entry(body)
		if created:
			TagService.set_entry_tags(created.id, tag_ids)
			PomodoroService.attach_target(DbConstants.TARGET_JOURNAL, created.id)
			_close_composer(false)
	else:
		_editing_entry.body = body
		if JournalService.save_entry(_editing_entry):
			TagService.set_entry_tags(_editing_entry.id, tag_ids)


func _on_composer_delete_pressed() -> void:
	if _editing_entry == null:
		return
	JournalService.delete_entry(_editing_entry.id)


func _on_journal_edit_requested(entry: JournalEntry) -> void:
	_load_entry_into_composer(entry)
