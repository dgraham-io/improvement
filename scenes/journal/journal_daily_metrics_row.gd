## End-of-day focus summary inserted after each day block in the journal timeline.
class_name JournalDailyMetricsRow
extends PanelContainer

const FOCUS_GOAL_SEC := 4 * 3600

@onready var _accent_dot: ColorRect = %AccentDot
@onready var _day_heading: Label = %DayHeadingLabel
@onready var _day_subtitle: Label = %DaySubtitleLabel
@onready var _focus_value: Label = %FocusValueLabel
@onready var _pomodoro_value: Label = %PomodoroValueLabel
@onready var _goal_progress: ProgressBar = %GoalProgressBar
@onready var _goal_caption: Label = %GoalCaptionLabel
@onready var _journal_value: Label = %JournalValueLabel
@onready var _tasks_value: Label = %TasksValueLabel
@onready var _sessions_value: Label = %SessionsValueLabel
@onready var _empty_hint: Label = %EmptyHintLabel
@onready var _stats_grid: GridContainer = %StatsGrid
@onready var _hourly_bars: HBoxContainer = %HourlyBars


func _ready() -> void:
	_accent_dot.color = ThemePalette.color(
		self,
		ImprovementThemeTypes.METRICS_ACCENT_DOT,
		ImprovementThemeTypes.METRICS_ROW
	)


func setup(stats: DailyWorkStats) -> void:
	_day_heading.text = TimeFormat.format_day_heading(stats.day_start_unix)
	_day_subtitle.text = TimeFormat.format_day_subtitle(stats.day_start_unix)
	_focus_value.text = TimeFormat.format_work_duration(stats.total_work_sec)
	_pomodoro_value.text = str(stats.completed_pomodoros)
	_sessions_value.text = str(stats.session_count)
	_journal_value.text = TimeFormat.format_work_duration(stats.journal_work_sec)
	_tasks_value.text = TimeFormat.format_work_duration(stats.task_work_sec)
	var has_work := stats.has_work()
	_empty_hint.visible = not has_work
	_stats_grid.visible = has_work
	_goal_progress.visible = has_work
	_goal_caption.visible = has_work
	_hourly_bars.visible = has_work
	if has_work:
		var goal_ratio := clampf(float(stats.total_work_sec) / float(FOCUS_GOAL_SEC), 0.0, 1.0)
		_goal_progress.value = goal_ratio
		_goal_caption.text = (
			"%s of %s focus goal"
			% [
				TimeFormat.format_work_duration(stats.total_work_sec),
				TimeFormat.format_work_duration(FOCUS_GOAL_SEC),
			]
		)
		_build_hourly_chart(stats.hourly_work_sec)
	else:
		_goal_progress.value = 0.0
		_clear_hourly_chart()


func _build_hourly_chart(hourly_work_sec: PackedInt32Array) -> void:
	_clear_hourly_chart()
	var peak_sec := 1
	for hour in range(24):
		if hour < hourly_work_sec.size():
			peak_sec = maxi(peak_sec, hourly_work_sec[hour])
	for hour in range(24):
		var work_sec := 0
		if hour < hourly_work_sec.size():
			work_sec = hourly_work_sec[hour]
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.alignment = BoxContainer.ALIGNMENT_END
		column.add_theme_constant_override("separation", 2)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 40)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		bar.max_value = peak_sec
		bar.step = 1.0
		bar.show_percentage = false
		bar.value = work_sec
		bar.tooltip_text = "%02d:00 — %s" % [hour, TimeFormat.format_work_duration(work_sec)]
		column.add_child(bar)
		var tick := Label.new()
		tick.text = "·" if hour % 6 != 0 else str(hour)
		tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tick.theme_type_variation = &"Label_chart_tick"
		column.add_child(tick)
		_hourly_bars.add_child(column)


func _clear_hourly_chart() -> void:
	for child in _hourly_bars.get_children():
		child.queue_free()
