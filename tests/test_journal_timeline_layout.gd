## GUT tests for journal day-block grouping.
extends GutTest

const TimeFmt := preload("res://scripts/util/time_format.gd")
const TimelineLayout := preload("res://scripts/journal/journal_timeline_layout.gd")


func test_build_day_blocks_empty() -> void:
	assert_eq(TimelineLayout.build_day_blocks([]).size(), 0)


func test_build_day_blocks_groups_two_days() -> void:
	var today := TimeFmt.local_day_start(int(Time.get_unix_time_from_system()))
	var yesterday := today - 86400
	var entries: Array[JournalEntry] = []
	var older := JournalEntry.new()
	older.id = 1
	older.created_at = yesterday + 3600
	entries.append(older)
	var newer := JournalEntry.new()
	newer.id = 2
	newer.created_at = today + 3600
	entries.append(newer)
	var blocks: Array = TimelineLayout.build_day_blocks(entries)
	assert_eq(blocks.size(), 2)
	assert_eq(blocks[0]["day_start"], yesterday)
	assert_eq(blocks[0]["entries"].size(), 1)
	assert_eq(blocks[1]["day_start"], today)
	assert_eq(blocks[1]["entries"].size(), 1)
