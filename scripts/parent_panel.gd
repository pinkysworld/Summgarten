extends CanvasLayer
## Parent area behind a parent gate (a multiplication task adults can solve).

signal changed(settings: Dictionary)
signal delete_recordings
signal clear_garden

var settings := {}
var exporter: Callable ## returns the saved file path or ""
var _box: VBoxContainer
var _answer := 0


const INK := Color("2f2a4a")
const PAPER := Color("fbf6ee")
const DANGER := Color("d9534f")


func _box_style(bg: Color, radius := 12) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.set_corner_radius_all(radius)
	st.set_content_margin_all(10)
	st.content_margin_left = 18
	st.content_margin_right = 18
	return st


func _make_theme() -> Theme:
	var th := Theme.new()
	for type in ["Button", "OptionButton"]:
		th.set_stylebox("normal", type, _box_style(INK))
		th.set_stylebox("hover", type, _box_style(INK.lightened(0.15)))
		th.set_stylebox("pressed", type, _box_style(INK.darkened(0.2)))
		th.set_stylebox("disabled", type, _box_style(Color("b9b4c4")))
		th.set_stylebox("focus", type, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			th.set_color(c, type, PAPER)
		th.set_color("font_disabled_color", type, PAPER)
	var track := _box_style(Color("e3ddd2"), 8)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	th.set_stylebox("slider", "HSlider", track)
	var fill := _box_style(Color("4cc3b5"), 8)
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	for y in 28:
		for x in 28:
			var d := Vector2(x - 13.5, y - 13.5).length()
			knob.set_pixel(x, y, INK if d < 11 else (PAPER if d < 14 else Color(0, 0, 0, 0)))
	var tex := ImageTexture.create_from_image(knob)
	th.set_icon("grabber", "HSlider", tex)
	th.set_icon("grabber_highlight", "HSlider", tex)
	return th


func _ready() -> void:
	layer = 10
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fbf7ee")
	style.set_corner_radius_all(18)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	panel.theme = _make_theme()
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	panel.add_child(_box)
	_show_gate()


func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()


func _label(text: String, size := 22) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("2b2340"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func _show_gate() -> void:
	_clear()
	var a := randi_range(6, 9)
	var b := randi_range(6, 9)
	_answer = a * b
	_label("Elternbereich", 30)
	_label("Bitte lösen: %d × %d = ?" % [a, b])
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_box.add_child(row)
	var options := [_answer, _answer + randi_range(1, 5), _answer - randi_range(1, 5)]
	options.shuffle()
	for o in options:
		var btn := Button.new()
		btn.text = str(o)
		btn.custom_minimum_size = Vector2(110, 64)
		btn.add_theme_font_size_override("font_size", 26)
		btn.pressed.connect(func():
			if o == _answer:
				_show_settings()
			else:
				queue_free())
		row.add_child(btn)
	_button("Zurück zum Garten", queue_free)


func _show_settings() -> void:
	_clear()
	_label("Elternbereich", 30)

	var mic := Button.new()
	mic.toggle_mode = true
	mic.button_pressed = settings.mic
	mic.custom_minimum_size = Vector2(0, 48)
	mic.add_theme_font_size_override("font_size", 20)
	var paint_mic := func(on: bool):
		mic.text = "Mikrofon: an" if on else "Mikrofon: aus"
		var st := _box_style(Color("4cc3b5") if on else Color("b9b4c4"), 24)
		for k in ["normal", "hover", "pressed", "hover_pressed"]:
			mic.add_theme_stylebox_override(k, st)
	paint_mic.call(settings.mic)
	mic.toggled.connect(func(on):
		settings.mic = on
		paint_mic.call(on)
		changed.emit(settings))
	_box.add_child(mic)
	_label("Ohne Mikrofon wachsen Wesen mit eingebauten Klängen.", 16)

	_label("Lautstärke", 18)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = settings.volume
	vol.custom_minimum_size = Vector2(0, 36)
	vol.value_changed.connect(func(v):
		settings.volume = v
		changed.emit(settings))
	_box.add_child(vol)

	_label("Der Garten schläft ein nach", 18)
	var day := OptionButton.new()
	day.add_theme_font_size_override("font_size", 20)
	for m in [4, 6, 10]:
		day.add_item("%d Minuten" % m, m)
	day.select([4, 6, 10].find(int(settings.get("day_minutes", 6))))
	day.item_selected.connect(func(idx):
		settings.day_minutes = day.get_item_id(idx)
		changed.emit(settings))
	_box.add_child(day)

	var exp := _button("Konzert als Audiodatei speichern", func(): pass)
	var exp_info := _label("", 15)
	exp.pressed.connect(func():
		var path: String = exporter.call() if exporter.is_valid() else ""
		if path.is_empty():
			exp_info.text = "Noch keine Wesen im Garten."
		else:
			exp_info.text = "Gespeichert: " + path)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	_box.add_child(gap)
	var del := _button("Alle Aufnahmen löschen", func(): pass)
	for k in ["normal", "hover", "pressed"]:
		del.add_theme_stylebox_override(k, _box_style(DANGER if k != "hover" else DANGER.lightened(0.1)))
	del.pressed.connect(func():
		if del.text.begins_with("Wirklich"):
			delete_recordings.emit()
			del.text = "Aufnahmen gelöscht ✓"
			del.disabled = true
		else:
			del.text = "Wirklich alle Aufnahmen löschen?")
	var clr := _button("Garten neu beginnen", func(): pass)
	for k in ["normal", "hover", "pressed"]:
		clr.add_theme_stylebox_override(k, _box_style(DANGER if k != "hover" else DANGER.lightened(0.1)))
	clr.pressed.connect(func():
		if clr.text.begins_with("Wirklich"):
			clear_garden.emit()
			clr.text = "Garten ist leer ✓"
			clr.disabled = true
		else:
			clr.text = "Wirklich den ganzen Garten leeren?")

	_label("Aufnahmen bleiben nur auf diesem Gerät. Kein Upload, keine Werbung, keine Analyse.", 15)
	_label("Klanggarten %s" % ProjectSettings.get_setting("application/config/version"), 12)
	_button("Zurück zum Garten", queue_free)
