## One-shot: render main scene and save a PNG for docs. Run from project root:
## godot --path . --script res://scripts/tools/capture_screenshot.gd
extends SceneTree

const OUTPUT := "res://docs/screenshots/app.png"
const WINDOW_SIZE := Vector2i(1280, 720)


func _init() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	root.add_child(scene.instantiate())
	if root is Window:
		(root as Window).size = WINDOW_SIZE
	var timer := Timer.new()
	timer.wait_time = 1.5
	timer.one_shot = true
	timer.timeout.connect(_save_and_quit)
	root.add_child(timer)
	timer.start()


func _save_and_quit() -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("Saved screenshot: ", path)
	quit()
