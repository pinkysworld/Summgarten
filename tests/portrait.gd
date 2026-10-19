extends Node
## Portrait check: studio intro, then the turn-the-device hint.
func _ready() -> void:
	get_tree().root.size = Vector2i(768, 1024)
	var keep := Node.new()
	keep.set_script(load("res://tests/portrait_shot.gd"))
	get_tree().root.add_child.call_deferred(keep)
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
