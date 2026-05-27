## GUT tests for task save logic (validation paths without autoload DB).
extends GutTest

const TaskComposerLogic := preload("res://scripts/tasks/task_composer_logic.gd")


func test_try_save_rejects_empty_title() -> void:
	var result: TaskComposerLogic.SaveResult = TaskComposerLogic.try_save(
		null, "   ", "", DbConstants.TASK_PENDING
	)
	assert_false(result.ok)
	assert_false(result.created)
