extends Node
## Garden at the window's aspect (iPhone is ~19.5:9).
## godot --path . --windowed --resolution 1562x720 res://tests/wide.tscn -- <outdir> <name>
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var main = load("res://scenes/main.tscn").instantiate()
	main.screenshot_mode = true
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png(args[0].path_join(args[1] + ".png"))
	get_tree().quit()
