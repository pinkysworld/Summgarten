extends Node
## Thirst, watering, growth and the help bubbles.
## godot --path . --windowed res://tests/water.tscn -- <outdir>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._clear_garden()
	for i in 4:
		main.bed_data[i] = {"preset": i * 3, "water": 0.1 if i % 2 == 0 else 0.9}
		main._spawn(i, null, false)
	var n: int = main._help_items().size()
	main._help_all = main.HELP_STEP * n - 1.0 # first bubble of the tour
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png(out.path_join("water_help.png"))
	main._help_all = main.HELP_STEP * 2 - 1.3 # the watering can bubble
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png(out.path_join("water_help_can.png"))
	main._help_all = 0.0
	var before: float = main.beds[1].scale.x
	main._press_at(main.CAN_HOME + Vector2(10, -35))
	assert(main._can_held)
	main._press_at(main.BED_POSITIONS[0] + Vector2(0, -40))
	await get_tree().create_timer(0.35).timeout
	get_viewport().get_texture().get_image().save_png(out.path_join("water_pour.png"))
	main._press_at(main.BED_POSITIONS[1] + Vector2(0, -40))
	await get_tree().create_timer(1.6).timeout
	get_viewport().get_texture().get_image().save_png(out.path_join("water_after.png"))
	var ok: bool = main.beds[0].thirst < 0.05 and main.beds[1].scale.x > before
	main._press_at(Vector2(640, 300))
	print("WATER_OK" if ok and not main._can_held else "WATER_FAIL", " grew ", before, "->", main.beds[1].scale.x)
	main._clear_garden()
	get_tree().quit()
