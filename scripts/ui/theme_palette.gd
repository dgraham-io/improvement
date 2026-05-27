## Read semantic colors from the active Improvement theme.
class_name ThemePalette
extends RefCounted


static func color(node: Control, key: StringName, theme_type: StringName) -> Color:
	return node.get_theme_color(key, theme_type)
