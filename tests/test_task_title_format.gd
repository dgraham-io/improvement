## GUT tests for task title BBCode formatting.
extends GutTest

const TaskTitleFormat := preload("res://scripts/tasks/task_title_format.gd")


func test_display_text_strikethrough_when_done() -> void:
	assert_eq(TaskTitleFormat.display_text("Ship feature", true), "[s]Ship feature[/s]")


func test_display_text_plain_when_active() -> void:
	assert_eq(TaskTitleFormat.display_text("Ship feature", false), "Ship feature")


func test_escape_bbcode_in_title() -> void:
	assert_eq(
		TaskTitleFormat.display_text("[debug]", true),
		"[s][lb]debug[rb][/s]"
	)
