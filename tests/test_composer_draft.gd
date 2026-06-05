## GUT tests for composer draft snapshots (journal/task field bundles).
extends GutTest

const ComposerDraft := preload("res://scripts/ui/composer_draft.gd")


func test_journal_from_fields_round_trip() -> void:
	var draft: Dictionary = ComposerDraft.journal_from_fields(
		"Draft body",
		[2, 5] as Array[int],
		42,
		"timestamps",
		"Save",
		true
	)
	assert_eq(draft.get("body", ""), "Draft body")
	assert_eq(draft.get("tag_ids", []), [2, 5])
	assert_eq(int(draft.get("editing_entry_id", 0)), 42)
	assert_true(bool(draft.get("delete_visible", false)))


func test_task_from_fields_round_trip() -> void:
	var draft: Dictionary = ComposerDraft.task_from_fields(
		"Title",
		"Notes",
		[1] as Array[int],
		DbConstants.TASK_IN_PROGRESS,
		9,
		"Save",
		false
	)
	assert_eq(draft.get("title", ""), "Title")
	assert_eq(draft.get("status", ""), DbConstants.TASK_IN_PROGRESS)
	assert_eq(int(draft.get("editing_task_id", 0)), 9)
