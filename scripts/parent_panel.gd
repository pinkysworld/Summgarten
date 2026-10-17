extends CanvasLayer
## Parent area behind a parent gate (a multiplication task adults can solve).

signal changed(settings: Dictionary)
signal delete_recordings
signal clear_garden

var settings := {}
var exporter: Callable ## returns the saved file path or ""
var _box: VBoxContainer
var _answer := 0


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

	var mic := CheckButton.new()
	mic.text = "Mikrofon verwenden"
	mic.add_theme_font_size_override("font_size", 20)
	for state in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		mic.add_theme_color_override(state, Color("2b2340"))
	mic.button_pressed = settings.mic
	mic.toggled.connect(func(on):
		settings.mic = on
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

	var del := _button("Alle Aufnahmen löschen", func(): pass)
	del.pressed.connect(func():
		if del.text.begins_with("Wirklich"):
			delete_recordings.emit()
			del.text = "Aufnahmen gelöscht ✓"
			del.disabled = true
		else:
			del.text = "Wirklich alle Aufnahmen löschen?")
	var clr := _button("Garten neu beginnen", func(): pass)
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
