## GUT tests for task status OptionButton helpers.
extends GutTest

const StatusOptions := preload("res://scripts/ui/task_status_options.gd")

var _option: OptionButton


func before_each() -> void:
	_option = OptionButton.new()
	add_child_autofree(_option)
	StatusOptions.populate(_option)


func test_populate_adds_four_statuses() -> void:
	assert_eq(_option.item_count, 4)
	assert_eq(StatusOptions.selected_status(_option), DbConstants.TASK_PENDING)


func test_select_and_read_status() -> void:
	StatusOptions.select_status(_option, DbConstants.TASK_DONE)
	assert_eq(StatusOptions.selected_status(_option), DbConstants.TASK_DONE)
