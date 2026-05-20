extends Control


@export var scale_factor: float = 1.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get the system's current scale factor (1.0, 1.25, 1.5, 2.0, etc.)
	var os_scale_factor = DisplayServer.screen_get_scale()
	# Apply it to the entire UI
	get_tree().root.content_scale_factor = scale_factor
	print("HiDPI Scale Factor applied: ", scale_factor)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
