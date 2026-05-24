## Formats mission titles for list rows (BBCode strikethrough when done).
class_name TodoTitleFormat
extends RefCounted


static func escape_bbcode(text: String) -> String:
	var escaped := ""
	for character in text:
		match character:
			"[":
				escaped += "[lb]"
			"]":
				escaped += "[rb]"
			_:
				escaped += character
	return escaped


static func display_text(title: String, done: bool) -> String:
	var safe := escape_bbcode(title)
	if done:
		return "[s]%s[/s]" % safe
	return safe
