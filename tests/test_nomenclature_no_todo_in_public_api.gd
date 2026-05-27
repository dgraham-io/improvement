## Guard: public scripts/scenes must not reintroduce todo/mission API names.
extends GutTest

const FORBIDDEN_PATTERNS: PackedStringArray = [
	"class_name TodoItem",
	"func get_todo(",
	"func list_todos(",
	"func insert_todo(",
	"signal todo_created",
	"signal todo_tags_changed",
	"MissionStatusOptions",
	"mission_status_options.gd",
	"todo_item.gd",
]

const SCAN_DIRS: PackedStringArray = [
	"res://scripts/autoload",
	"res://scripts/tasks",
	"res://scripts/models",
	"res://scripts/ui",
	"res://scenes/tasks",
	"res://scenes/main.gd",
]


func test_no_forbidden_todo_identifiers_in_public_code() -> void:
	for dir_path in SCAN_DIRS:
		_scan_dir(dir_path)


func _scan_dir(path: String) -> void:
	var abs := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(abs):
		return
	var stack: Array[String] = [abs]
	while not stack.is_empty():
		var current: String = stack.pop_back()
		var dir := DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name != "." and name != "..":
				var full: String = current.path_join(name)
				if dir.current_is_dir():
					stack.append(full)
				elif name.ends_with(".gd"):
					_check_file(full)
			name = dir.get_next()
		dir.list_dir_end()


func _check_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	for pattern in FORBIDDEN_PATTERNS:
		assert_false(
			text.contains(pattern),
			"%s must not contain '%s'" % [path, pattern]
		)
