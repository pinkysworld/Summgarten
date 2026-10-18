extends Node
## Garden toys, duets, golden beings and long-press uprooting.
## godot --path . --windowed res://tests/toys.tscn -- <outdir>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._clear_garden()
	main._help_all = 0.0
	main.screenshot_mode = true
	main.set_season(main.Season.SUMMER)
	for i in 5:
		main.bed_data[i] = {"preset": [5, 2, 0, 3, 4][i], "gold": i == 3}
		main._spawn(i, null, false)
	main._t = 115.0 # hedgehog is visiting
	await get_tree().create_timer(0.5).timeout
	main._press_at(main.MILL)
	main._press_at(main.POND + Vector2(20, 0))
	main._press_at(main.TREE_CROWN)
	var st: Vector3 = main.STONES[1]
	main._press_at(Vector2(st.x, st.y))
	main._press_at(main.BED_POSITIONS[0] + Vector2(0, -50)) # frog: snail answers
	await get_tree().create_timer(0.7).timeout
	get_viewport().get_texture().get_image().save_png(out.path_join("toys.png"))
	print("PARTS ", main._worms.size(), " ", main._apples.size(), " ", main._mill_boost)
	var ok: bool = main._worms.size() == 1 and main._apples.size() == 2 and main._mill_boost > 0.0
	# hold on a being for a while: it turns back into a seed
	main._press_at(main.BED_POSITIONS[4] + Vector2(0, -50))
	await get_tree().create_timer(3.6).timeout
	ok = ok and main.beds[4] == null and main.bed_data[4] == null
	main._set_weather(main.Weather.RAIN)
	await get_tree().create_timer(2.5).timeout
	get_viewport().get_texture().get_image().save_png(out.path_join("toys_rain.png"))
	print("TOYS_OK" if ok else "TOYS_FAIL", " worms=", main._worms.size(), " apples=", main._apples.size(), " bed4=", main.beds[4])
	main._clear_garden()
	get_tree().quit()
