## Domain model for one tag (maps to tags).
class_name Tag
extends Resource

const _DbRow := preload("res://scripts/database/db_row.gd")

@export var id: int = 0
@export var name: String = ""
@export var created_at: int = 0


static func from_row(row: Dictionary) -> Tag:
	var tag := Tag.new()
	tag.id = _DbRow.int_value(row.get("id"))
	tag.name = _DbRow.string_value(row.get("name"))
	tag.created_at = _DbRow.int_value(row.get("created_at"))
	return tag
