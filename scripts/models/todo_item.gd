## Domain model for one task (maps to todos).
class_name TodoItem
extends Resource

const _DbRow := preload("res://scripts/database/db_row.gd")

@export var id: int = 0
@export var created_at: int = 0
@export var updated_at: int = 0
@export var title: String = ""
@export var notes: String = ""
@export var status: String = DbConstants.TODO_PENDING
@export var priority: int = 0
@export var due_at: int = 0
@export var sort_order: int = 0
@export var journal_entry_id: int = 0
@export var deleted_at: int = 0


func is_deleted() -> bool:
	return deleted_at > 0


func is_done() -> bool:
	return status == DbConstants.TODO_DONE


static func from_row(row: Dictionary) -> TodoItem:
	var item := TodoItem.new()
	item.id = _DbRow.int_value(row.get("id"))
	item.created_at = _DbRow.int_value(row.get("created_at"))
	item.updated_at = _DbRow.int_value(row.get("updated_at"))
	item.title = _DbRow.string_value(row.get("title"))
	item.notes = _DbRow.string_value(row.get("notes"))
	item.status = _DbRow.string_value(row.get("status"), DbConstants.TODO_PENDING)
	item.priority = _DbRow.int_value(row.get("priority"))
	item.due_at = _DbRow.int_value(row.get("due_at"))
	item.sort_order = _DbRow.int_value(row.get("sort_order"))
	item.journal_entry_id = _DbRow.int_value(row.get("journal_entry_id"))
	item.deleted_at = _DbRow.int_value(row.get("deleted_at"))
	return item
