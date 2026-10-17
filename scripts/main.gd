extends Node2D
## The garden: 8 beds, weather, concert, day/night cycle, persistence.

const Creature := preload("res://scripts/creature.gd")
const ParentPanel := preload("res://scripts/parent_panel.gd")

const SAVE_PATH := "user://garden.json"
const DAY_LENGTH := 360.0 # seconds until the garden falls asleep
const BED_POSITIONS := [
	Vector2(200, 440), Vector2(493, 440), Vector2(787, 440), Vector2(1080, 440),
	Vector2(200, 665), Vector2(493, 665), Vector2(787, 665), Vector2(1080, 665),
]
const BTN_CONDUCTOR := Vector2(90, 90)
const BTN_SUN := Vector2(1060, 90)
const BTN_RAIN := Vector2(1190, 90)
const BTN_PARENT := Vector2(1240, 30)
const BTN_R := 56.0

enum Weather { NONE, SUN, RAIN }
enum State { DAY, RECORDING, CONCERT, NIGHT }

var state := State.DAY
var weather := Weather.NONE
var day_time := 0.0
var beds: Array = [] ## creature node or null per bed
var bed_data: Array = [] ## saved description per bed or null
var settings := {"mic": true, "volume": 0.8}

var _rec_bed := -1
var _rec_time := 0.0
var _t := 0.0
var _rain: Array[Vector2] = []
var _panel: CanvasLayer
var _next_preset := 0
var _overlay := Node2D.new()


func _ready() -> void:
	randomize()
	beds.resize(BED_POSITIONS.size())
	bed_data.resize(BED_POSITIONS.size())
	for i in 80:
		_rain.append(Vector2(randf() * 1400 - 60, randf() * 760))
	_overlay.z_index = 10
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_load()
	Audio.set_volume(settings.volume)
	_greet()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p := get_global_mouse_position()
	if p.distance_to(BTN_PARENT) < 30:
		_open_parent_gate()
		return
	match state:
		State.RECORDING, State.CONCERT:
			return
		State.NIGHT:
			if p.distance_to(BTN_SUN) < BTN_R:
				_wake_up()
			return
	if p.distance_to(BTN_SUN) < BTN_R:
		_set_weather(Weather.NONE if weather == Weather.SUN else Weather.SUN)
		return
	if p.distance_to(BTN_RAIN) < BTN_R:
		_set_weather(Weather.NONE if weather == Weather.RAIN else Weather.RAIN)
		return
	if p.distance_to(BTN_CONDUCTOR) < BTN_R:
		if _creature_count() >= 3:
			_concert()
		return
	for i in BED_POSITIONS.size():
		var c = beds[i]
		if c:
			var hit := Rect2(BED_POSITIONS[i] + Vector2(-c.radius(), -c.radius() * 2.0 - 30), Vector2(c.radius() * 2, c.radius() * 2 + 60))
			if hit.has_point(p):
				c.sing(_shift())
				return
		elif p.distance_to(BED_POSITIONS[i]) < 85:
			_plant(i)
			return


# ---------------------------------------------------------------- flow

func _plant(i: int) -> void:
	if settings.mic:
		state = State.RECORDING
		_rec_bed = i
		_rec_time = 0.0
		Audio.start_recording()
	else:
		_grow_preset(i)


func _finish_recording() -> void:
	var raw := Audio.stop_recording()
	var bed := _rec_bed
	_rec_bed = -1
	state = State.DAY
	var rate := Audio.mix_rate()
	var res := SoundLab.analyze(raw, rate)
	if res.is_empty():
		# No sound (or no mic): never fail, a friendly built-in sound grows instead.
		_grow_preset(bed)
		return
	var file := "bed_%d_%d.pcm" % [bed, Time.get_unix_time_from_system()]
	_write_pcm(file, res.samples)
	bed_data[bed] = {"pitch": res.pitch, "loud": res.loud, "freq": res.freq, "file": file, "rate": rate}
	_spawn(bed, SoundLab.make_wav(res.samples, rate), true)
	_save()


func _grow_preset(i: int) -> void:
	var idx := _next_preset
	_next_preset = (_next_preset + 5) % SoundLab.PRESET_COUNT # wander through all twelve
	bed_data[i] = {"preset": idx}
	_spawn(i, null, true)
	_save()


func _spawn(i: int, wav: AudioStreamWAV, fresh: bool) -> void:
	var d: Dictionary = bed_data[i]
	var pitch: int
	var loud: int
	var freq: float
	if d.has("preset"):
		var pr := SoundLab.preset(int(d.preset))
		wav = SoundLab.make_wav(pr.samples, 22050)
		pitch = pr.pitch
		loud = pr.loud
		freq = pr.freq
	else:
		pitch = int(d.pitch)
		loud = int(d.loud)
		freq = float(d.freq)
	var c := Creature.new()
	c.position = BED_POSITIONS[i]
	c.z_index = i / 4 # front row in front
	c.setup(pitch, loud, wav, freq)
	add_child(c)
	beds[i] = c
	if fresh:
		c.grow_in()
		get_tree().create_timer(0.9).timeout.connect(func(): if is_instance_valid(c): c.sing(_shift()))
	else:
		c.grow = 1.0


func _greet() -> void:
	var delay := 0.6
	for i in beds.size():
		var c = beds[i]
		if c:
			c.grow = 0.0
			get_tree().create_timer(delay).timeout.connect(func():
				if is_instance_valid(c):
					c.grow_in(1.0)
					c.sing(_shift()))
			delay += 0.5


func _concert() -> void:
	state = State.CONCERT
	var beat := 60.0 / _bpm()
	for _r in 2:
		for c in beds:
			if c and is_instance_valid(c):
				c.sing(_shift())
				await get_tree().create_timer(beat).timeout
	await get_tree().create_timer(beat).timeout
	if state == State.CONCERT:
		state = State.DAY


func _set_weather(w: Weather) -> void:
	weather = w
	for c in beds:
		if c:
			c.sing(_shift())
			break


func _shift() -> float:
	match weather:
		Weather.SUN: return 3.0
		Weather.RAIN: return -3.0
	return 0.0


func _bpm() -> float:
	match weather:
		Weather.SUN: return 116.0
		Weather.RAIN: return 68.0
	return 90.0


func _creature_count() -> int:
	return beds.filter(func(c): return c != null).size()


func _go_to_sleep() -> void:
	if state == State.RECORDING:
		Audio.stop_recording()
		_rec_bed = -1
	state = State.NIGHT
	weather = Weather.NONE
	for c in beds:
		if c:
			c.sleeping = true


func _wake_up() -> void:
	state = State.DAY
	day_time = 0.0
	for c in beds:
		if c:
			c.sleeping = false
	_greet()


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	_t += delta
	if state != State.NIGHT:
		day_time += delta
		if day_time >= DAY_LENGTH and state == State.DAY:
			_go_to_sleep()
	if state == State.RECORDING:
		_rec_time += delta
		if _rec_time >= Audio.RECORD_SECONDS:
			_finish_recording()
	if weather == Weather.RAIN:
		for i in _rain.size():
			_rain[i].y += delta * 520.0
			_rain[i].x -= delta * 60.0
			if _rain[i].y > 760:
				_rain[i] = Vector2(randf() * 1400 - 60, -20)
	queue_redraw()
	_overlay.queue_redraw()


func _evening() -> float:
	if state == State.NIGHT:
		return 1.0
	return clampf((day_time - DAY_LENGTH * 0.8) / (DAY_LENGTH * 0.2), 0.0, 1.0)


func _draw() -> void:
	var ev := _evening()
	var sky := Color("8cc8ec").lerp(Color("f2a46b"), clampf(ev * 2.0, 0.0, 1.0)).lerp(Color("1f2550"), clampf(ev * 2.0 - 1.0, 0.0, 1.0))
	if weather == Weather.RAIN:
		sky = sky.lerp(Color("7b8794"), 0.45)
	elif weather == Weather.SUN:
		sky = sky.lerp(Color("bfe6ff"), 0.3)
	draw_rect(Rect2(-2000, -2000, 5280, 4720), sky)

	# Sun / moon
	if state == State.NIGHT:
		draw_circle(Vector2(640, 120), 46, Color("f6f1c8"))
		draw_circle(Vector2(662, 106), 40, sky)
		for i in 30:
			var sp := Vector2(fmod(i * 197.0, 1280.0), fmod(i * 83.0, 300.0))
			draw_circle(sp, 2.0 + sin(_t * 2.0 + i) * 0.8, Color(1, 1, 1, 0.8))
	else:
		var sun_y := lerpf(130.0, 330.0, ev)
		draw_circle(Vector2(640, sun_y), 50, Color("ffe27a").lerp(Color("ff9a5a"), ev))

	# Hills and ground
	var hill := Color("7cc46a").lerp(Color("2d4a45"), ev)
	draw_circle(Vector2(250, 760), 420, hill.darkened(0.1))
	draw_circle(Vector2(1050, 780), 460, hill.darkened(0.05))
	draw_rect(Rect2(-2000, 380, 5280, 3000), hill)

	# Beds
	for i in BED_POSITIONS.size():
		var b: Vector2 = BED_POSITIONS[i]
		_draw_ellipse(b + Vector2(0, 8), Vector2(95, 26), Color("6b4a2f").lerp(Color("2a2430"), ev * 0.6))
		if beds[i] == null and state != State.NIGHT:
			var glow := 0.5 + 0.5 * sin(_t * 3.0 + i)
			draw_circle(b + Vector2(0, -6), 26 + glow * 8, Color(1, 0.95, 0.6, 0.25 + 0.2 * glow))
			_draw_ellipse(b + Vector2(0, -6), Vector2(14, 18), Color("d9a441"))
			draw_line(b + Vector2(0, -22), b + Vector2(6, -32), Color("5aa64b"), 4.0)

	if weather == Weather.RAIN:
		for r in _rain:
			draw_line(r, r + Vector2(-6, 18), Color(0.85, 0.9, 1.0, 0.6), 2.0)

	# Buttons (no text: icons only)
	var can_concert := _creature_count() >= 3 and state == State.DAY
	_draw_button(BTN_CONDUCTOR, can_concert, false)
	_draw_baton(BTN_CONDUCTOR, can_concert)
	var sun_active := weather == Weather.SUN or state == State.NIGHT
	_draw_button(BTN_SUN, state != State.CONCERT, sun_active)
	_draw_sun_icon(BTN_SUN, state == State.NIGHT)
	_draw_button(BTN_RAIN, state == State.DAY, weather == Weather.RAIN)
	_draw_cloud_icon(BTN_RAIN)
	draw_circle(BTN_PARENT, 14, Color(1, 1, 1, 0.35))
	draw_arc(BTN_PARENT, 8, 0, TAU, 16, Color(0.2, 0.2, 0.3, 0.6), 3.0)

	if ev > 0.0:
		draw_rect(Rect2(-2000, -2000, 5280, 4720), Color(0.05, 0.05, 0.2, ev * 0.25))


func _draw_overlay() -> void:
	# Recording overlay
	if state == State.RECORDING and _rec_bed >= 0:
		var c: Vector2 = BED_POSITIONS[_rec_bed] + Vector2(0, -120)
		var pulse := 1.0 + 0.08 * sin(_t * 8.0)
		var lvl := Audio.level
		for k in 3:
			_overlay.draw_arc(c, (70 + k * 22) * (0.8 + lvl * 0.6), 0, TAU, 48, Color(1, 1, 1, 0.5 - k * 0.15), 5.0)
		_overlay.draw_circle(c, 60 * pulse, Color("ff6f91"))
		_overlay.draw_rect(Rect2(c + Vector2(-14, -34), Vector2(28, 46)), Color.WHITE)
		_overlay.draw_circle(c + Vector2(0, -34), 14, Color.WHITE)
		_overlay.draw_circle(c + Vector2(0, 12), 14, Color.WHITE)
		_overlay.draw_arc(c + Vector2(0, 2), 26, 0.1, PI - 0.1, 12, Color.WHITE, 5.0)
		_overlay.draw_line(c + Vector2(0, 28), c + Vector2(0, 42), Color.WHITE, 5.0)
		var prog := _rec_time / Audio.RECORD_SECONDS
		_overlay.draw_arc(c, 66, -PI / 2, -PI / 2 + TAU * prog, 48, Color("ffe066"), 8.0)


func _draw_button(c: Vector2, enabled: bool, active: bool) -> void:
	var a := 1.0 if enabled else 0.35
	var bob := sin(_t * 2.0 + c.x) * 3.0 if enabled else 0.0
	if active:
		draw_circle(c, BTN_R + 10 + sin(_t * 4.0) * 4, Color(1, 0.95, 0.5, 0.45))
	draw_circle(c + Vector2(0, 6), BTN_R, Color(0, 0, 0, 0.15 * a))
	draw_circle(c + Vector2(0, bob * 0.3), BTN_R, Color(1, 1, 1, 0.9 * a))


func _draw_baton(c: Vector2, enabled: bool) -> void:
	var a := 1.0 if enabled else 0.35
	var wave := sin(_t * 5.0) * 0.3 if enabled else 0.0
	var dir := Vector2.from_angle(-0.8 + wave)
	draw_line(c - dir * 30, c + dir * 32, Color(0.3, 0.2, 0.15, a), 7.0)
	draw_circle(c + dir * 34, 8, Color(1, 0.85, 0.3, a))
	for k in 3:
		draw_circle(c + Vector2(18 + k * 6, 20 - k * 14), 5, Color(0.5, 0.3, 0.8, a))


func _draw_sun_icon(c: Vector2, sunrise: bool) -> void:
	var col := Color("ffb627")
	for i in 8:
		var d := Vector2.from_angle(TAU * i / 8.0 + _t * 0.5)
		draw_line(c + d * 28, c + d * 42, col, 6.0)
	draw_circle(c, 22, col)
	if sunrise:
		draw_circle(c, 22 + sin(_t * 3.0) * 3, Color(1, 0.9, 0.4, 0.5))


func _draw_cloud_icon(c: Vector2) -> void:
	var col := Color("8aa0b8")
	draw_circle(c + Vector2(-14, -4), 18, col)
	draw_circle(c + Vector2(10, -10), 22, col)
	draw_circle(c + Vector2(24, 2), 14, col)
	draw_rect(Rect2(c + Vector2(-30, -4), Vector2(66, 18)), col)
	for k in 3:
		draw_line(c + Vector2(-16 + k * 16, 22), c + Vector2(-20 + k * 16, 36), Color("4f9de8"), 4.0)


func _draw_ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


# ---------------------------------------------------------------- parents

func _open_parent_gate() -> void:
	if _panel:
		return
	if state == State.RECORDING:
		Audio.stop_recording()
		_rec_bed = -1
		state = State.DAY
	_panel = ParentPanel.new()
	_panel.settings = settings.duplicate()
	_panel.changed.connect(_on_settings_changed)
	_panel.delete_recordings.connect(_delete_recordings)
	_panel.clear_garden.connect(_clear_garden)
	_panel.tree_exited.connect(func(): _panel = null)
	add_child(_panel)


func _on_settings_changed(s: Dictionary) -> void:
	settings = s
	Audio.set_volume(settings.volume)
	_save()


func _delete_recordings() -> void:
	for i in bed_data.size():
		var d = bed_data[i]
		if d and d.has("file"):
			_remove_bed(i)
	# Remove stray files too.
	var dir := DirAccess.open("user://")
	if dir:
		for f in dir.get_files():
			if f.ends_with(".pcm"):
				dir.remove(f)
	_save()


func _clear_garden() -> void:
	for i in bed_data.size():
		_remove_bed(i)
	_delete_recordings()


func _remove_bed(i: int) -> void:
	var d = bed_data[i]
	if d and d.has("file"):
		DirAccess.remove_absolute("user://" + d.file)
	if beds[i]:
		beds[i].queue_free()
	beds[i] = null
	bed_data[i] = null


# ---------------------------------------------------------------- save

func _write_pcm(file: String, samples: PackedFloat32Array) -> void:
	var f := FileAccess.open("user://" + file, FileAccess.WRITE)
	if f:
		f.store_buffer(samples.to_byte_array())


func _read_pcm(file: String) -> PackedFloat32Array:
	var f := FileAccess.open("user://" + file, FileAccess.READ)
	if not f:
		return PackedFloat32Array()
	return f.get_buffer(f.get_length()).to_float32_array()


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": 1, "settings": settings, "beds": bed_data, "next_preset": _next_preset}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	if data.has("settings"):
		settings.merge(data.settings, true)
	_next_preset = int(data.get("next_preset", 0))
	var saved: Array = data.get("beds", [])
	for i in mini(saved.size(), bed_data.size()):
		var d = saved[i]
		if typeof(d) != TYPE_DICTIONARY:
			continue
		bed_data[i] = d
		if d.has("file"):
			var samples := _read_pcm(d.file)
			if samples.is_empty():
				bed_data[i] = null
				continue
			_spawn(i, SoundLab.make_wav(samples, int(d.rate)), false)
		else:
			_spawn(i, null, false)
