extends Node
## Every language renders: help bubble + parents' area per locale.
## godot --path . --windowed res://tests/langs.tscn -- <outdir> ar th hi ko
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(0.6).timeout
	for loc in args.slice(1):
		main.settings.lang = loc
		main._apply_language()
		main._help_font = null
		main._help_all = main.HELP_STEP * main._help_items().size() - 1.0
		main._open_parent_gate()
		await get_tree().process_frame
		main._panel._show_settings()
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(out.path_join("lang_%s.png" % loc))
		main._panel._show_credits()
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png(out.path_join("credits_%s.png" % loc))
		main._panel.queue_free()
		await get_tree().process_frame
	print("LANGS_OK")
	get_tree().quit()
