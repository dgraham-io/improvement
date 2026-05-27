## Pure helpers: map a Y coordinate to a list insertion index (0 = before first row).
class_name TodoReorderInsert
extends RefCounted

const MOTION_THRESHOLD := 4.0


## [param local_y] is in the same coordinate space as each row's [member Control.position].
## [param rows] must be ordered top-to-bottom. Returns 0..rows.size() (after last row).
## [param edge_padding] widens each slot (extra at list top for index 0).
static func insert_index_from_local_y(
	local_y: float, rows: Array, edge_padding: float = 0.0
) -> int:
	if rows.is_empty():
		return 0
	var pad := maxf(edge_padding, 0.0)
	var first: Control = rows[0] as Control
	if first != null and local_y < first.position.y + pad:
		return 0
	for i in rows.size():
		var row: Control = rows[i] as Control
		if row == null:
			continue
		var split_y := row.position.y + row.size.y * 0.5
		if i == 0:
			split_y += pad
		elif pad > 0.0:
			split_y += pad * 0.5
		if local_y < split_y:
			return i
	return rows.size()


## Uses a fixed [param drag_anchor_y] from drag start plus motion to avoid "gap below" when moving up.
static func insert_index_for_drag(
	local_y: float,
	rows: Array,
	dragged_row_index: int,
	drag_anchor_y: float,
	edge_padding: float = 0.0
) -> int:
	if rows.is_empty():
		return 0
	var insert_at := insert_index_from_local_y(local_y, rows, edge_padding)
	if dragged_row_index < 0:
		return insert_at
	var moving_up := local_y < drag_anchor_y - MOTION_THRESHOLD
	var moving_down := local_y > drag_anchor_y + MOTION_THRESHOLD
	if moving_up:
		return mini(insert_at, dragged_row_index)
	if moving_down:
		return maxi(insert_at, dragged_row_index + 1)

	# Neutral zone (mouse hasn't moved far enough from grab point to trigger
	# the strong moving_up/moving_down bias).
	# Use the original grab position (drag_anchor_y) as the decision point.
	# This makes small upward movements from a low grab point immediately open
	# the gap above the item, matching user intent and the final drop position.
	if dragged_row_index < rows.size():
		if local_y <= drag_anchor_y:
			return dragged_row_index
		return dragged_row_index + 1

	return insert_at


## Returns true if inserting the dragged row at [param proposed] would result in a different order.
## Used to gate visual drop feedback (gap) and actual acceptance.
static func would_change_order(dragged_row_index: int, proposed: int, row_count: int) -> bool:
	if dragged_row_index < 0:
		return true
	# These two positions are no-ops (item stays where it was)
	if proposed == dragged_row_index:
		return false
	if proposed == dragged_row_index + 1:
		return false
	if proposed < 0 or proposed > row_count:
		return false
	return true


## Y coordinate (local to [param list_container]) for a horizontal drop indicator line.
static func line_y_for_insert_index(insert_index: int, rows: Array, list_height: float) -> float:
	if rows.is_empty():
		return 0.0
	if insert_index <= 0:
		var first: Control = rows[0] as Control
		return first.position.y if first != null else 0.0
	if insert_index >= rows.size():
		var last: Control = rows[rows.size() - 1] as Control
		if last == null:
			return list_height
		return last.position.y + last.size.y
	var above: Control = rows[insert_index - 1] as Control
	var below: Control = rows[insert_index] as Control
	if above == null or below == null:
		return 0.0
	var gap_mid := (above.position.y + above.size.y + below.position.y) * 0.5
	return gap_mid
