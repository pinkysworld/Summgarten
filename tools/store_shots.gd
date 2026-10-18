extends Node
## Renders Steam store screenshots (1920x1080) and capsule art.
## godot --path . --resolution 1920x1080 res://tools/store_shots.tscn -- shots <outdir> [lang] [WxH]
## godot --path . --resolution 1232x706 res://tools/store_shots.tscn -- capsule <outdir>
## Headlines are translated (i18n/strings.csv); render once per store language.

const INK := Color("2f2a4a")

var main
var out := "user://"
var _headline: Label
var _layer: CanvasLayer
var _title: Control


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "shots"
	out = args[1] if args.size() > 1 else out
	DirAccess.make_dir_recursive_absolute(out)
	var lang: String = args[2] if args.size() > 2 else "de"
	# App Store sizes are taller than most screens; a borderless window may exceed them.
	if args.size() > 3:
		var wh := args[3].split("x")
		get_tree().root.borderless = true
		get_tree().root.size = Vector2i(int(wh[0]), int(wh[1]))
		await get_tree().process_frame
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._clear_garden()
	main.settings.mic = false
	main.screenshot_mode = true
	main.set_season(1)
	main.settings.lang = lang
	main._apply_language()
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
	_headline.visible = false
	_title = Control.new()
	_title.set_script(load("res://tools/title.gd"))
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 4
	_title.offset_bottom = 120
	_title.size_px = int(get_viewport().get_visible_rect().size.y * 0.075)
	_title.text = ""
	layer.add_child(_title)
	if mode == "check":
		print("STORE_TOOL_OK")
	elif mode == "capsule":
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


func _shot(name: String, headline_key: String) -> void:
	_title.text = tr(headline_key) if headline_key != "" else ""
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join(name))
	print("SHOT ", name)


func _shots() -> void:
	# 1: the core idea: your voice grows a being
	_fill([0, -1, 6, -1, -1, -1])
	await get_tree().create_timer(0.5).timeout
	main.bed_data[4] = {"preset": _preset_for(3)}
	main._spawn(4, null, true)
	await get_tree().create_timer(1.75).timeout
	main.state = main.State.RECORDING
	main._rec_bed = 1
	main._rec_time = 1.4
	for f in 20:
		Audio.level = 0.75 + 0.2 * sin(f * 0.7)
		await get_tree().process_frame
	await _shot("01_stimme.png", "HL_VOICE")
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
	await _shot("03_konzert.png", "HL_CONCERT")

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
	await _shot("04_regenbogen.png", "HL_RAINBOW")

	# 4: good night
	main._rainbow = 0.0
	main._go_to_sleep()
	await get_tree().create_timer(3.0).timeout
	await _shot("02_gute_nacht.png", "HL_NIGHT")

	# 5: for parents: three trust badges over the garden
	main._wake_up()
	await get_tree().create_timer(2.0).timeout
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.2, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	_layer.move_child(dim, 0)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	_layer.add_child(row)
	var badges := [["BADGE_OFFLINE", Color("4cc3b5")], ["BADGE_NOADS", Color("ff7a6b")], ["BADGE_PRIVATE", Color("6fa8e8")]]
	var vs := get_viewport().get_visible_rect().size
	for bd in badges:
		var card := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color("fbf6ee")
		st.set_corner_radius_all(int(vs.y * 0.04))
		st.border_color = bd[1]
		st.set_border_width_all(int(vs.y * 0.008))
		st.set_content_margin_all(vs.y * 0.03)
		card.add_theme_stylebox_override("panel", st)
		card.custom_minimum_size = Vector2(vs.x * 0.24, vs.y * 0.3)
		var l := Label.new()
		l.text = tr(bd[0])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", int(vs.y * 0.045))
		l.add_theme_color_override("font_color", Color("2f2a4a"))
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Arial Rounded MT Bold", "Arial"])
		sf.fallbacks = [load("res://fonts/NotoSansSC-Bold-subset.otf"), load("res://fonts/NotoSansJP-Bold-subset.otf")]
		l.add_theme_font_override("font", sf)
		card.add_child(l)
		row.add_child(card)
	row.position = (vs - row.get_combined_minimum_size()) / 2.0
	await get_tree().create_timer(0.3).timeout
	await _shot("07_eltern.png", "HL_PARENTS")
	row.queue_free()
	dim.queue_free()

	# 6: seasons (winter hats and snow)
	main._clear_garden()
	_fill([6, 4, 0, 1, 5, 2])
	main.set_season(3)
	await get_tree().create_timer(1.2).timeout
	await _shot("05_jahreszeiten.png", "HL_SEASONS")
	main.set_season(1)

	# 7: echo game, waiting for the child
	main._clear_garden()
	_fill([4, 6, 1, -1, 3, 8])
	await get_tree().create_timer(0.8).timeout
	for c in main.beds:
		if c:
			c.invite()
	main.beds[0].sing(0.0)
	main.beds[0].highlight()
	await get_tree().create_timer(0.35).timeout
	await _shot("06_nachsingen.png", "HL_ECHO")


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
