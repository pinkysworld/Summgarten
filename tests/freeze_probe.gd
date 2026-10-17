extends Node
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	for k in 8:
		await get_tree().create_timer(2.0).timeout
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png(out + "/f%d.png" % k)
		print("FRAME ", k, " ", img.get_pixel(640, 120), " ", Engine.get_frames_drawn())
	get_tree().quit()
