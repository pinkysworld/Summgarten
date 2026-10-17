extends Node
## Renders Steam store screenshots (1920x1080) and capsule art.
## godot --path . --resolution 1920x1080 res://tools/store_shots.tscn -- shots <outdir>
## godot --path . --resolution 1232x706 res://tools/store_shots.tscn -- capsule <outdir>

const INK := Color("2f2a4a")

var main
var out := "user://"
var _headline: Label
var _layer: CanvasLayer


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "shots"
	out = args[1] if args.size() > 1 else out
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._clear_garden()
	main.settings.mic = false
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_headline = Label.new()
	_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_headline.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_headline.offset_top = 16
	_headline.add_theme_font_size_override("font_size", 38)
	_headline.add_theme_color_override("font_color", Color.WHITE)
	_headline.add_theme_color_override("font_outline_color", INK)
	_headline.add_theme_constant_override("outline_size", 16)
	layer.add_child(_headline)
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Arial Rounded MT Bold", "Chalkboard SE", "Arial"])
	_headline.add_theme_font_override("font", sf)
	_layer = layer
	if mode == "capsule":
		await _capsule()
	else:
		await _shots()
	main._clear_garden()
	get_tree().quit()


func _preset_for(species: int) -> int:
	for i in SoundLab.PRESET_COUNT:
		if SoundLab.preset_species(i) == species:
			return i
	return 0


func _fill(species: Array) -> void:
	for i in species.size():
		if species[i] < 0:
			continue
		main.bed_data[i] = {"preset": _preset_for(species[i])}
		main._spawn(i, null, false)


func _shot(name: String, headline: String) -> void:
	_headline.text = headline
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join(name))
	print("SHOT ", name)


func _shots() -> void:
	# 1: the core idea: your voice grows a being
	_fill([0, 4, 6, -1, 3, -1])
	await get_tree().create_timer(1.0).timeout
	main.state = main.State.RECORDING
	main._rec_bed = 3
	main._rec_time = 1.4
	for f in 20:
		Audio.level = 0.75 + 0.2 * sin(f * 0.7)
		await get_tree().process_frame
	await _shot("01_stimme.png", "Deine Stimme lässt es wachsen")
	main.state = main.State.DAY
	main._rec_bed = -1
	main._clear_garden()

	# 2: concert finale with a full, varied garden
	_fill([0, 7, 4, 2, 3, 8])
	main._set_weather(main.Weather.SUN)
	await get_tree().create_timer(0.5).timeout
	for c in main.beds:
		if c:
			c.sing(0.0)
	main._fireworks()
	await get_tree().create_timer(0.75).timeout
	await _shot("03_konzert.png", "Ein Konzert aus Kinderstimmen")

	# 3: rain, then rainbow
	main.weather = main.Weather.NONE
	main._rain_amount = 0.0
	main._rainbow = 1.0
	main._clear_garden()
	_fill([5, 6, 1, 4, 8, 3])
	await get_tree().create_timer(0.6).timeout
	for c in main.beds:
		if c:
			c.celebrate_hop(randf() * 0.2)
	await get_tree().create_timer(0.2).timeout
	await _shot("04_regenbogen.png", "Sonne, Regen, Regenbogen")

	# 4: good night
	main._rainbow = 0.0
	main._go_to_sleep()
	await get_tree().create_timer(3.0).timeout
	await _shot("02_gute_nacht.png", "Gute Nacht, Garten")

	# 5: for parents
	main._wake_up()
	await get_tree().create_timer(2.0).timeout
	main._open_parent_gate()
	await get_tree().process_frame
	main._panel._show_settings()
	await get_tree().create_timer(0.3).timeout
	await _shot("05_eltern.png", "Offline · Ohne Werbung · Aufnahmen bleiben auf dem Gerät")
	main._panel.queue_free()


func _capsule() -> void:
	main.hide_ui = true
	_fill([0, 8, -1, -1, -1, -1])
	for c in main.beds:
		if c:
			c.modulate = Color(0.85, 0.88, 0.95) # supporting cast, pushed back
	await get_tree().create_timer(0.5).timeout
	# hero: a big singing beetle in front, friends either side
	var Creature := load("res://scripts/creature.gd")
	var heroes := [[3, Vector2(640, 705), 2.3]]
	for h in heroes:
		var c = Creature.new()
		c.setup(int(h[0]) / 3, int(h[0]) % 3, SoundLab.make_wav(SoundLab.preset(0).samples, 22050), 261.63)
		c.position = h[1]
		c.scale = Vector2.ONE * float(h[2])
		c.z_index = 5
		c.grow = 1.0
		main.add_child(c)
		c.sing_amp = 0.9
		for k in 3:
			c._notes.append([Vector2(randf_range(-70, 70), -c.HEIGHTS[c.species] - 20 - k * 30), Vector2(randf_range(-20, 20), -40), 0.3 + k * 0.2, c.PALETTE[c.species]])
	_headline.text = ""
	var title := Control.new()
	title.set_script(load("res://tools/title.gd"))
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 6
	title.offset_bottom = 180
	title.size_px = int(get_viewport().get_visible_rect().size.y * 0.19)
	_layer.add_child(title)
	for f in 3:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join("capsule_%dx%d.png" % [get_viewport().size.x, get_viewport().size.y]))
	print("SHOT capsule")
