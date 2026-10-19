extends Node
func _ready() -> void:
	for t in [2.0, 12.0, 1.0]:
		await get_tree().create_timer(t).timeout
		get_viewport().get_texture().get_image().save_png("/private/tmp/claude-501/-Users-michelpicker-Developer-Klanggarten/64311891-f26e-443d-ab9e-ce6ca259b476/scratchpad/portrait_%s.png" % t)
	get_tree().quit()
