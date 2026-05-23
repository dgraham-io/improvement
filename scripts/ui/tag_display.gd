## Formats tag lists for list rows.
class_name TagDisplay
extends RefCounted


static func format_tag_names(tags: Array) -> String:
	if tags.is_empty():
		return ""
	var names: PackedStringArray = []
	for tag in tags:
		if tag is Tag and not tag.name.is_empty():
			names.append(tag.name)
	return " · ".join(names)
