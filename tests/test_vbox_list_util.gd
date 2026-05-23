## GUT tests for VBox list clearing helper.
extends GutTest

const VBoxUtil := preload("res://scripts/ui/vbox_list_util.gd")

var _vbox: VBoxContainer
var _keeper: Label


func before_each() -> void:
	_vbox = VBoxContainer.new()
	_keeper = Label.new()
	_keeper.name = "Keeper"
	_vbox.add_child(_keeper)
	add_child_autofree(_vbox)
	await wait_process_frames(1)


func test_clear_children_except_removes_other_nodes() -> void:
	var extra := Label.new()
	_vbox.add_child(extra)
	await wait_process_frames(1)
	assert_eq(_vbox.get_child_count(), 2)
	VBoxUtil.clear_children_except(_vbox, _keeper)
	await wait_process_frames(1)
	assert_eq(_vbox.get_child_count(), 1)
	assert_eq(_vbox.get_child(0), _keeper)
