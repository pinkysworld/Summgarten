extends Node
## Captures the studio intro with the Klanggarten preset at a few moments.
func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var intro := MinhStudioIntro.play(self, load("res://addons/minh_studio_intro/presets/klanggarten.tres"))
	for t in [0.7, 1.6, 2.2]:
		intro.seek(t)
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(out.path_join("intro_%s.png" % str(t)))
	print("INTRO_OK length=", intro.length())
	get_tree().quit()
