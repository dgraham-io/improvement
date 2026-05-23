## Normalizes tag names for storage and lookup.
class_name TagNames
extends RefCounted


static func normalize(raw: String) -> String:
	var collapsed := raw.strip_edges()
	while collapsed.find("  ") >= 0:
		collapsed = collapsed.replace("  ", " ")
	return collapsed


static func is_valid(raw: String) -> bool:
	return not normalize(raw).is_empty()
