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
var _beat_time := 0.0
var _beat := 0
var _bass: AudioStreamWAV
var _pluck: AudioStreamWAV
var _plop: AudioStreamWAV
var _presses := {} ## button centre -> time pressed
var _confetti: Array = [] ## [pos, vel, age, color, spin]
var _overlay := Node2D.new()


func _ready() -> void:
	randomize()
	beds.resize(BED_POSITIONS.size())
	bed_data.resize(BED_POSITIONS.size())
	for i in 80:
		_rain.append(Vector2(randf() * 1400 - 60, randf() * 760))
	_bass = SoundLab.make_wav(SoundLab.instrument(0, SoundLab.BASE_FREQ / 2.0), 22050)
	_pluck = SoundLab.make_wav(SoundLab.instrument(1, SoundLab.BASE_FREQ * 2.0), 22050)
	_plop = SoundLab.make_wav(SoundLab.instrument(2, 520.0), 22050)
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
	var cols := [Color("ff7fa8"), Color("ffd84d"), Color("7fd6c2"), Color("9fd0ff"), Color("c98bd9")]
	for burst in 4:
		var origin := Vector2(240 + burst * 270, 200 + (burst % 2) * 60)
		for i in 22:
			var a := TAU * i / 22.0
			_confetti.append([origin, Vector2(cos(a), sin(a)) * randf_range(140, 260), -burst * 0.25, cols[(i + burst) % cols.size()], randf() * TAU])


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
	_tick_music(delta)
	for cf in _confetti:
		cf[2] += delta
		if cf[2] > 0.0:
			cf[0] += cf[1] * delta
			cf[1].y += 160.0 * delta
			cf[1] *= 0.985
	_confetti = _confetti.filter(func(cf): return cf[2] < 2.2)
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
	return clampf((day_time - DAY_LENGTH * 0.8) / (DAY_LENGTH * 0.2), 0.0, 1.0)


func _draw() -> void:
	var ev := _evening()
	var night := clampf(ev * 2.0 - 1.0, 0.0, 1.0)
	var dusk := clampf(ev * 2.0, 0.0, 1.0)
	var top := Color("5fb0e8").lerp(Color("7b6fc4"), dusk).lerp(Color("0f1436"), night)
	var bottom := Color("d4f0ff").lerp(Color("ffb36b"), dusk).lerp(Color("2b2f66"), night)
	if weather == Weather.RAIN:
		top = top.lerp(Color("66717f"), 0.55)
		bottom = bottom.lerp(Color("aab4bf"), 0.5)
	elif weather == Weather.SUN:
		bottom = bottom.lerp(Color("fff4c2"), 0.4)
	_gradient_rect(Rect2(-2000, -2000, 5280, 2000), top, top)
	_gradient_rect(Rect2(-2000, 0, 5280, 420), top, bottom)

	# Stars, moon, sun
	if night > 0.0:
		for i in 60:
			var sp := Vector2(fmod(i * 197.3, 1300.0) - 10, fmod(i * 83.7, 330.0))
			var tw := 0.6 + 0.4 * sin(_t * (1.5 + fmod(i, 3.0)) + i)
			draw_circle(sp, 1.2 + fmod(i, 3.0) * 0.6, Color(1, 1, 0.9, night * tw))
	if state == State.NIGHT:
		draw_circle(Vector2(640, 120), 46, Color("f6f1c8"))
		draw_circle(Vector2(664, 104), 40, top.lerp(bottom, 0.25))
	else:
		var sun_c := Vector2(640, lerpf(120.0, 360.0, ev))
		var sun_col := Color("ffe27a").lerp(Color("ff8a4a"), ev)
		var halo := 1.0 if weather != Weather.RAIN else 0.3
		if weather == Weather.RAIN:
			sun_col = Color(sun_col, 0.35)
		for k in 4:
			draw_circle(sun_c, 60 + k * 28 + sin(_t * 1.5) * 4, Color(sun_col, 0.10 * halo))
		for i in 12:
			var d := Vector2.from_angle(TAU * i / 12.0 + _t * 0.15)
			draw_line(sun_c + d * 62, sun_c + d * (78 + 6 * sin(_t * 2.0 + i)), Color(sun_col, 0.7 * halo), 5.0)
		draw_circle(sun_c, 52, sun_col)
		draw_circle(sun_c + Vector2(-14, -14), 22, Color(1, 1, 1, 0.25))

	# Drifting clouds
	var cloud_col := Color(1, 1, 1, 0.9).lerp(Color("c9a0b8"), dusk * 0.5).lerp(Color("39406e"), night)
	if weather == Weather.RAIN:
		cloud_col = Color("8e98a6")
	for i in 5:
		var speed := 8.0 + i * 3.0
		var x := fmod(i * 330.0 + _t * speed, 1700.0) - 250.0
		_draw_cloud(Vector2(x, 70 + fmod(i * 61.0, 160.0)), 0.7 + fmod(i * 0.37, 0.6), cloud_col)

	# Layered hills with soft gradients
	var far := Color("9fd48a").lerp(Color("c7a487"), dusk * 0.4).lerp(Color("23334f"), night)
	var mid := Color("7cc46a").lerp(Color("b08a62"), dusk * 0.3).lerp(Color("1d3a3c"), night)
	var near := Color("6bb85a").lerp(Color("8a7a4a"), dusk * 0.3).lerp(Color("183232"), night)
	_draw_hill(330, 120, 0.004, 1.0, far)
	_draw_hill(370, 60, 0.007, 2.3, mid)
	_gradient_rect(Rect2(-2000, 390, 5280, 2400), near.lightened(0.08), near.darkened(0.12))
	draw_rect(Rect2(-2000, 2790, 5280, 2000), near.darkened(0.12))

	# Grass tufts and tiny flowers (deterministic)
	var tuft := near.darkened(0.18)
	for i in 70:
		var gp := Vector2(fmod(i * 157.0, 1320.0) - 20, 400 + fmod(i * 89.0, 320.0))
		var sway := sin(_t * 1.3 + i) * 3.0
		for k in 3:
			draw_line(gp + Vector2((k - 1) * 4, 0), gp + Vector2((k - 1) * 7 + sway, -12 - k * 3), tuft, 2.0)
		if i % 6 == 0:
			var fc: Color = [Color("ffffff"), Color("ffd84d"), Color("ff9ec4")][i % 3]
			draw_circle(gp + Vector2(sway, -16), 3.5, fc.lerp(tuft, night * 0.7))

	# Beds
	for i in BED_POSITIONS.size():
		var b: Vector2 = BED_POSITIONS[i]
		var soil := Color("7a5236").lerp(Color("2a2430"), ev * 0.6)
		_draw_ellipse(b + Vector2(0, 14), Vector2(102, 30), Color(0, 0, 0, 0.12))
		_draw_ellipse(b + Vector2(0, 8), Vector2(98, 28), soil.darkened(0.25))
		_draw_ellipse(b + Vector2(0, 5), Vector2(90, 22), soil)
		for k in 5:
			draw_circle(b + Vector2(-60 + k * 30, 6 + (k % 2) * 6), 3, soil.lightened(0.15))
		if beds[i] == null and state != State.NIGHT:
			var glow := 0.5 + 0.5 * sin(_t * 3.0 + i)
			for k in 3:
				draw_circle(b + Vector2(0, -6), 18 + k * 9 + glow * 6, Color(1, 0.95, 0.6, (0.22 - k * 0.06) * (0.6 + glow * 0.4)))
			var bounce := absf(sin(_t * 2.0 + i)) * 4.0
			var grow := 1.0
			if i == _rec_bed:
				var lvl := Audio.level
				grow = 1.0 + lvl * 0.9
				bounce = absf(sin(_t * 18.0)) * 10.0 * lvl + 3.0
				b += Vector2(sin(_t * 31.0) * 5.0 * lvl, 0)
			_draw_ellipse(b + Vector2(0, -6 - bounce), Vector2(14, 18) * grow, Color("e0a83e"))
			_draw_ellipse(b + Vector2(-4, -12 - bounce), Vector2(4, 6), Color(1, 1, 1, 0.5))
			draw_line(b + Vector2(0, -22 - bounce), b + Vector2(6, -34 - bounce), Color("5aa64b"), 4.0)
			_draw_ellipse(b + Vector2(11, -36 - bounce), Vector2(8, 4), Color("6cc15a"))
			for k in 3:
				var a := _t * 1.5 + TAU * k / 3.0 + i
				draw_circle(b + Vector2(cos(a) * 34, -10 + sin(a) * 14), 2.5, Color(1, 1, 0.8, 0.8 * glow))

	# Butterflies by day, fireflies at night
	if state == State.NIGHT or night > 0.3:
		for i in 18:
			var fp := Vector2(fmod(i * 233.0 + sin(_t * 0.4 + i) * 60.0, 1280.0), 300 + fmod(i * 71.0, 380.0) + cos(_t * 0.6 + i) * 30.0)
			var f := 0.5 + 0.5 * sin(_t * 2.5 + i * 1.7)
			draw_circle(fp, 9, Color(1, 1, 0.5, 0.15 * f))
			draw_circle(fp, 3, Color(1, 1, 0.6, 0.9 * f))
	elif weather != Weather.RAIN:
		for i in 3:
			var bp := Vector2(fmod(_t * 40.0 + i * 450.0, 1500.0) - 100, 250 + sin(_t * 0.9 + i * 2.0) * 80 + i * 40)
			var flap := absf(sin(_t * 12.0 + i))
			var bc: Color = [Color("ffb3d1"), Color("ffd84d"), Color("9fd0ff")][i]
			_draw_ellipse(bp + Vector2(-7 * flap, 0), Vector2(8 * flap + 1, 10), bc)
			_draw_ellipse(bp + Vector2(7 * flap, 0), Vector2(8 * flap + 1, 10), bc)
			draw_line(bp + Vector2(0, -6), bp + Vector2(0, 6), Color("3a2f40"), 2.0)

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
	for cf in _confetti:
		if cf[2] > 0.0:
			var al: float = clampf(2.2 - float(cf[2]), 0.0, 1.0)
			var d := Vector2.from_angle(float(cf[4]) + float(cf[2]) * 6.0) * 7.0
			_overlay.draw_line(cf[0] - d, cf[0] + d, Color(cf[3], al), 5.0)
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
	var since: float = _t - float(_presses.get(c, -10.0))
	if since < 0.5:
		draw_circle(c, BTN_R + since * 70.0, Color(1, 1, 1, 0.5 * (1.0 - since * 2.0)))
	var bob := sin(_t * 2.0 + c.x) * 3.0 if enabled else 0.0
	if active:
		draw_circle(c, BTN_R + 10 + sin(_t * 4.0) * 4, Color(1, 0.95, 0.5, 0.45))
	draw_circle(c + Vector2(0, 6), BTN_R, Color(0, 0, 0, 0.15 * a))
	var press := 1.0 - 0.12 * maxf(0.0, 1.0 - since * 5.0)
	draw_circle(c + Vector2(0, bob * 0.3), BTN_R * press, Color(1, 1, 1, 0.9 * a))


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


func _gradient_rect(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _draw_hill(base_y: float, amp: float, freq: float, ph: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for x in range(-200, 1501, 40):
		pts.append(Vector2(x, base_y - amp * (0.5 + 0.5 * sin(x * freq + ph))))
	pts.append(Vector2(1500, 900))
	pts.append(Vector2(-200, 900))
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
