## Fills and reads task status values on an OptionButton.
class_name TaskStatusOptions
extends RefCounted


static func populate(option: OptionButton) -> void:
	if option == null:
		return
	option.clear()
	option.add_item("Pending", 0)
	option.set_item_metadata(0, DbConstants.TASK_PENDING)
	option.add_item("In progress", 1)
	option.set_item_metadata(1, DbConstants.TASK_IN_PROGRESS)
	option.add_item("Done", 2)
	option.set_item_metadata(2, DbConstants.TASK_DONE)
	option.add_item("Cancelled", 3)
	option.set_item_metadata(3, DbConstants.TASK_CANCELLED)


static func select_status(option: OptionButton, status: String) -> void:
	if option == null:
		return
	for i in option.item_count:
		if option.get_item_metadata(i) == status:
			option.select(i)
			return
	option.select(0)


static func selected_status(option: OptionButton) -> String:
	if option == null or option.item_count == 0:
		return DbConstants.TASK_PENDING
	var idx := option.selected
	return str(option.get_item_metadata(idx))
