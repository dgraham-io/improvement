## Helpers for mapping SQLite row dictionaries to GDScript types.
class_name DbRow
extends RefCounted


static func int_value(value: Variant, default: int = 0) -> int:
	if value == null:
		return default
	return int(value)


static func string_value(value: Variant, default: String = "") -> String:
	if value == null:
		return default
	return str(value)
