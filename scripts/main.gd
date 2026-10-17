extends Node2D
## The garden: 6 beds, weather, concert, day/night cycle, persistence.

const Creature := preload("res://scripts/creature.gd")
const ParentPanel := preload("res://scripts/parent_panel.gd")

const SAVE_PATH := "user://garden.json"
## Organic layout on three depths: back, middle, front.
const BED_POSITIONS := [
	Vector2(400, 455), Vector2(880, 450),
	Vector2(205, 580), Vector2(1075, 575),
	Vector2(500, 690), Vector2(800, 685),
]
const BED_SCALE := [0.78, 0.8, 0.9, 0.92, 1.0, 1.02]
const BTN_CONDUCTOR := Vector2(95, 95)
const BTN_SUN := Vector2(1035, 95)
const BTN_RAIN := Vector2(1170, 95)
const BTN_PARENT := Vector2(1240, 200)
const BTN_R := 56.0

enum Weather { NONE, SUN, RAIN }
enum State { DAY, RECORDING, CONCERT, NIGHT }

var state := State.DAY
var weather := Weather.NONE
var day_time := 0.0
var beds: Array = [] ## creature node or null per bed
var bed_data: Array = [] ## saved description per bed or null
var settings := {"mic": true, "volume": 0.8, "day_minutes": 6}

var _rec_bed := -1
var _rec_time := 0.0
var _t := 0.0
var _rain: Array[Vector2] = []
var _panel: CanvasLayer
var _next_preset := 0
var _beat_time := 0.0
var _beat := 0
var _bass: AudioStreamWAV
var _pluck: AudioStreamWAV
var _plop: AudioStreamWAV
var _bird: AudioStreamWAV
var _cricket: AudioStreamWAV
var _yawn: AudioStreamWAV
var _amb_timer := 3.0
var _presses := {} ## button centre -> time pressed
var _confetti: Array = [] ## [pos, vel, age, color, spin, size]
var _front := Node2D.new()
var _rainbow := 0.0
var _rain_amount := 0.0
var _btn_offset := Vector2.ZERO
var _btn_alpha := 1.0
var hide_ui := false ## key art: no buttons, no empty beds
var _overlay := Node2D.new()


func _ready() -> void:
	randomize()
	beds.resize(BED_POSITIONS.size())
	bed_data.resize(BED_POSITIONS.size())
	for i in 80:
		_rain.append(Vector2(randf() * 1400 - 60, randf() * 760))
	_bass = SoundLab.make_wav(SoundLab.instrument(0, SoundLab.BASE_FREQ / 2.0), 22050)
	_pluck = SoundLab.make_wav(SoundLab.instrument(1, SoundLab.BASE_FREQ * 2.0), 22050)
	_bird = SoundLab.make_wav(SoundLab.ambient(0), 22050)
	_cricket = SoundLab.make_wav(SoundLab.ambient(1), 22050)
	_yawn = SoundLab.make_wav(SoundLab.ambient(3), 22050)
	_plop = SoundLab.make_wav(SoundLab.instrument(2, 520.0), 22050)
	var paper := CanvasLayer.new()
	paper.layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/paper.gdshader")
	rect.material = mat
	paper.add_child(rect)
	add_child(paper)
	_front.z_index = 9
	_front.draw.connect(_draw_front)
	add_child(_front)
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
	for btn in [BTN_CONDUCTOR, BTN_SUN, BTN_RAIN]:
		if p.distance_to(btn) < BTN_R:
			_presses[btn] = _t
	Audio.play_music(_plop, randf_range(-2.0, 2.0) + _shift(), 2.0)
	if p.distance_to(BTN_PARENT) < 34:
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
			var hit := Rect2(BED_POSITIONS[i] + Vector2(-c.radius() - 20, -c.height() - 20), Vector2(c.radius() * 2 + 40, c.height() + 50))
			if hit.has_point(p):
				c.cheer()
				c.sing(_shift())
				return
		elif p.distance_to(BED_POSITIONS[i]) < 105 * BED_SCALE[i]:
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
	# Prefer a sound whose species is not in the garden yet, so it stays varied.
	var used := {}
	for c in beds:
		if c:
			used[c.species] = true
	var idx := _next_preset
	for k in SoundLab.PRESET_COUNT:
		var cand := (_next_preset + k * 5) % SoundLab.PRESET_COUNT
		if not used.has(SoundLab.preset_species(cand)):
			idx = cand
			break
	_next_preset = (idx + 5) % SoundLab.PRESET_COUNT
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
	c.scale = Vector2.ONE * BED_SCALE[i]
	c.z_index = int(BED_POSITIONS[i].y / 100.0) - 3 # deeper beds behind
	c.setup(pitch, loud, wav, freq)
	add_child(c)
	beds[i] = c
	c.sang.connect(_on_sang)
	if fresh:
		c.grow_in()
		get_tree().create_timer(2.3).timeout.connect(func():
			if is_instance_valid(c):
				c.cheer()
				c.sing(_shift()))
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
					c.grow_in(1.0, false)
					c.sing(_shift()))
			delay += 0.5


func _concert() -> void:
	state = State.CONCERT
	var beat := 60.0 / _bpm()
	var singers := beds.filter(func(c): return c != null)
	# Round 1: one after another, like a melody.
	for c in singers:
		if is_instance_valid(c):
			c.sing(_shift())
		await get_tree().create_timer(beat).timeout
	# Round 2: in pairs, like little chords.
	for k in range(0, singers.size(), 2):
		for c in singers.slice(k, k + 2):
			if is_instance_valid(c):
				c.sing(_shift())
		await get_tree().create_timer(beat).timeout
	# Finale: everyone together, then a bow and fireworks.
	for c in singers:
		if is_instance_valid(c):
			c.sing(_shift())
	_fireworks()
	if weather == Weather.RAIN:
		weather = Weather.NONE # the concert chases the rain away
		_rainbow = 1.0
	await get_tree().create_timer(beat * 1.5).timeout
	for i in singers.size():
		if is_instance_valid(singers[i]):
			singers[i].bow()
	await get_tree().create_timer(1.3).timeout
	for i in singers.size():
		if is_instance_valid(singers[i]):
			singers[i].celebrate_hop(i * 0.08)
	await get_tree().create_timer(0.8).timeout
	if state == State.CONCERT:
		state = State.DAY


func _fireworks() -> void:
	var cols := [Color("ff7a6b"), Color("ffc93c"), Color("4cc3b5"), Color("6fa8e8"), Color("9b6bd6"), Color("ff8fb8")]
	for burst in 4:
		var origin := Vector2(330 + burst * 205, 150 + (burst % 2) * 60)
		for i in 24:
			var a := TAU * i / 30.0 + randf() * 0.2
			var size: float = [5.0, 8.0, 12.0][i % 3]
			_confetti.append([origin, Vector2(cos(a), sin(a)) * randf_range(120, 300) * (1.3 - size / 20.0), -burst * 0.22, cols[(i + burst) % cols.size()], randf() * TAU, size])


## Seconds until the garden falls asleep (parents choose 4, 6 or 10 minutes).
func day_length() -> float:
	return float(settings.get("day_minutes", 6)) * 60.0


## Renders the garden concert (melody, pairs, finale, soft bass) to a WAV in
## the user's Documents folder. Returns the path, or "" if nothing to render.
func export_concert() -> String:
	var singers := beds.filter(func(c): return c != null)
	if singers.is_empty():
		return ""
	var rate := 22050
	var beat := 60.0 / _bpm()
	var events := [] # [creature, start_seconds]
	var t := 0.5
	for c in singers:
		events.append([c, t])
		t += beat
	for k in range(0, singers.size(), 2):
		for c in singers.slice(k, k + 2):
			events.append([c, t])
		t += beat
	for c in singers:
		events.append([c, t])
	var total := t + 2.5
	var mix := PackedFloat32Array()
	mix.resize(int(total * rate))
	for e in events:
		var c = e[0]
		var src := _wav_to_floats(c.stream)
		var step: float = SoundLab.pitch_scale_for(c.freq, _shift()) * float(c.stream.mix_rate) / rate
		var start := int(float(e[1]) * rate)
		var j := 0.0
		var o := start
		while int(j) < src.size() - 1 and o < mix.size():
			var a := int(j)
			mix[o] += lerpf(src[a], src[a + 1], j - a) * 0.6
			j += step
			o += 1
	var bass := SoundLab.instrument(0, SoundLab.BASE_FREQ / 2.0 * pow(2.0, _shift() / 12.0))
	var roots := [0.0, -3.0, 0.0, -5.0]
	var bt := 0.5
	var bar := 0
	while bt < t + 1.0:
		var ratio := pow(2.0, float(roots[bar % 4]) / 12.0)
		var start := int(bt * rate)
		var j := 0.0
		var o := start
		while int(j) < bass.size() - 1 and o < mix.size():
			mix[o] += bass[int(j)] * 0.25
			j += ratio
			o += 1
		bt += beat * 2.0
		bar += 1
	var peak := 0.0
	for v in mix:
		peak = maxf(peak, absf(v))
	if peak > 0.95:
		for i in mix.size():
			mix[i] *= 0.95 / peak
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if dir.is_empty():
		dir = OS.get_user_data_dir()
	var path := dir.path_join("Klanggarten-Konzert-%s.wav" % stamp)
	var err := SoundLab.make_wav(mix, rate).save_to_wav(path)
	return path if err == OK else ""


func _wav_to_floats(w: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w.data.size() / 2)
	for i in out.size():
		out[i] = w.data.decode_s16(i * 2) / 32768.0
	return out


func _on_sang(who: Node2D) -> void:
	for c in beds:
		if c and c != who:
			c.notice(who.global_position)


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
	var delay := 0.3
	for c in beds:
		if c:
			c.sleeping = true
			var pitch := randf_range(0.8, 1.4)
			get_tree().create_timer(delay).timeout.connect(func():
				Audio.play_ambient(_yawn, pitch, 6.0)
				if is_instance_valid(c):
					c.yawn())
			delay += 0.7


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
		if day_time >= day_length() and state == State.DAY:
			_go_to_sleep()
	_tick_music(delta)
	_tick_ambience(delta)
	for cf in _confetti:
		cf[2] += delta
		if cf[2] > 0.0:
			cf[0] += cf[1] * delta
			cf[1].y += 160.0 * delta
			cf[1] *= 0.985
	_confetti = _confetti.filter(func(cf): return cf[2] < 2.4)
	_rain_amount = move_toward(_rain_amount, 1.0 if weather == Weather.RAIN else 0.0, delta * 0.5)
	_rainbow = maxf(0.0, _rainbow - delta / 12.0)
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
	_front.queue_redraw()


func _tick_ambience(delta: float) -> void:
	Audio.set_rain(weather == Weather.RAIN and state != State.RECORDING)
	if state == State.RECORDING:
		return
	_amb_timer -= delta
	if _amb_timer > 0.0:
		return
	if state == State.NIGHT:
		Audio.play_ambient(_cricket, randf_range(0.9, 1.1), randf_range(-6.0, 0.0))
		_amb_timer = randf_range(1.2, 3.0)
	elif weather != Weather.RAIN and _evening() < 0.6:
		Audio.play_ambient(_bird, randf_range(0.8, 1.3), randf_range(-8.0, -2.0))
		_amb_timer = randf_range(4.0, 10.0)
	else:
		_amb_timer = 2.0


## Gentle accompaniment: bass on 1 and 3, music-box notes on the off-beats.
## Quiet while recording so the child can hear itself; silent at night.
func _tick_music(delta: float) -> void:
	if state == State.NIGHT or state == State.RECORDING or _creature_count() == 0:
		return
	_beat_time += delta
	var beat := 60.0 / _bpm()
	if _beat_time < beat / 2.0:
		return
	_beat_time -= beat / 2.0
	_beat += 1
	var half := _beat % 16 # 8 beats = 2 bars, in half beats
	var bar := (_beat / 8) % 4
	var roots := [0.0, -3.0, 0.0, -5.0] # C, A, C, G
	var root: float = roots[bar] + _shift()
	var fade := 1.0 - _evening()
	if half % 4 == 0:
		Audio.play_music(_bass, root, linear_to_db(0.9 * fade + 0.01))
	elif half % 2 == 1 and randf() < 0.55:
		var steps := [0.0, 2.0, 4.0, 7.0, 9.0, 12.0]
		Audio.play_music(_pluck, steps[randi() % steps.size()] + _shift() - 12.0, linear_to_db(0.5 * fade + 0.01))


func _evening() -> float:
	if state == State.NIGHT:
		return 1.0
	return clampf((day_time - day_length() * 0.8) / (day_length() * 0.2), 0.0, 1.0)


func _draw() -> void:
	var ev := _evening()
	var night := clampf(ev * 2.0 - 1.0, 0.0, 1.0)
	var dusk := clampf(ev * 2.0, 0.0, 1.0)
	var vivid := clampf(1.0 - _rain_mood(), 0.0, 1.0) # rain greys the world, the rainbow brings colour back
	var top := Color("6cbbe8").lerp(Color("7b6fc4"), dusk).lerp(Color("1e2246"), night)
	var bottom := Color("e8f4f8").lerp(Color("ffb36b"), dusk).lerp(Color("3b3f7a"), night)
	top = top.lerp(Color("6f7c8c"), 0.55 * (1.0 - vivid))
	bottom = bottom.lerp(Color("b4bec9"), 0.5 * (1.0 - vivid))
	if weather == Weather.SUN:
		bottom = bottom.lerp(Color("fff4c2"), 0.4)
	_gradient_rect(Rect2(-2000, -2000, 5280, 2000), top, top)
	_gradient_rect(Rect2(-2000, 0, 5280, 420), top, bottom)

	# Stars, moon, sun (the sky sun sits left so it never competes with the sun button)
	if night > 0.0:
		for i in 60:
			var sp := Vector2(fmod(i * 197.3, 1300.0) - 10, fmod(i * 83.7, 330.0))
			var tw := 0.6 + 0.4 * sin(_t * (1.5 + fmod(i, 3.0)) + i)
			draw_circle(sp, 1.2 + fmod(i, 3.0) * 0.6, Color(1, 1, 0.9, night * tw))
	if state == State.NIGHT:
		draw_circle(Vector2(420, 110), 40, Color("f6f1c8"))
		draw_circle(Vector2(441, 96), 35, top.lerp(bottom, 0.2))
	else:
		var sun_c := Vector2(400, lerpf(105.0, 330.0, ev))
		var sun_col := Color("ffe27a").lerp(Color("ff8a4a"), ev)
		sun_col.a = lerpf(0.35, 1.0, vivid)
		for k in 3:
			draw_circle(sun_c, 48 + k * 22 + sin(_t * 1.5) * 3, Color(sun_col, 0.10 * sun_col.a))
		draw_circle(sun_c, 40, sun_col)
		draw_circle(sun_c + Vector2(-11, -11), 15, Color(1, 1, 1, 0.3 * sun_col.a))

	# Rainbow after a rainy concert
	if _rainbow * (1.0 - dusk) > 0.0:
		var rb := [Color("ff6b6b"), Color("ffa94d"), Color("ffd84d"), Color("7cc86a"), Color("4cc3b5"), Color("6fa8e8"), Color("9b6bd6")]
		for k in rb.size():
			draw_arc(Vector2(640, 470), 470 - k * 16, PI, TAU, 96, Color(rb[k], 0.55 * _rainbow * (1.0 - dusk)), 16.0, true)

	# Drifting clouds
	var cloud_col := Color(1, 1, 1, 0.92).lerp(Color("c9a0b8"), dusk * 0.5).lerp(Color("39406e"), night)
	cloud_col = cloud_col.lerp(Color("8e98a6"), 1.0 - vivid)
	for i in 5:
		var speed := 8.0 + i * 3.0
		var x := fmod(i * 330.0 + _t * speed, 1700.0) - 250.0
		_draw_cloud(Vector2(x, 60 + fmod(i * 61.0, 150.0)), 0.7 + fmod(i * 0.37, 0.6), cloud_col)

	# Hills with aerial perspective: the far one is pale and bluish
	var far := Color("a9d49a").lerp(Color("c7a487"), dusk * 0.4).lerp(Color("2a3558"), night)
	var mid := Color("86c56d").lerp(Color("b08a62"), dusk * 0.3).lerp(Color("1d3a3c"), night)
	var near := Color("8cc665").lerp(Color("8a7a4a"), dusk * 0.3).lerp(Color("183232"), night)
	far = far.lerp(far.darkened(0.2), 1.0 - vivid)
	mid = mid.lerp(mid.darkened(0.2), 1.0 - vivid)
	near = near.lerp(near.darkened(0.15), 1.0 - vivid)
	_draw_hill(325, 110, 0.004, 1.0, far)
	_draw_tree(Vector2(1150, 352), 0.75, night, vivid) # a little tree far away
	_draw_hill(372, 55, 0.007, 2.3, mid)
	_gradient_rect(Rect2(-2000, 385, 5280, 2400), near.lightened(0.06), Color("5fa14a").lerp(near, 0.4 + night * 0.6).darkened(0.08))
	draw_rect(Rect2(-2000, 2785, 5280, 2000), near.darkened(0.12))

	# Mid-ground: big tree on the left, fence on the right
	_draw_tree(Vector2(90, 470), 1.25, night, vivid)
	_draw_fence(Vector2(1000, 425), night)

	# Winding path from the front into the garden
	var path_col := Color("e9d3a6").lerp(Color("4a4560"), night * 0.8).lerp(Color("bfae8c"), 1.0 - vivid)
	var path := PackedVector2Array()
	var path_r := PackedVector2Array()
	for i in 21:
		var u := float(i) / 20.0
		var y := lerpf(740.0, 400.0, u)
		var x := 640.0 + sin(u * 3.2 + 0.4) * 110.0 * (1.0 - u * 0.4)
		var w := lerpf(120.0, 26.0, u)
		path.append(Vector2(x - w, y))
		path_r.append(Vector2(x + w, y))
	path_r.reverse()
	path.append_array(path_r)
	draw_colored_polygon(path, path_col)
	for i in 14:
		var u := fmod(i * 0.137, 1.0)
		var sp := Vector2(640.0 + sin(u * 3.2 + 0.4) * 110.0 * (1.0 - u * 0.4) + sin(i * 2.3) * 50.0 * (1.0 - u), lerpf(740.0, 400.0, u))
		_draw_ellipse(sp, Vector2(9, 5) * (1.0 - u * 0.6), path_col.darkened(0.12))

	# Grass tufts and tiny flowers (deterministic)
	var tuft := near.darkened(0.22)
	for i in 70:
		var gp := Vector2(fmod(i * 157.0, 1320.0) - 20, 400 + fmod(i * 89.0, 320.0))
		var sway := sin(_t * 1.3 + i) * 3.0
		for k in 3:
			draw_line(gp + Vector2((k - 1) * 4, 0), gp + Vector2((k - 1) * 7 + sway, -12 - k * 3), tuft, 2.5)
		if i % 6 == 0:
			var fc: Color = [Color("ffffff"), Color("ffc93c"), Color("ff8fb8")][i % 3]
			draw_circle(gp + Vector2(sway, -16), 4.0, fc.lerp(tuft, night * 0.7))

	# Stones and the watering can
	for st in [Vector3(560, 470, 14), Vector3(745, 520, 18), Vector3(470, 600, 12), Vector3(820, 615, 16)]:
		var sc := Color("c9c2b8").lerp(Color("3b3d55"), night * 0.8)
		_draw_ellipse(Vector2(st.x, st.y), Vector2(st.z, st.z * 0.6), sc)
		draw_arc(Vector2(st.x, st.y), st.z, PI + 0.3, TAU - 0.3, 10, Color(1, 1, 1, 0.35 * (1.0 - night)), 2.0)
	_draw_can(Vector2(1165, 650), night)

	# Beds: organic, different sizes, three depths
	for i in BED_POSITIONS.size():
		if hide_ui and beds[i] == null:
			continue
		var b: Vector2 = BED_POSITIONS[i]
		var k: float = BED_SCALE[i]
		var soil := Color("7a4a2e").lerp(Color("2a2430"), ev * 0.6)
		_draw_ellipse(b + Vector2(0, 14 * k), Vector2(118, 34) * k, Color(0, 0, 0, 0.12))
		_draw_ellipse(b + Vector2(0, 8 * k), Vector2(112, 32) * k, soil.darkened(0.3))
		_draw_ellipse(b + Vector2(0, 4 * k), Vector2(102, 25) * k, soil)
		for j in 6:
			draw_circle(b + Vector2((-70 + j * 28) * k, (4 + (j % 2) * 7) * k), 3.5 * k, soil.lightened(0.15))
		# little pebble rim
		for j in 9:
			var a := PI * 0.1 + PI * 0.8 * j / 8.0
			_draw_ellipse(b + Vector2(cos(a) * 110, sin(a) * 32 + 8) * k, Vector2(9, 6) * k, Color("bdb2a3").lerp(Color("3b3d55"), night * 0.8))
		if beds[i] == null and state != State.NIGHT:
			var glow := 0.5 + 0.5 * sin(_t * 3.0 + i)
			for g in 3:
				draw_circle(b + Vector2(0, -8 * k), (22 + g * 11 + glow * 6) * k, Color(1, 0.95, 0.6, (0.24 - g * 0.06) * (0.6 + glow * 0.4)))
			var bounce := absf(sin(_t * 2.0 + i)) * 5.0
			var grow := 1.0
			var sb := b
			if i == _rec_bed:
				var lvl := Audio.level
				grow = 1.0 + lvl * 0.9
				bounce = absf(sin(_t * 18.0)) * 12.0 * lvl + 3.0
				sb += Vector2(sin(_t * 31.0) * 6.0 * lvl, 0)
			var seed_c := sb + Vector2(0, (-8 - bounce) * k)
			_draw_ellipse(seed_c, Vector2(17, 22) * grow * k, Color("8a5a2b"))
			_draw_ellipse(seed_c, Vector2(14, 19) * grow * k, Color("e0a83e"))
			_draw_ellipse(seed_c + Vector2(-5, -7) * k, Vector2(4, 6) * k, Color(1, 1, 1, 0.55))
			draw_line(seed_c + Vector2(0, -19) * k, seed_c + Vector2(7, -32) * k, Color("4f8f3a"), 5.0 * k)
			_draw_ellipse(seed_c + Vector2(14, -34) * k, Vector2(10, 5) * k, Color("7cc86a"))
			for g in 3:
				var a := _t * 1.5 + TAU * g / 3.0 + i
				draw_circle(b + Vector2(cos(a) * 40, -12 + sin(a) * 16) * k, 3.0 * k, Color(1, 1, 0.8, 0.85 * glow))

	# Butterflies by day, fireflies at night
	if state == State.NIGHT or night > 0.3:
		for i in 18:
			var fp := Vector2(fmod(i * 233.0 + sin(_t * 0.4 + i) * 60.0, 1280.0), 300 + fmod(i * 71.0, 380.0) + cos(_t * 0.6 + i) * 30.0)
			var f := 0.5 + 0.5 * sin(_t * 2.5 + i * 1.7)
			draw_circle(fp, 10, Color(1, 1, 0.5, 0.15 * f))
			draw_circle(fp, 3.5, Color(1, 1, 0.6, 0.9 * f))
	elif weather != Weather.RAIN:
		for i in 3:
			var bp := Vector2(fmod(_t * 40.0 + i * 450.0, 1500.0) - 100, 250 + sin(_t * 0.9 + i * 2.0) * 80 + i * 40)
			var flap := absf(sin(_t * 12.0 + i))
			var bc: Color = [Color("ff8fb8"), Color("ffc93c"), Color("6fa8e8")][i]
			_draw_ellipse(bp + Vector2(-8 * flap, 0), Vector2(9 * flap + 1, 11), bc)
			_draw_ellipse(bp + Vector2(8 * flap, 0), Vector2(9 * flap + 1, 11), bc)
			draw_line(bp + Vector2(0, -7), bp + Vector2(0, 7), Color("3a2f40"), 2.5)

	if ev > 0.0:
		draw_rect(Rect2(-2000, -2000, 5280, 4720), Color(0.05, 0.05, 0.2, ev * 0.22))


## Foreground layer above the beings: framing leaves, rain, buttons.
func _draw_front() -> void:
	var ev := _evening()
	var night := clampf(ev * 2.0 - 1.0, 0.0, 1.0)
	var leaf := Color("3e7d3a").lerp(Color("10241f"), night)
	var leaf2 := Color("4f9442").lerp(Color("15302a"), night)
	# corner foliage frames the scene like a picture book
	var sw := sin(_t * 0.9) * 0.04
	for l in [Vector4(-30, 760, -1.2, 150), Vector4(20, 770, -0.8, 120), Vector4(-40, 700, -1.5, 110),
			Vector4(1310, 760, -1.95, 150), Vector4(1260, 775, -2.35, 120), Vector4(1320, 690, -1.65, 105)]:
		_front_leaf(Vector2(l.x, l.y), l.z + sw, l.w, leaf if int(l.w) % 2 == 0 else leaf2)
	for i in 18:
		var x := -20.0 + i * 78.0
		var h := 26.0 + fmod(i * 37.0, 22.0)
		var s := sin(_t * 1.2 + i) * 4.0
		_front.draw_colored_polygon(PackedVector2Array([Vector2(x - 12, 740), Vector2(x + s, 740 - h), Vector2(x + 12, 740)]), leaf2)

	if weather == Weather.RAIN:
		for r in _rain:
			_front.draw_line(r, r + Vector2(-6, 18), Color(0.85, 0.9, 1.0, 0.6), 2.0)

	if hide_ui:
		return
	# Buttons: thick icons on coloured discs
	var can_concert := _creature_count() >= 3 and state == State.DAY
	_draw_button(BTN_CONDUCTOR, Color("ff8a7a"), can_concert, state == State.CONCERT)
	_draw_baton(BTN_CONDUCTOR)
	var sun_active := weather == Weather.SUN or state == State.NIGHT
	_draw_button(BTN_SUN, Color("ffd45c"), state != State.CONCERT, sun_active)
	_draw_sun_icon(BTN_SUN)
	_draw_button(BTN_RAIN, Color("7fb6f0"), state == State.DAY, weather == Weather.RAIN)
	_draw_cloud_icon(BTN_RAIN)
	# parent button: small but clearly visible padlock
	_front.draw_circle(BTN_PARENT + Vector2(0, 3), 24, Color(0, 0, 0, 0.15))
	_front.draw_circle(BTN_PARENT, 24, Color("fbf6ee"))
	_front.draw_arc(BTN_PARENT, 24, 0, TAU, 32, Color("2f2a4a"), 3.0, true)
	_front.draw_arc(BTN_PARENT + Vector2(0, -4), 8, PI, TAU, 12, Color("2f2a4a"), 4.0, true)
	_front.draw_rect(Rect2(BTN_PARENT + Vector2(-11, -4), Vector2(22, 16)), Color("2f2a4a"))
	_front.draw_circle(BTN_PARENT + Vector2(0, 3), 3, Color("fbf6ee"))


func _front_leaf(at: Vector2, ang: float, length: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		pts.append(Vector2(u * length, -sin(u * PI) * length * 0.3))
	for i in range(11, 0, -1):
		var u := float(i) / 12.0
		pts.append(Vector2(u * length, sin(u * PI) * length * 0.3))
	for i in pts.size():
		pts[i] = at + pts[i].rotated(ang)
	_front.draw_colored_polygon(pts, col)
	_front.draw_line(at, at + Vector2(length * 0.85, 0).rotated(ang), col.lightened(0.15), 3.0, true)


func _rain_mood() -> float:
	return _rain_amount


func _draw_tree(base: Vector2, k: float, night: float, vivid: float) -> void:
	var trunk := Color("8a5a3b").lerp(Color("2a2430"), night * 0.8)
	var crown := Color("5fa14a").lerp(Color("1d3a3c"), night).lerp(Color("4f7a50"), 1.0 - vivid)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-14, 0) * k, base + Vector2(-9, -110) * k, base + Vector2(9, -110) * k, base + Vector2(14, 0) * k]), trunk)
	for b in [Vector3(-40, -130, 52), Vector3(36, -138, 50), Vector3(0, -180, 60), Vector3(-10, -120, 44)]:
		draw_circle(base + Vector2(b.x, b.y) * k, b.z * k, crown)
	draw_circle(base + Vector2(-22, -196) * k, 20 * k, crown.lightened(0.12))
	for a in [Vector2(-30, -150), Vector2(26, -170), Vector2(4, -128)]:
		draw_circle(base + a * k, 6 * k, Color("ff7a6b").lerp(crown, night * 0.8))


func _draw_fence(at: Vector2, night: float) -> void:
	var wood := Color("f0dfc0").lerp(Color("3b3d55"), night * 0.8)
	var line := wood.darkened(0.35)
	draw_line(at + Vector2(0, -26), at + Vector2(250, -32), line, 6.0)
	draw_line(at + Vector2(0, -26), at + Vector2(250, -32), wood, 3.0)
	for i in 7:
		var p := at + Vector2(i * 40, -i)
		var pts := PackedVector2Array([p + Vector2(-8, 0), p + Vector2(-8, -42), p + Vector2(0, -52), p + Vector2(8, -42), p + Vector2(8, 0)])
		draw_colored_polygon(pts, wood)
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, line, 2.0, true)


func _draw_can(at: Vector2, night: float) -> void:
	var c := Color("6fa8e8").lerp(Color("2a3558"), night * 0.8)
	var ink := c.darkened(0.45)
	draw_line(at + Vector2(30, -30), at + Vector2(74, -66), ink, 10.0)
	draw_line(at + Vector2(30, -30), at + Vector2(74, -66), c, 6.0)
	_draw_ellipse(at + Vector2(78, -68), Vector2(10, 6), c.lightened(0.2))
	var body := PackedVector2Array([at + Vector2(-36, 0), at + Vector2(-30, -62), at + Vector2(32, -62), at + Vector2(36, 0)])
	draw_colored_polygon(body, c)
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, ink, 3.0, true)
	draw_arc(at + Vector2(0, -62), 24, PI, TAU, 16, ink, 6.0, true)
	draw_circle(at + Vector2(-14, -40), 7, Color(1, 1, 1, 0.35))


func _draw_overlay() -> void:
	for cf in _confetti:
		if cf[2] > 0.0:
			var al: float = clampf(2.4 - float(cf[2]), 0.0, 1.0)
			var size: float = cf[5]
			var v: Vector2 = cf[1]
			var stretch := clampf(v.length() / 120.0, 1.0, 2.6)
			_overlay.draw_circle(cf[0], size * 1.8, Color(cf[3], 0.12 * al))
			var pts := PackedVector2Array()
			for i in 12:
				var a := TAU * i / 12.0
				pts.append(cf[0] + Vector2(cos(a) * size * stretch, sin(a) * size / stretch).rotated(v.angle()))
			_overlay.draw_colored_polygon(pts, Color(cf[3], al))
			if size >= 12.0:
				_overlay.draw_circle(cf[0] - v.normalized() * size * 0.3, size * 0.3, Color(1, 1, 1, 0.8 * al))
	# Recording overlay
	if state == State.RECORDING and _rec_bed >= 0:
		var c: Vector2 = BED_POSITIONS[_rec_bed] + Vector2(0, -130 * BED_SCALE[_rec_bed])
		var pulse := 1.0 + 0.08 * sin(_t * 8.0)
		var lvl := Audio.level
		for k in 3:
			_overlay.draw_arc(c, (70 + k * 22) * (0.8 + lvl * 0.6), 0, TAU, 48, Color(1, 1, 1, 0.55 - k * 0.15), 6.0, true)
		_overlay.draw_circle(c + Vector2(0, 5), 60 * pulse, Color(0, 0, 0, 0.15))
		_overlay.draw_circle(c, 60 * pulse, Color("ff6f91"))
		_overlay.draw_arc(c, 60 * pulse, 0, TAU, 48, Color("b83a6e"), 4.0, true)
		_overlay.draw_rect(Rect2(c + Vector2(-14, -34), Vector2(28, 46)), Color.WHITE)
		_overlay.draw_circle(c + Vector2(0, -34), 14, Color.WHITE)
		_overlay.draw_circle(c + Vector2(0, 12), 14, Color.WHITE)
		_overlay.draw_arc(c + Vector2(0, 2), 26, 0.1, PI - 0.1, 12, Color.WHITE, 6.0, true)
		_overlay.draw_line(c + Vector2(0, 28), c + Vector2(0, 42), Color.WHITE, 6.0)
		var prog := _rec_time / Audio.RECORD_SECONDS
		_overlay.draw_arc(c, 68, -PI / 2, -PI / 2 + TAU * prog, 48, Color("ffd45c"), 9.0, true)


func _draw_button(c: Vector2, col: Color, enabled: bool, active: bool) -> void:
	var since: float = _t - float(_presses.get(c, -10.0))
	if since < 0.5:
		_front.draw_arc(c, BTN_R + since * 80.0, 0, TAU, 40, Color(1, 1, 1, 0.8 * (1.0 - since * 2.0)), 6.0, true)
	var bounce := 0.0
	if active:
		bounce = absf(sin(_t * 5.0)) * 6.0
		_front.draw_arc(c, BTN_R + 10 + sin(_t * 4.0) * 3, 0, TAU, 40, Color("fff3a0"), 7.0, true)
	elif enabled:
		bounce = absf(sin(_t * 2.0 + c.x)) * 2.0
	if not enabled:
		col = col.lerp(Color("c9c4bd"), 0.7)
	var press := 1.0 - 0.12 * maxf(0.0, 1.0 - since * 5.0)
	var p := c - Vector2(0, bounce)
	_front.draw_circle(c + Vector2(0, 7), BTN_R, Color(0, 0, 0, 0.18))
	_front.draw_circle(p, BTN_R * press, col)
	_front.draw_arc(p, BTN_R * press, 0, TAU, 48, col.darkened(0.35), 5.0, true)
	_front.draw_arc(p, BTN_R * press - 9, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.5), 6.0, true)
	_btn_offset = Vector2(0, -bounce)
	_btn_alpha = 1.0 if enabled else 0.55


func _draw_baton(c: Vector2) -> void:
	c += _btn_offset
	var a := _btn_alpha
	var wave := sin(_t * 5.0) * 0.3 if a > 0.9 else 0.0
	var dir := Vector2.from_angle(-0.8 + wave)
	var ink := Color(0.17, 0.14, 0.27, a)
	_front.draw_line(c - dir * 30, c + dir * 26, ink, 14.0, true)
	_front.draw_line(c - dir * 30, c + dir * 26, Color(1, 1, 1, a), 8.0, true)
	var tip := c + dir * 30
	var pts := PackedVector2Array()
	for i in 10:
		var ang := TAU * i / 10.0 - PI / 2 + _t
		pts.append(tip + Vector2(cos(ang), sin(ang)) * (17.0 if i % 2 == 0 else 7.0))
	_front.draw_colored_polygon(pts, Color(1, 0.85, 0.25, a))
	var closed := pts.duplicate()
	closed.append(pts[0])
	_front.draw_polyline(closed, ink, 3.0, true)


func _draw_sun_icon(c: Vector2) -> void:
	c += _btn_offset
	var col := Color(1.0, 0.55, 0.15, _btn_alpha)
	for i in 8:
		var d := Vector2.from_angle(TAU * i / 8.0 + _t * 0.5)
		_front.draw_line(c + d * 28, c + d * 40, col, 8.0, true)
	_front.draw_circle(c, 21, col)
	_front.draw_circle(c + Vector2(-6, -6), 7, Color(1, 1, 1, 0.45 * _btn_alpha))


func _draw_cloud_icon(c: Vector2) -> void:
	c += _btn_offset
	var col := Color(1, 1, 1, _btn_alpha)
	_front.draw_circle(c + Vector2(-14, -6), 17, col)
	_front.draw_circle(c + Vector2(8, -13), 21, col)
	_front.draw_circle(c + Vector2(24, -1), 13, col)
	_front.draw_rect(Rect2(c + Vector2(-30, -6), Vector2(66, 18)), col)
	for k in 3:
		_front.draw_line(c + Vector2(-14 + k * 15, 20), c + Vector2(-19 + k * 15, 34), Color(0.17, 0.3, 0.6, _btn_alpha), 6.0, true)


func _gradient_rect(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _draw_hill(base_y: float, amp: float, freq: float, ph: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for x in range(-600, 1901, 40):
		pts.append(Vector2(x, base_y - amp * (0.5 + 0.5 * sin(x * freq + ph))))
	pts.append(Vector2(1900, 900))
	pts.append(Vector2(-600, 900))
	draw_colored_polygon(pts, col)


func _draw_cloud(c: Vector2, k: float, col: Color) -> void:
	for b in [Vector3(-40, 0, 28), Vector3(-10, -16, 36), Vector3(26, -6, 30), Vector3(52, 6, 20), Vector3(0, 8, 30)]:
		draw_circle(c + Vector2(b.x, b.y) * k, b.z * k, col)
	draw_circle(c + Vector2(-14, -24) * k, 14 * k, Color(1, 1, 1, col.a * 0.4))


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
	_panel.exporter = export_concert
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
