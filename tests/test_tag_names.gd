## GUT tests for tag name normalization.
extends GutTest

const TagNames := preload("res://scripts/tags/tag_names.gd")


func test_normalize_trims_edges() -> void:
	assert_eq(TagNames.normalize("  Work  "), "Work")


func test_normalize_collapses_whitespace() -> void:
	assert_eq(TagNames.normalize("Side   project"), "Side project")


func test_is_valid_rejects_empty() -> void:
	assert_false(TagNames.is_valid("   "))
