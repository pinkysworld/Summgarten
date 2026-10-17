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
const LANGS := [["", "Auto"], ["de", "Deutsch"], ["en", "English"], ["zh_CN", "简体中文"], ["fr", "Français"],
	["es", "Español"], ["pt_BR", "Português (Brasil)"], ["ja", "日本語"], ["ru", "Русский"], ["pl", "Polski"]]


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
	panel.custom_minimum_size = Vector2(580, 0)
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
	_label(tr("PARENTS"), 30)
	_label(tr("GATE_Q") % [a, b])
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
	_button(tr("BACK"), queue_free)


func _card() -> VBoxContainer:
	var card := PanelContainer.new()
	var st := _box_style(Color("f1e9dc"), 16)
	st.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", st)
	_box.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	return v


func _link(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", 17)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color("b04a4a"))
	b.add_theme_color_override("font_disabled_color", Color("7a7488"))
	var empty := StyleBoxEmpty.new()
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, empty)
	_box.add_child(b)
	return b


func _confirming(b: Button, ask: String, done: String, sig: Signal) -> void:
	var original := b.text
	b.pressed.connect(func():
		if b.text == ask:
			sig.emit()
			b.text = done
			b.disabled = true
		else:
			b.text = ask
			get_tree().create_timer(4.0).timeout.connect(func():
				if is_instance_valid(b) and b.text == ask:
					b.text = original))


func _show_settings() -> void:
	_clear()
	_label(tr("PARENTS"), 28)
	var outer := _box

	# Sound
	_box = _card()
	var mic := Button.new()
	mic.toggle_mode = true
	mic.button_pressed = settings.mic
	mic.custom_minimum_size = Vector2(0, 46)
	mic.add_theme_font_size_override("font_size", 19)
	var paint_mic := func(on: bool):
		mic.text = tr("MIC_ON") if on else tr("MIC_OFF")
		var st := _box_style(Color("4cc3b5") if on else Color("b9b4c4"), 23)
		for k in ["normal", "hover", "pressed", "hover_pressed"]:
			mic.add_theme_stylebox_override(k, st)
	paint_mic.call(settings.mic)
	mic.toggled.connect(func(on):
		settings.mic = on
		paint_mic.call(on)
		changed.emit(settings))
	_box.add_child(mic)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var vl := Label.new()
	vl.text = tr("VOLUME")
	vl.add_theme_font_size_override("font_size", 17)
	vl.add_theme_color_override("font_color", INK)
	row.add_child(vl)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = settings.volume
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.custom_minimum_size = Vector2(0, 34)
	vol.value_changed.connect(func(v):
		settings.volume = v
		changed.emit(settings))
	row.add_child(vol)
	_box.add_child(row)

	# Play time and concert
	_box = _card()
	_label(tr("SLEEP_AFTER"), 17)
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for m in [4, 6, 10, 15]:
		var chip := Button.new()
		chip.text = tr("MINUTES") % m
		chip.toggle_mode = true
		chip.button_group = group
		chip.custom_minimum_size = Vector2(96, 40)
		chip.add_theme_font_size_override("font_size", 18)
		chip.add_theme_stylebox_override("normal", _box_style(Color("d8d1c5"), 20))
		chip.add_theme_stylebox_override("hover", _box_style(Color("cbc3b5"), 20))
		chip.add_theme_stylebox_override("pressed", _box_style(Color("4cc3b5"), 20))
		chip.add_theme_stylebox_override("hover_pressed", _box_style(Color("4cc3b5"), 20))
		chip.add_theme_color_override("font_color", INK)
		chip.button_pressed = int(settings.get("day_minutes", 6)) == m
		chip.pressed.connect(func():
			settings.day_minutes = m
			changed.emit(settings))
		chips.add_child(chip)
	_box.add_child(chips)
	var exp := _button(tr("SAVE_CONCERT"), func(): pass)
	var exp_info := _label("", 14)
	exp_info.visible = false
	exp.pressed.connect(func():
		var path: String = exporter.call() if exporter.is_valid() else ""
		exp_info.visible = true
		exp_info.text = tr("NO_BEINGS") if path.is_empty() else tr("SAVED") % path)

	# Language and season
	_box = _card()
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 10)
	var ll := Label.new()
	ll.text = tr("LANGUAGE")
	ll.add_theme_font_size_override("font_size", 17)
	ll.add_theme_color_override("font_color", INK)
	lang_row.add_child(ll)
	var lang := OptionButton.new()
	lang.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang.add_theme_font_size_override("font_size", 17)
	for i in LANGS.size():
		lang.add_item(LANGS[i][1])
		if LANGS[i][0] == settings.get("lang", ""):
			lang.select(i)
	lang.item_selected.connect(func(idx):
		settings.lang = LANGS[idx][0]
		changed.emit(settings)
		_show_settings.call_deferred())
	lang_row.add_child(lang)
	_box.add_child(lang_row)
	_label(tr("SEASON"), 17)
	var seasons := HBoxContainer.new()
	seasons.alignment = BoxContainer.ALIGNMENT_CENTER
	seasons.add_theme_constant_override("separation", 6)
	var sg := ButtonGroup.new()
	var names := ["SEASON_AUTO", "SPRING", "SUMMER", "AUTUMN", "WINTER"]
	for i in names.size():
		var chip := Button.new()
		chip.text = tr(names[i])
		chip.toggle_mode = true
		chip.button_group = sg
		chip.custom_minimum_size = Vector2(0, 38)
		chip.add_theme_font_size_override("font_size", 15)
		chip.add_theme_stylebox_override("normal", _box_style(Color("d8d1c5"), 19))
		chip.add_theme_stylebox_override("hover", _box_style(Color("cbc3b5"), 19))
		chip.add_theme_stylebox_override("pressed", _box_style(Color("4cc3b5"), 19))
		chip.add_theme_stylebox_override("hover_pressed", _box_style(Color("4cc3b5"), 19))
		chip.add_theme_color_override("font_color", INK)
		chip.button_pressed = int(settings.get("season", -1)) == i - 1
		chip.pressed.connect(func():
			settings.season = i - 1
			changed.emit(settings))
		seasons.add_child(chip)
	_box.add_child(seasons)

	# Trust + quiet destructive actions
	_box = outer
	_label(tr("TRUST"), 14)
	var sep := HSeparator.new()
	_box.add_child(sep)
	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 18)
	_box.add_child(links)
	var del := _link(tr("DELETE_REC"))
	del.reparent(links)
	_confirming(del, tr("DELETE_SURE"), tr("DELETE_DONE"), delete_recordings)
	var clr := _link(tr("RESET"))
	clr.reparent(links)
	_confirming(clr, tr("RESET_SURE"), tr("RESET_DONE"), clear_garden)
	_button(tr("BACK"), queue_free)
	_label("Klanggarten %s" % ProjectSettings.get_setting("application/config/version"), 12)
