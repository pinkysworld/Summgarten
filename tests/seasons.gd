extends Node
## Renders every season (and all nine species) for a visual check.
## godot --path . res://tests/seasons.tscn -- <outdir>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._clear_garden()
	for set_i in 2:
		var species: Array = [0, 1, 2, 3, 4, 5] if set_i == 0 else [6, 7, 8, 0, 4, 2]
		for i in species.size():
			for p in SoundLab.PRESET_COUNT:
				if SoundLab.preset_species(p) == species[i]:
					main.bed_data[i] = {"preset": p}
					break
			main._spawn(i, null, false)
		for s in 4:
			if set_i == 1 and s != 3:
				continue
			main.set_season(s)
			await get_tree().create_timer(1.2).timeout
			get_viewport().get_texture().get_image().save_png(out.path_join("season_%d_%d.png" % [set_i, s]))
		main._clear_garden()
	print("SEASONS_OK")
	get_tree().quit()
