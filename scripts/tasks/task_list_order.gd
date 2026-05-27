## Pure helpers for task list ordering (active first, completed last).
extends RefCounted


## Returns [param items] with non-done tasks first, preserving relative order within each group.
static func ordered_active_first(items: Array) -> Array:
	var active: Array = []
	var done: Array = []
	for item in items:
		if item is TodoItem and (item as TodoItem).is_done():
			done.append(item)
		else:
			active.append(item)
	var result: Array = []
	result.append_array(active)
	result.append_array(done)
	return result


## Assigns contiguous sort_order values (0..n-1) for [param ordered_items]. Returns true if any changed.
static func apply_sort_orders(ordered_items: Array) -> bool:
	var changed := false
	for i in ordered_items.size():
		var item: TodoItem = ordered_items[i]
		if item.sort_order != i:
			item.sort_order = i
			changed = true
	return changed
