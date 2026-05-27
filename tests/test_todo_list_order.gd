## GUT tests for mission list ordering helpers.
extends GutTest

const TodoListOrder := preload("res://scripts/tasks/task_list_order.gd")


func _make_todo(id: int, status: String, sort_order: int) -> TodoItem:
	var item := TodoItem.new()
	item.id = id
	item.status = status
	item.sort_order = sort_order
	return item


func test_ordered_active_first_preserves_groups() -> void:
	var items: Array = [
		_make_todo(1, DbConstants.TASK_DONE, 0),
		_make_todo(2, DbConstants.TASK_PENDING, 1),
		_make_todo(3, DbConstants.TASK_DONE, 2),
		_make_todo(4, DbConstants.TASK_IN_PROGRESS, 3),
	]
	var ordered := TodoListOrder.ordered_active_first(items)
	assert_eq(ordered.size(), 4)
	assert_eq((ordered[0] as TodoItem).id, 2)
	assert_eq((ordered[1] as TodoItem).id, 4)
	assert_eq((ordered[2] as TodoItem).id, 1)
	assert_eq((ordered[3] as TodoItem).id, 3)


func test_apply_sort_orders_renumbers() -> void:
	var items: Array = [
		_make_todo(1, DbConstants.TASK_PENDING, 5),
		_make_todo(2, DbConstants.TASK_DONE, 9),
	]
	assert_true(TodoListOrder.apply_sort_orders(items))
	assert_eq(items[0].sort_order, 0)
	assert_eq(items[1].sort_order, 1)
	assert_false(TodoListOrder.apply_sort_orders(items))
