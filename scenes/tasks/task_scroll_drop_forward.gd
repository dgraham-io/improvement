## Forwards drag-and-drop from the scroll viewport to the task list (including below rows).
extends ScrollContainer

@onready var _list = $TaskEntriesVBox


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return _list.handle_can_drop(_list.scroll_drop_position(self, at_position), data)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	_list.handle_drop(_list.scroll_drop_position(self, at_position), data)
