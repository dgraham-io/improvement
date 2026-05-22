## Drag grip on a mission row; starts reorder drag for the parent TodoRow.
extends Control


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	tooltip_text = "Drag to reorder"


func _get_drag_data(_at_position: Vector2) -> Variant:
	var row := _find_todo_row()
	if row == null:
		return null
	return row.create_drag_data()


func _find_todo_row() -> TodoRow:
	var node: Node = self
	while node != null:
		if node is TodoRow:
			return node as TodoRow
		node = node.get_parent()
	return null
