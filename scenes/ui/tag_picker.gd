## Dropdown + create field for optional tags on journal entries and missions.
class_name TagPicker
extends VBoxContainer

const _TagNames := preload("res://scripts/tags/tag_names.gd")

var _selected: Dictionary = {}
var _available: Array[Tag] = []

@onready var _selected_row: HBoxContainer = %SelectedTagsRow
@onready var _tag_option: OptionButton = %TagOption
@onready var _new_tag_field: LineEdit = %NewTagField
@onready var _add_tag_button: Button = %AddTagButton


func _ready() -> void:
	_tag_option.item_selected.connect(_on_tag_option_selected)
	_add_tag_button.pressed.connect(_on_add_tag_pressed)
	_new_tag_field.text_submitted.connect(_on_new_tag_submitted)
	refresh()


func refresh() -> void:
	_available = TagService.list_tags()
	_rebuild_option_menu()
	_rebuild_selected_chips()


func clear() -> void:
	_selected.clear()
	_new_tag_field.text = ""
	_tag_option.select(0)
	_rebuild_selected_chips()
	_rebuild_option_menu()


func set_selected_tags(tags: Array) -> void:
	_selected.clear()
	for tag in tags:
		if tag is Tag and tag.id > 0:
			_selected[tag.id] = tag
	_rebuild_selected_chips()
	_rebuild_option_menu()


func get_selected_tag_ids() -> Array[int]:
	var ids: Array[int] = []
	for tag_id in _selected.keys():
		ids.append(int(tag_id))
	ids.sort()
	return ids


func _rebuild_option_menu() -> void:
	_tag_option.clear()
	_tag_option.add_item("Select tag…", 0)
	for tag in _available:
		if _selected.has(tag.id):
			continue
		_tag_option.add_item(tag.name, tag.id)
	_tag_option.select(0)


func _rebuild_selected_chips() -> void:
	for child in _selected_row.get_children():
		child.queue_free()
	_selected_row.visible = not _selected.is_empty()
	var sorted_tags: Array[Tag] = []
	for tag in _selected.values():
		sorted_tags.append(tag)
	sorted_tags.sort_custom(func(a: Tag, b: Tag) -> bool:
		return a.name.nocasecmp_to(b.name) < 0
	)
	for tag in sorted_tags:
		var chip := Button.new()
		chip.text = "%s  ×" % tag.name
		chip.theme_type_variation = &"Button_ghost"
		chip.focus_mode = Control.FOCUS_NONE
		chip.pressed.connect(_on_chip_remove.bind(tag.id))
		_selected_row.add_child(chip)


func _on_tag_option_selected(index: int) -> void:
	if index <= 0:
		return
	var tag_id := _tag_option.get_item_id(index)
	if tag_id <= 0:
		_tag_option.select(0)
		return
	_add_tag_by_id(tag_id)
	_tag_option.select(0)


func _on_add_tag_pressed() -> void:
	_try_add_new_tag(_new_tag_field.text)


func _on_new_tag_submitted(new_text: String) -> void:
	_try_add_new_tag(new_text)


func _try_add_new_tag(raw_name: String) -> void:
	if not _TagNames.is_valid(raw_name):
		return
	var tag := TagService.find_or_create(raw_name)
	if tag == null:
		return
	_new_tag_field.text = ""
	_add_tag(tag)
	refresh()


func _add_tag_by_id(tag_id: int) -> void:
	for tag in _available:
		if tag.id == tag_id:
			_add_tag(tag)
			_rebuild_option_menu()
			return
	var tag := TagService.get_tag(tag_id)
	if tag != null:
		_add_tag(tag)
		refresh()


func _add_tag(tag: Tag) -> void:
	if tag == null or tag.id <= 0 or _selected.has(tag.id):
		return
	_selected[tag.id] = tag
	_rebuild_selected_chips()
	_rebuild_option_menu()


func _on_chip_remove(tag_id: int) -> void:
	_selected.erase(tag_id)
	_rebuild_selected_chips()
	_rebuild_option_menu()
