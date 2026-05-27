## Clears a VBoxContainer list while keeping one sentinel node (e.g. empty label).
class_name VBoxListUtil
extends RefCounted


static func clear_children_except(vbox: VBoxContainer, keep_node: Control) -> void:
	clear_children_except_many(vbox, [keep_node] if keep_node != null else [])


static func clear_children_except_many(vbox: VBoxContainer, keep_nodes: Array) -> void:
	if vbox == null:
		return
	var to_remove: Array[Node] = []
	for child in vbox.get_children():
		if child not in keep_nodes:
			to_remove.append(child)
	for child in to_remove:
		child.queue_free()
