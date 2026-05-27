## Mission list drop target: insert between rows or at the top/bottom of the list.
class_name TodoListDropTarget
extends VBoxContainer

signal reorder_to_index(dragged_id: int, insert_index: int)

const _TodoReorderInsert := preload("res://scripts/todos/todo_reorder_insert.gd")
const DROP_EDGE_PADDING := 10.0
const DROP_GAP_HEIGHT := 18.0
const DROP_GAP_COLOR := Color(0.133333, 0.866667, 1, 0.22)
const GAP_CLOSE_DEBOUNCE_SEC := 0.2
const GAP_OPEN_ANIM_SEC := 0.12
const GAP_CLOSE_ANIM_SEC := 0.1

var _insert_index: int = -1
var _pending_index: int = -1
var _committed_index: int = -1
var _active_drag_id: int = -1
var _drag_anchor_y: float = 0.0
var _drop_gap: ColorRect
var _gap_tween: Tween
var _close_timer: Timer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_drop_gap = ColorRect.new()
	_drop_gap.name = "DropGapSpacer"
	_drop_gap.color = DROP_GAP_COLOR
	_drop_gap.custom_minimum_size = Vector2(0.0, 0.0)
	_drop_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_gap.visible = false
	add_child(_drop_gap)
	_close_timer = _make_debounce_timer(GAP_CLOSE_DEBOUNCE_SEC, _on_close_debounced)
	add_child(_close_timer)


func _make_debounce_timer(wait_sec: float, callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = wait_sec
	timer.timeout.connect(callback)
	return timer


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_reset_drag_tracking()
		_set_rows_reorder_drag_active(false)
		_request_gap_hide()


func clear_rows() -> void:
	for child in get_children():
		if child is TodoRow:
			child.queue_free()
	_reset_drag_tracking()
	_set_rows_reorder_drag_active(false)
	_force_hide_gap()


func _set_rows_reorder_drag_active(active: bool) -> void:
	for child in get_children():
		if child is TodoRow:
			(child as TodoRow).set_reorder_drag_active(active)


func _collect_rows() -> Array:
	var rows: Array = []
	for child in get_children():
		if child is TodoRow:
			rows.append(child)
	return rows


func _row_index_for_id(rows: Array, todo_id: int) -> int:
	for i in rows.size():
		var row := rows[i] as TodoRow
		if row != null and row.item != null and row.item.id == todo_id:
			return i
	return -1


func _resolve_insert_index(local_y: float, data: Variant) -> int:
	var rows := _collect_rows()
	var dragged_id: int = int(data.get("todo_id", 0))
	if dragged_id != _active_drag_id:
		_active_drag_id = dragged_id
		_drag_anchor_y = float(data.get("list_anchor_y", local_y))
	local_y = _clamp_local_y_for_list_top(local_y, rows)
	var dragged_row_index := _row_index_for_id(rows, dragged_id)
	return _TodoReorderInsert.insert_index_for_drag(
		local_y, rows, dragged_row_index, _drag_anchor_y, DROP_EDGE_PADDING
	)


func _clamp_local_y_for_list_top(local_y: float, rows: Array) -> float:
	if rows.is_empty():
		return local_y
	var first: Control = rows[0] as Control
	if first == null:
		return local_y
	if local_y < first.position.y:
		return first.position.y + DROP_EDGE_PADDING * 0.5
	return local_y


func _reset_drag_tracking() -> void:
	_active_drag_id = -1
	_drag_anchor_y = 0.0


func _is_valid_drag(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return int(data.get("todo_id", 0)) > 0


func handle_can_drop(at_position: Vector2, data: Variant) -> bool:
	return _can_drop_data(at_position, data)


func handle_drop(at_position: Vector2, data: Variant) -> void:
	_drop_data(at_position, data)


## Map a position in [param scroll] to list-local coordinates; below the last row counts as append.
func scroll_drop_position(scroll: ScrollContainer, at_position: Vector2) -> Vector2:
	var global_pos := scroll.get_global_transform() * at_position
	var local := get_global_transform().affine_inverse() * global_pos
	var rows := _collect_rows()
	if rows.is_empty():
		return local
	var last: Control = rows[rows.size() - 1] as Control
	var last_bottom := last.position.y + last.size.y
	if local.y > last_bottom:
		local.y = last_bottom + 1.0
	local.y = _clamp_local_y_for_list_top(local.y, rows)
	return local


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _is_valid_drag(data):
		_reset_drag_tracking()
		_request_gap_hide()
		return false
	var insert_index := _resolve_insert_index(at_position.y, data)
	_insert_index = insert_index
	_request_gap_at(insert_index)
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _is_valid_drag(data):
		return
	var dragged_id: int = int(data.get("todo_id", 0))
	var insert_index := _committed_index if _committed_index >= 0 else _resolve_insert_index(
		at_position.y, data
	)
	_reset_drag_tracking()
	_set_rows_reorder_drag_active(false)
	_request_gap_hide()
	reorder_to_index.emit(dragged_id, insert_index)


func _request_gap_at(insert_index: int) -> void:
	_close_timer.stop()
	_pending_index = insert_index
	if insert_index == _committed_index:
		return
	var rows := _collect_rows()
	if _committed_index >= 0 and _drop_gap.visible:
		_relocate_gap(insert_index, rows)
	else:
		_open_gap_at(insert_index, rows)


func _request_gap_hide() -> void:
	_pending_index = -1
	if _committed_index < 0:
		return
	_close_timer.start()


func _relocate_gap(insert_index: int, rows: Array) -> void:
	var target_index := insert_index
	_animate_gap_height(
		0.0,
		GAP_CLOSE_ANIM_SEC,
		func() -> void:
			if _pending_index == target_index and _pending_index >= 0:
				_open_gap_at(target_index, rows)
	)


func _on_close_debounced() -> void:
	if _pending_index >= 0:
		return
	_animate_gap_close()


func _open_gap_at(insert_index: int, rows: Array) -> void:
	var child_index := _child_index_for_insert(insert_index, rows)
	move_child(_drop_gap, child_index)
	_drop_gap.visible = true
	_committed_index = insert_index
	_insert_index = insert_index
	_drop_gap.custom_minimum_size.y = 0.0
	_animate_gap_height(DROP_GAP_HEIGHT, GAP_OPEN_ANIM_SEC)


func _animate_gap_close() -> void:
	_animate_gap_height(0.0, GAP_CLOSE_ANIM_SEC, func() -> void: _finish_gap_hidden())


func _finish_gap_hidden() -> void:
	_drop_gap.visible = false
	_committed_index = -1
	_insert_index = -1
	_drop_gap.custom_minimum_size.y = 0.0


func _force_hide_gap() -> void:
	_kill_gap_tween()
	_close_timer.stop()
	_pending_index = -1
	_finish_gap_hidden()


func _animate_gap_height(to_height: float, duration: float, on_complete: Callable = Callable()) -> void:
	_kill_gap_tween()
	_gap_tween = create_tween()
	_gap_tween.tween_property(
		_drop_gap, "custom_minimum_size:y", to_height, duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if on_complete.is_valid():
		_gap_tween.finished.connect(on_complete, CONNECT_ONE_SHOT)


func _kill_gap_tween() -> void:
	if _gap_tween != null and _gap_tween.is_valid():
		_gap_tween.kill()
	_gap_tween = null


func _child_index_for_insert(insert_index: int, rows: Array) -> int:
	if rows.is_empty():
		return 0
	if insert_index >= rows.size():
		return (rows[rows.size() - 1] as Node).get_index() + 1
	return (rows[insert_index] as Node).get_index()
