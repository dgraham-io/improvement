## Drag grip on a task row; starts reorder drag for the parent TaskRow.
extends Control


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	tooltip_text = "Drag to reorder (drop between tasks or at list ends)"


func _get_drag_data(at_position: Vector2) -> Variant:
	var row = _find_todo_row()
	if row == null:
		return null
	# Row enables passthrough so the list (not buttons) owns drop targeting.
	return row._get_drag_data(at_position)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var row = _find_todo_row()
	if row == null:
		return false
	# Convert handle-local coords to row-local so the row's forwarding logic works correctly.
	var handle_global := get_global_transform() * at_position
	var row_local: Vector2 = row.get_global_transform().affine_inverse() * handle_global
	return row._can_drop_data(row_local, data)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var row = _find_todo_row()
	if row == null:
		return
	var handle_global := get_global_transform() * at_position
	var row_local: Vector2 = row.get_global_transform().affine_inverse() * handle_global
	row._drop_data(row_local, data)


const _TaskRowScript := preload("res://scenes/tasks/task_row.gd")


func _find_todo_row():
	var node: Node = self
	while node != null:
		if node is Control and (node as Control).get_script() == _TaskRowScript:
			return node
		node = node.get_parent()
	return null
