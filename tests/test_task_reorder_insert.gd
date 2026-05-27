## GUT tests for task list insertion index helpers.
extends GutTest

const TaskReorderInsert := preload("res://scripts/tasks/task_reorder_insert.gd")


func _mock_row(y: float, height: float) -> Control:
	var row := Control.new()
	row.position = Vector2(0.0, y)
	row.size = Vector2(100.0, height)
	return row


func test_insert_index_before_first_row() -> void:
	var rows: Array = [_mock_row(0.0, 40.0), _mock_row(50.0, 40.0)]
	assert_eq(TaskReorderInsert.insert_index_from_local_y(10.0, rows), 0)


func test_insert_index_between_rows() -> void:
	var rows: Array = [_mock_row(0.0, 40.0), _mock_row(50.0, 40.0)]
	assert_eq(TaskReorderInsert.insert_index_from_local_y(45.0, rows), 1)


func test_insert_index_after_last_row() -> void:
	var rows: Array = [_mock_row(0.0, 40.0), _mock_row(50.0, 40.0)]
	assert_eq(TaskReorderInsert.insert_index_from_local_y(120.0, rows), 2)


func test_line_y_at_list_ends() -> void:
	var rows: Array = [_mock_row(10.0, 30.0), _mock_row(50.0, 30.0)]
	assert_eq(TaskReorderInsert.line_y_for_insert_index(0, rows, 200.0), 10.0)
	assert_eq(TaskReorderInsert.line_y_for_insert_index(2, rows, 200.0), 80.0)


func test_drag_up_targets_slot_above_not_below() -> void:
	var rows: Array = [_mock_row(0.0, 40.0), _mock_row(50.0, 40.0)]
	assert_eq(TaskReorderInsert.insert_index_for_drag(30.0, rows, 1, 60.0, 0.0), 1)
	assert_eq(TaskReorderInsert.insert_index_for_drag(75.0, rows, 1, 60.0, 0.0), 2)


func test_top_of_list_slot() -> void:
	var rows: Array = [_mock_row(10.0, 40.0), _mock_row(60.0, 40.0)]
	assert_eq(TaskReorderInsert.insert_index_from_local_y(5.0, rows, 10.0), 0)
	assert_eq(TaskReorderInsert.insert_index_from_local_y(0.0, rows, 10.0), 0)


func test_edge_padding_makes_top_slot_easier() -> void:
	var rows: Array = [_mock_row(0.0, 40.0), _mock_row(50.0, 40.0)]
	assert_eq(TaskReorderInsert.insert_index_from_local_y(10.0, rows, 0.0), 0)
	assert_eq(TaskReorderInsert.insert_index_from_local_y(28.0, rows, 10.0), 0)
	assert_eq(TaskReorderInsert.insert_index_from_local_y(38.0, rows, 10.0), 1)


func test_would_change_order_noop_positions() -> void:
	assert_false(TaskReorderInsert.would_change_order(1, 1, 4))
	assert_false(TaskReorderInsert.would_change_order(1, 2, 4))
	assert_true(TaskReorderInsert.would_change_order(1, 0, 4))
	assert_true(TaskReorderInsert.would_change_order(1, 3, 4))
	assert_true(TaskReorderInsert.would_change_order(1, 4, 4))


func test_would_change_order_for_new_drag() -> void:
	assert_true(TaskReorderInsert.would_change_order(-1, 0, 3))
