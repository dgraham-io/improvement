## User-visible error dialogs for failed saves and API operations.
class_name AppMessage
extends RefCounted


static func show_error(owner: Node, title: String, message: String) -> void:
	if owner == null or message.is_empty():
		return
	var tree := owner.get_tree()
	if tree == null or tree.root == null:
		return
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = "OK"
	tree.root.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


static func show_save_failed(owner: Node, what: String) -> void:
	var detail := Database.get_last_error()
	var message := "Could not save %s." % what
	if not detail.is_empty():
		message += "\n\n%s" % detail
	show_error(owner, "Save failed", message)


static func show_delete_failed(owner: Node, what: String) -> void:
	var detail := Database.get_last_error()
	var message := "Could not delete %s." % what
	if not detail.is_empty():
		message += "\n\n%s" % detail
	show_error(owner, "Delete failed", message)
