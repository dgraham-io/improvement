## GUT tests for task list ordering helpers.
extends GutTest

const TaskListOrder := preload("res://scripts/tasks/task_list_order.gd")


func _make_task(id: int, status: String, sort_order: int) -> TaskItem:
	var item := TaskItem.new()
	item.id = id
	item.status = status
	item.sort_order = sort_order
	return item


func test_ordered_active_first_preserves_groups() -> void:
	var items: Array = [
		_make_task(1, DbConstants.TASK_DONE, 0),
		_make_task(2, DbConstants.TASK_PENDING, 1),
		_make_task(3, DbConstants.TASK_DONE, 2),
		_make_task(4, DbConstants.TASK_IN_PROGRESS, 3),
	]
	var ordered := TaskListOrder.ordered_active_first(items)
	assert_eq(ordered.size(), 4)
	assert_eq((ordered[0] as TaskItem).id, 2)
	assert_eq((ordered[1] as TaskItem).id, 4)
	assert_eq((ordered[2] as TaskItem).id, 1)
	assert_eq((ordered[3] as TaskItem).id, 3)


func test_apply_sort_orders_renumbers() -> void:
	var items: Array = [
		_make_task(1, DbConstants.TASK_PENDING, 5),
		_make_task(2, DbConstants.TASK_DONE, 9),
	]
	assert_true(TaskListOrder.apply_sort_orders(items))
	assert_eq(items[0].sort_order, 0)
	assert_eq(items[1].sort_order, 1)
	assert_false(TaskListOrder.apply_sort_orders(items))
