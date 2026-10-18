extends Node2D
## The garden: 6 beds, weather, concert, day/night cycle, persistence.

const Creature := preload("res://scripts/creature.gd")
const ParentPanel := preload("res://scripts/parent_panel.gd")

const SAVE_PATH := "user://garden.json"
## Organic layout on three depths: back, middle, front.
const BED_POSITIONS := [
	Vector2(330, 445), Vector2(960, 438),
	Vector2(150, 568), Vector2(1110, 560),
	Vector2(500, 650), Vector2(790, 648),
]
const BED_SCALE := [0.9, 0.9, 1.04, 1.04, 1.14, 1.14]
## Tall or wide species are toned down so neighbours never cover each other.
const SPECIES_SCALE := [1.0, 1.0, 0.95, 1.0, 1.0, 0.85, 0.92, 0.94, 0.98]
const BTN_CONDUCTOR := Vector2(95, 95)
const BTN_SUN := Vector2(1035, 95)
const BTN_RAIN := Vector2(1170, 95)
const BTN_PARENT := Vector2(1240, 200)
const BTN_HELP := Vector2(1240, 268)
const BTN_ECHO := Vector2(95, 235)
const BTN_R := 56.0
const CAN_HOME := Vector2(1050, 682)
const MAX_GROWTH := 0.25 ## watering makes a being up to 25 % bigger

enum Weather { NONE, SUN, RAIN }
enum State { DAY, RECORDING, CONCERT, NIGHT, ECHO }
enum Season { SPRING, SUMMER, AUTUMN, WINTER }

## Per season: near, mid, mid2, far ground, tree crown, fruit, path, flower count.
const SEASONS := [
	[Color("8fd16a"), Color("86cf6c"), Color("7cc862"), Color("a8dc90"), Color("7cc86a"), Color("ffb3d1"), Color("ecd6a8"), 70],
	[Color("7fbd5a"), Color("7cc260"), Color("6db654"), Color("9bd47a"), Color("5fa14a"), Color("ff7a6b"), Color("e9d3a6"), 40],
	[Color("b5b25a"), Color("c9a24a"), Color("b8913e"), Color("d6b884"), Color("e08a3c"), Color("c0392b"), Color("dcc59a"), 8],
	[Color("f4f1ec"), Color("dce6f0"), Color("c8d6e6"), Color("e6edf5"), Color("3f6b55"), Color("ffffff"), Color("cdd6e2"), 0],
]

var state := State.DAY
var weather := Weather.NONE
var day_time := 0.0
var beds: Array = [] ## creature node or null per bed
var bed_data: Array = [] ## saved description per bed or null
var settings := {"mic": true, "volume": 0.8, "day_minutes": 6, "lang": "", "season": -1}

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
var _flashes: Array = [] ## [pos, age]
var _shake := 0.0
var hide_ui := false
var _pad_active := false
var screenshot_mode := false ## store/trailer captures: no automatic season change
var _bed_fronts: Array[Node2D] = []
var _focus := 4
var _stick_time := -1.0
# Echo game ("sing it back")
var _echo_listen := false
var _mic_pos := Vector2.ZERO
var _rec_len := 2.5
var _echo_seq: Array = []
var _echo_pos := 0
var _echo_waiting := false
var _echo_result := 0 ## 0 waiting, 1 done right, 2 needs a replay
var _echo_idle := 0.0
var season := Season.SUMMER
var _auto_season := 1
var _season_parts: Array = [] ## falling petals / leaves / snow: [pos, phase] ## key art: no buttons, no empty beds
var _overlay := Node2D.new()
var _can_held := false
var _can_pos := CAN_HOME
var _pour := 0.0 ## seconds left of the pouring animation
var _pour_drops: Array = [] ## [pos, vel, age]
var _water_save := 0.0
var _ev_smooth := 0.0
var _paper_mat: ShaderMaterial
var _stage_light := 0.0 ## concert: dim the edges, spotlight the singers
var _cam := Camera2D.new()
var _cam_target := Vector2(640, 360)
var _cam_zoom := 1.0
var _spots: Array = [] ## [world pos, alpha, width] spotlights on singers
var _song_rings: Array = [] ## [age, colour] pond rings, one per sung note
var _wet: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0] ## per bed: freshly watered soil darkens, then dries
var _beat_kick := 0.0 ## flowers and grass nod on the beat
var _season_fade := 0.0 ## paper wash when the season changes
const HELP_STEP := 4.0 ## seconds per bubble in the help tour
var _help_all := 0.0 ## seconds left in the help tour (one bubble at a time)
var _help_one := {} ## help key -> seconds left (a single bubble)
var _help_font: Font
const FRIENDS := {0: 3, 3: 0, 2: 5, 5: 2, 4: 8, 8: 4, 6: 7, 7: 6, 1: 0} ## species pairs that sing a duet
const STONES := [Vector3(612, 470, 14), Vector3(640, 528, 17), Vector3(655, 590, 12), Vector3(905, 520, 16)]
const MILL := Vector2(600, 233)
const TREE_CROWN := Vector2(232, 270)
const POND := Vector2(1195, 452)
var _hold_t := -1.0 ## finger held down on a being: after a second it turns back into a seed
var _hold_p := Vector2.ZERO
var _hold_bed := -1
var _last_input := 0.0
var _mill_angle := 0.0
var _mill_boost := 0.0
var _tree_shake := 0.0
var _apples: Array = [] ## [pos, vel, age]
var _worms := {} ## stone index -> age
var _hog_curl := 0.0
var _silent_recs := 0
var _last_singer: Node2D
var _can_goal := Vector2.ZERO ## finger position: the can glides after it instead of jumping
var _can_follow := false
var _can_drag := false ## the can was picked up with this touch: letting go over a being waters it
var _echo_taps := false ## the microphone heard nothing: this echo game continues with taps
var _state_time := 0.0
var _last_state := State.DAY


## Minh Nguyen Studios intro: full on the very first start, short afterwards.
## Skipped when the garden runs inside a test or tool scene.
func _studio_intro() -> void:
	if get_tree().current_scene != self or screenshot_mode:
		return
	var first: bool = not settings.get("intro_seen", false)
	var intro := MinhStudioIntro.play(self, load("res://addons/minh_studio_intro/presets/klanggarten.tres"),
		MinhStudioIntro.Mode.FULL if first else MinhStudioIntro.Mode.SHORT)
	settings.intro_seen = true
	_save()
	await intro.fade_started


## Deeper beds draw behind; a bed's front lip shares its being's z and is added later.
func _bed_z(i: int) -> int:
	return int(BED_POSITIONS[i].y / 40.0) - 8


func _ready() -> void:
	randomize()
	# Full screen for players; tests and tools pass --windowed.
	if not "--windowed" in OS.get_cmdline_args() and not OS.has_feature("editor"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
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
	_paper_mat = mat
	rect.material = mat
	paper.add_child(rect)
	add_child(paper)
	for i in BED_POSITIONS.size():
		var bf := Node2D.new()
		bf.position = BED_POSITIONS[i]
		bf.z_index = _bed_z(i)
		bf.draw.connect(_draw_bed_front.bind(bf, i))
		add_child(bf)
		_bed_fronts.append(bf)
	_front.z_index = 9
	_front.draw.connect(_draw_front)
	add_child(_front)
	_cam.position = Vector2(640, 360)
	add_child(_cam)
	_cam.make_current()
	_overlay.z_index = 10
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -3.0
	AudioServer.add_bus_effect(0, lim)
	_load()
	Audio.set_volume(settings.volume)
	_apply_language()
	_apply_season()
	_apply_season()
	await _studio_intro()
	_greet()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed)):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if _pad_input(event):
		return
	if event is InputEventMouseMotion:
		if _can_held and _pour <= 0.0:
			_can_goal = get_global_mouse_position()
			_can_follow = true
		if int(_t * 10) % 2 == 0:
			for c in beds:
				if c:
					c.look_toward(get_global_mouse_position())
	if event is InputEventMouseButton and not event.pressed:
		_hold_t = -1.0
		if _can_drag and _can_held and event.position.distance_to(CAN_HOME) > 90.0:
			_can_pos = get_global_mouse_position()
			_use_can(_can_pos)
		_can_drag = false
		_can_follow = false
	if event is InputEventMouseMotion and _hold_t >= 0.0 and event.position.distance_to(_hold_p) > 40.0:
		_hold_t = -1.0
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_pad_active = false
	if _can_held:
		_can_pos = get_global_mouse_position()
	_press_at(get_global_mouse_position())


# ---------------------------------------------------------------- gamepad (Steam Deck)

## Points a gamepad can select: the round buttons and every bed.
func _focus_targets() -> Array:
	var t := [BTN_CONDUCTOR, BTN_ECHO, BTN_SUN, BTN_RAIN]
	for i in BED_POSITIONS.size():
		var c = beds[i]
		t.append(BED_POSITIONS[i] + Vector2(0, -c.height() * 0.5) if c else BED_POSITIONS[i] + Vector2(0, -10))
	t.append(CAN_HOME + Vector2(0, -35))
	return t


func _pad_input(event: InputEvent) -> bool:
	var dir := Vector2.ZERO
	if event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_A:
				_pad_active = true
				_press_at(_focus_targets()[_focus])
				return true
			JOY_BUTTON_START:
				_open_parent_gate()
				return true
			JOY_BUTTON_DPAD_LEFT: dir = Vector2.LEFT
			JOY_BUTTON_DPAD_RIGHT: dir = Vector2.RIGHT
			JOY_BUTTON_DPAD_UP: dir = Vector2.UP
			JOY_BUTTON_DPAD_DOWN: dir = Vector2.DOWN
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.6 and event.axis <= JOY_AXIS_LEFT_Y:
		if _t - _stick_time < 0.25:
			return true
		_stick_time = _t
		dir = Vector2(signf(event.axis_value), 0) if event.axis == JOY_AXIS_LEFT_X else Vector2(0, signf(event.axis_value))
	if dir == Vector2.ZERO:
		return false
	_pad_active = true
	_move_focus(dir)
	if _can_held:
		_can_pos = _focus_targets()[_focus]
	return true


## Picks the nearest target roughly in the pressed direction.
func _move_focus(dir: Vector2) -> void:
	var targets := _focus_targets()
	var from: Vector2 = targets[_focus]
	var best := -1
	var best_score := INF
	for i in targets.size():
		if i == _focus:
			continue
		var d: Vector2 = targets[i] - from
		var along := d.dot(dir)
		if along <= 10.0:
			continue
		var score := along + absf(d.cross(dir)) * 2.0
		if score < best_score:
			best_score = score
			best = i
	if best >= 0:
		_focus = best
		Audio.play_music(_plop, 4.0 + _shift(), -6.0)


func _press_at(p: Vector2) -> void:
	for btn in [BTN_CONDUCTOR, BTN_SUN, BTN_RAIN, BTN_ECHO]:
		if p.distance_to(btn) < BTN_R:
			_presses[btn] = _t
	_last_input = _t
	Audio.play_music(_plop, randf_range(-2.0, 2.0) + _shift(), 2.0)
	if p.distance_to(BTN_PARENT) < 34:
		_open_parent_gate()
		return
	if p.distance_to(BTN_HELP) < 30:
		_help_all = 0.0 if _help_all > 0.0 else HELP_STEP * _help_items().size()
		_help_one.clear()
		return
	match state:
		State.RECORDING, State.CONCERT:
			return
		State.ECHO:
			if p.distance_to(BTN_ECHO) < BTN_R:
				_end_echo()
				return
			_echo_tap(p)
			return
		State.NIGHT:
			if p.distance_to(BTN_SUN) < BTN_R:
				_wake_up()
			return
	if _can_held:
		_use_can(p)
		return
	if p.distance_to(CAN_HOME + Vector2(10, -35)) < 100:
		_can_drag = true
		_can_held = true
		_can_pos = p
		Audio.play_music(_pluck, _shift(), -4.0)
		return
	if p.distance_to(BTN_SUN) < BTN_R:
		_set_weather(Weather.NONE if weather == Weather.SUN else Weather.SUN)
		return
	if p.distance_to(BTN_RAIN) < BTN_R:
		_set_weather(Weather.NONE if weather == Weather.RAIN else Weather.RAIN)
		return
	if p.distance_to(BTN_ECHO) < BTN_R:
		if _creature_count() >= 2:
			_echo_game()
		else:
			_help_one["HELP_ECHO"] = 4.0
		return
	if p.distance_to(BTN_CONDUCTOR) < BTN_R:
		if _creature_count() >= 3:
			_concert()
		else:
			_help_one["HELP_CONDUCTOR"] = 4.0
		return
	if _tap_toy(p):
		return
	for i in BED_POSITIONS.size():
		var c = beds[i]
		if c:
			var hit := Rect2(BED_POSITIONS[i] + Vector2(-c.radius() - 20, -c.height() - 20), Vector2(c.radius() * 2 + 40, c.height() + 50))
			if hit.has_point(p):
				c.cheer()
				c.sing(_shift())
				_hold_t = _t
				_hold_p = p
				_hold_bed = i
				_duet(c)
				for o in beds:
					if o and o != c:
						o.look_toward(c.global_position + Vector2(0, -c.height() * 0.6))
				return
		elif p.distance_to(BED_POSITIONS[i]) < 105 * BED_SCALE[i]:
			_plant(i)
			return


# ---------------------------------------------------------------- flow

func _plant(i: int) -> void:
	# Before iOS shows its permission dialog, tell the grown-up what is coming.
	if settings.mic and OS.get_name() == "iOS" and not settings.get("mic_intro", false):
		settings.mic_intro = true
		_save()
		_help_one["MIC_ASK"] = 9.0
		_grow_preset(i)
		return
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
		_silent_recs += 1
		if _silent_recs >= 1:
			_help_one["HELP_MIC"] = 7.0 # tells parents the microphone hears nothing
		_grow_preset(bed)
		return
	_silent_recs = 0
	var file := "bed_%d_%d.pcm" % [bed, Time.get_unix_time_from_system()]
	_write_pcm(file, res.samples)
	bed_data[bed] = {"pitch": res.pitch, "loud": res.loud, "freq": res.freq, "file": file, "rate": rate}
	_spawn(bed, SoundLab.make_wav(res.samples, rate), true)
	_save()


## Holding the can: tap a being to water it, anywhere else puts the can back.
func _use_can(p: Vector2) -> void:
	for i in BED_POSITIONS.size():
		if beds[i] and _bed_hit(i).has_point(p):
			_water_bed(i)
			return
	_can_held = false
	_can_pos = CAN_HOME


func _bed_hit(i: int) -> Rect2:
	var c = beds[i]
	return Rect2(BED_POSITIONS[i] + Vector2(-c.radius() - 45, -c.height() - 40), Vector2(c.radius() * 2 + 90, c.height() + 90))


func _water_bed(i: int) -> void:
	_can_follow = false
	var c = beds[i]
	var d: Dictionary = bed_data[i]
	_can_pos = BED_POSITIONS[i] + Vector2(105, -c.height() - 30)
	_pour = 1.1
	for k in 34:
		_pour_drops.append([_can_pos + Vector2(-100, 8), Vector2(randf_range(-50, 10), randf_range(-20, 30)), -k * 0.03])
	var was := float(d.get("water", 1.0))
	# a thirsty being just recovers; a happy one gets a little bigger
	if was > 0.5:
		d["size"] = minf(MAX_GROWTH, float(d.get("size", 0.0)) + 0.05)
	d["water"] = 1.0
	_wet[i] = 1.0
	get_tree().create_timer(1.2).timeout.connect(_can_fly_home)
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(c):
			c.water()
			_apply_bed_scale(i, true)
			c.sing(_shift()))
	Audio.play_music(_plop, 7.0 + _shift(), 0.0)
	_save()


## After pouring, the can hops back onto its slab in a little arc.
func _can_fly_home() -> void:
	if not _can_held:
		return
	var from := _can_pos
	var tw := create_tween()
	tw.tween_method(func(u: float):
		_can_pos = from.lerp(CAN_HOME + Vector2(0, -30), u) + Vector2(0, -sin(u * PI) * 90.0), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_can_held = false
		_can_pos = CAN_HOME
		Audio.play_music(_plop, _shift() - 5.0, -4.0))


func _apply_bed_scale(i: int, animate: bool) -> void:
	var c = beds[i]
	if not c:
		return
	var d: Dictionary = bed_data[i]
	var target: Vector2 = Vector2.ONE * BED_SCALE[i] * SPECIES_SCALE[c.species] * (1.0 + float(d.get("size", 0.0)))
	if animate:
		c.create_tween().tween_property(c, "scale", target, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	else:
		c.scale = target


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
	c.z_index = _bed_z(i)
	c.setup(pitch, loud, wav, freq)
	c.scale = Vector2.ONE * BED_SCALE[i] * SPECIES_SCALE[c.species] * (1.0 + float(d.get("size", 0.0)))
	c.thirst = 1.0 - float(d.get("water", 1.0))
	c.season = season
	if d.has("voice"):
		var vs := _read_pcm(str(d.voice))
		if not vs.is_empty():
			c.stream = SoundLab.make_wav(vs, int(d.get("vrate", 44100)))
			c.freq = float(d.get("vfreq", c.freq))
	if fresh and not d.has("gold"):
		d["gold"] = randf() < 0.08 # now and then a rare golden one
	c.golden = bool(d.get("gold", false))
	add_child(c)
	if i < _bed_fronts.size():
		move_child(_bed_fronts[i], -1) # lip right after its being
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
	if not settings.get("help_seen", false) and not screenshot_mode:
		settings.help_seen = true
		_help_all = HELP_STEP * _help_items().size()
		_save()
	var delay := 0.6
	for i in beds.size():
		var c = beds[i]
		if c:
			c.grow = 0.0
			get_tree().create_timer(delay).timeout.connect(func():
				if is_instance_valid(c):
					c.grow_in(1.0, false)
					c.sing(_shift())
					c.celebrate_hop(1.1))
			delay += 0.5


func _concert() -> void:
	state = State.CONCERT
	var beat := 60.0 / _bpm()
	var singers := beds.filter(func(c): return c != null)
	# the stage: edges dim, the camera leans in
	create_tween().tween_property(self, "_stage_light", 1.0, 0.6)
	_cam_zoom = 1.12
	await get_tree().create_timer(0.5).timeout
	# Round 1: one after another, like a melody; spotlight and camera follow.
	for c in singers:
		if is_instance_valid(c):
			_spotlight(c)
			_cam_target = Vector2(640, 360).lerp(c.global_position + Vector2(0, -80), 0.2)
			c.sing(_shift())
		await get_tree().create_timer(beat).timeout
	# Round 2: in pairs, like little chords.
	for k in range(0, singers.size(), 2):
		var mid := Vector2.ZERO
		var pair := singers.slice(k, k + 2)
		for c in pair:
			if is_instance_valid(c):
				_spotlight(c)
				mid += c.global_position / pair.size()
				c.sing(_shift())
		_cam_target = Vector2(640, 360).lerp(mid + Vector2(0, -80), 0.15)
		await get_tree().create_timer(beat).timeout
	# Finale: everyone together, lights up, wide shot, then fireworks.
	_cam_target = Vector2(640, 360)
	_cam_zoom = 1.0
	create_tween().tween_property(self, "_stage_light", 0.0, 0.4)
	for c in singers:
		if is_instance_valid(c):
			_spotlight(c)
			c.sing(_shift(), 1)
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
	_cam_target = Vector2(640, 360)
	_cam_zoom = 1.0
	if state == State.CONCERT:
		state = State.DAY


func _spotlight(c: Node2D) -> void:
	_spots.append([c.global_position, 1.0, c.radius() + 40.0])


## Echo game: creatures sing a short phrase, the child sings it back (microphone)
## or taps the singers in order (no microphone). There is no failing: a miss
## simply replays the phrase. Three phrases, each a little longer.
func _echo_game() -> void:
	state = State.ECHO
	_echo_taps = false
	var beat := 60.0 / _bpm()
	var singers := beds.filter(func(c): return c != null)
	# little ones start with a single note; after a few games phrases get longer
	var level := 1 if int(settings.get("echo_games", 0)) >= 3 else 0
	settings.echo_games = int(settings.get("echo_games", 0)) + 1
	_save()
	for round_i in 3:
		var length := mini(1 + round_i + level, 4)
		_echo_seq.clear()
		for k in length:
			var pick = singers[randi() % singers.size()]
			while singers.size() > 1 and not _echo_seq.is_empty() and pick == _echo_seq[-1]:
				pick = singers[randi() % singers.size()]
			_echo_seq.append(pick)
		var tries := 0
		while true:
			await get_tree().create_timer(beat).timeout
			if state != State.ECHO:
				return
			await _echo_play_phrase(beat)
			if state != State.ECHO:
				return
			var ok := false
			if settings.mic and not _echo_taps:
				ok = await _echo_listen_voice()
				if not ok:
					_echo_taps = true # nothing heard: tap the singers instead, never wait in silence
					ok = await _echo_wait_taps()
			else:
				ok = await _echo_wait_taps()
			if state != State.ECHO:
				return
			tries += 1
			if ok or tries >= 3:
				break
		for c in singers:
			if is_instance_valid(c):
				c.cheer()
				c.celebrate_hop(randf() * 0.1)
		_mini_burst(_echo_seq[0].global_position + Vector2(0, -_echo_seq[0].height() - 40))
		await get_tree().create_timer(beat * 2.0).timeout
	_fireworks()
	await get_tree().create_timer(beat * 3.0).timeout
	if state == State.ECHO:
		state = State.DAY


func _end_echo() -> void:
	if _echo_listen:
		Audio.stop_recording()
	_echo_listen = false
	_echo_waiting = false
	state = State.DAY


func _echo_play_phrase(beat: float) -> void:
	for c in _echo_seq:
		if not is_instance_valid(c):
			continue
		c.highlight()
		c.sing(_shift())
		await get_tree().create_timer(beat).timeout


## Microphone: listen while the first singer "holds the mic". Any answer counts.
func _echo_listen_voice() -> bool:
	var first = _echo_seq[0]
	_mic_pos = first.global_position + Vector2(0, -first.height() - 70)
	_rec_len = 1.6 + 0.6 * _echo_seq.size()
	_rec_time = 0.0
	_echo_listen = true
	Audio.start_recording()
	while _rec_time < _rec_len and state == State.ECHO:
		await get_tree().process_frame
		_rec_time += get_process_delta_time()
	var raw := Audio.stop_recording()
	_echo_listen = false
	var res := SoundLab.analyze(raw, Audio.mix_rate())
	if res.is_empty():
		return false
	# the first singer answers with the child's own voice and keeps it from now on
	var voice := SoundLab.make_wav(res.samples, Audio.mix_rate())
	Audio.play(voice, res.freq, _shift())
	_give_voice(first, res)
	if is_instance_valid(first):
		first.cheer()
	await get_tree().create_timer(minf(2.0, res.samples.size() / float(Audio.mix_rate()))).timeout
	return true


## A being keeps the voice the child sang to it (saved, so it stays after restart).
func _give_voice(c: Node2D, res: Dictionary) -> void:
	var i := beds.find(c)
	if i < 0 or bed_data[i] == null:
		return
	var d: Dictionary = bed_data[i]
	if d.has("voice"):
		DirAccess.remove_absolute("user://" + str(d.voice))
	var file := "voice_%d_%d.pcm" % [i, Time.get_unix_time_from_system()]
	_write_pcm(file, res.samples)
	d["voice"] = file
	d["vrate"] = Audio.mix_rate()
	d["vfreq"] = res.freq
	c.stream = SoundLab.make_wav(res.samples, Audio.mix_rate())
	c.freq = res.freq
	_save()


## No microphone: tap the singers in the same order.
func _echo_wait_taps() -> bool:
	_echo_pos = 0
	_echo_result = 0
	_echo_waiting = true
	_echo_idle = 0.0
	for c in _echo_seq:
		if is_instance_valid(c):
			c.invite()
	while _echo_result == 0 and state == State.ECHO:
		await get_tree().process_frame
		_echo_idle += get_process_delta_time()
		if _echo_idle > 15.0:
			state = State.DAY # nobody is playing: quietly leave the game
	_echo_waiting = false
	return _echo_result == 1


func _echo_tap(p: Vector2) -> void:
	if not _echo_waiting:
		return
	for i in BED_POSITIONS.size():
		var c = beds[i]
		if c == null:
			continue
		var hit := Rect2(BED_POSITIONS[i] + Vector2(-c.radius() - 20, -c.height() - 20), Vector2(c.radius() * 2 + 40, c.height() + 50))
		if not hit.has_point(p):
			continue
		_echo_idle = 0.0
		c.cheer()
		c.sing(_shift())
		if c == _echo_seq[_echo_pos]:
			_echo_pos += 1
			if _echo_pos >= _echo_seq.size():
				_echo_result = 1
		else:
			_echo_result = 2 # gently replay the phrase
		return


func _mini_burst(origin: Vector2) -> void:
	var cols := [Color("ffc93c"), Color("ff8fb8"), Color("ffffff")]
	for i in 16:
		var a := TAU * i / 16.0
		_confetti.append([origin, Vector2(cos(a), sin(a)) * 180.0, 0.0, cols[i % 3], 0.0, 8.0])
	_flashes.append([origin, 0.0])


func _fireworks() -> void:
	var sets := [[Color("ff7a6b"), Color("ffc93c"), Color("fff3a0")], [Color("4cc3b5"), Color("6fa8e8"), Color("ffffff")],
		[Color("9b6bd6"), Color("ff8fb8"), Color("ffe066")], [Color("7cc86a"), Color("ffc93c"), Color("ffffff")]]
	var beat := 60.0 / _bpm()
	_rain_amount = minf(_rain_amount, 0.2) # clear the grey for the finale
	for burst in 3:
		var origin := Vector2(640 + [-170, 170, 0][burst], [190.0, 190.0, 130.0][burst])
		var cols: Array = sets[burst]
		for i in 36:
			var a := TAU * i / 36.0
			var size: float = [7.0, 10.0, 15.0][i % 3]
			_confetti.append([origin, Vector2(cos(a), sin(a)) * (330.0 - size * 7.0), 0.0, cols[i % 3], 0.0, size])
		_flashes.append([origin, 0.0])
		_shake = 4.0
		for c in beds:
			if c:
				c.celebrate_hop(randf() * 0.08)
		await get_tree().create_timer(beat / 2.0).timeout


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
	_last_singer = who
	if season != Season.WINTER:
		_song_rings.append([0.0, Creature.PALETTE[who.species]])
	for c in beds:
		if c and c != who:
			c.notice(who.global_position)


func _set_weather(w: Weather) -> void:
	weather = w
	for c in beds:
		if c:
			c.raining = w == Weather.RAIN
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


## Leaving the app (home button, call, Siri) ends any recording or game cleanly
## and silences the garden until it comes back.
func _notification(what: int) -> void:
	if not OS.has_feature("mobile"):
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if state != State.DAY and state != State.NIGHT:
			_recover()
		elif Audio.recording:
			Audio.stop_recording()
		AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		AudioServer.set_bus_mute(0, false)
		_last_input = _t


## Back to the plain garden from any stuck mode.
func _recover() -> void:
	if Audio.recording:
		Audio.stop_recording()
	_rec_bed = -1
	_echo_listen = false
	_echo_waiting = false
	_can_held = false
	_can_pos = CAN_HOME
	_cam_target = Vector2(640, 360)
	_cam_zoom = 1.0
	_stage_light = 0.0
	_pad_active = false
	state = State.DAY


# ---------------------------------------------------------------- garden toys

## Windmill, pond, tree, stones, balloon and the hedgehog react to a tap.
func _tap_toy(p: Vector2) -> bool:
	if p.distance_to(MILL) < 42:
		_mill_boost = 1.0
		for k in 14:
			_confetti.append([MILL, Vector2.from_angle(randf() * TAU) * randf_range(60, 200), -k * 0.02, [Color("ffc1da"), Color("fff3a0"), Color.WHITE][k % 3], randf() * TAU, 6.0])
		Audio.play_music(_pluck, _shift() + 7.0, -6.0)
		return true
	var bp := _balloon_pos()
	if bp != Vector2.ZERO and p.distance_to(bp + Vector2(0, 8)) < 44:
		_balloon_seed(bp)
		return true
	var d := (p - POND) / Vector2(90, 28)
	if d.length() < 1.0 and season != Season.WINTER:
		var notes := [0.0, 2.0, 4.0, 7.0, 9.0, 12.0]
		var n: float = notes[clampi(int((p.x - POND.x + 90.0) / 30.0), 0, 5)]
		_song_rings.append([0.0, Color.from_hsv(n / 12.0, 0.6, 1.0)])
		Audio.play_music(_plop, _shift() + n, -2.0)
		return true
	if p.distance_to(TREE_CROWN) < 85 and state == State.DAY:
		_tree_shake = 1.0
		if season != Season.WINTER:
			for k in 2:
				_apples.append([TREE_CROWN + Vector2(randf_range(-50, 50), randf_range(-10, 30)), Vector2(randf_range(-30, 30), 0), 0.0])
		if is_instance_valid(_last_singer):
			Audio.play(_last_singer.stream, _last_singer.freq, _shift() - 12.0) # the tree hums the last song, low and soft
		return true
	for si in STONES.size():
		var st: Vector3 = STONES[si]
		if p.distance_to(Vector2(st.x, st.y)) < st.z + 14 and not _in_rest_zone(Vector2(st.x, st.y)):
			_worms[si] = 0.0
			for k in 3:
				get_tree().create_timer(0.15 + k * 0.13).timeout.connect(func(): Audio.play_music(_plop, _shift() + 12.0 + k * 2.0, -8.0))
			return true
	var hog := _hedgehog_pos()
	if hog != Vector2.ZERO and p.distance_to(hog) < 40:
		_hog_curl = 1.6
		Audio.play_music(_plop, _shift() + 9.0, -6.0)
		return true
	return false


func _tick_toys(delta: float) -> void:
	_mill_boost = maxf(0.0, _mill_boost - delta * 0.35)
	_mill_angle += delta * ((1.4 if weather == Weather.RAIN else 0.5) + _mill_boost * 7.0)
	_tree_shake = maxf(0.0, _tree_shake - delta * 2.0)
	_hog_curl = maxf(0.0, _hog_curl - delta)
	for ap in _apples:
		ap[2] += delta
		if ap[0].y < 468.0:
			ap[1].y += 900.0 * delta
			ap[0] += ap[1] * delta
		elif ap[1].y > 120.0:
			ap[1] = Vector2(ap[1].x * 0.5, -ap[1].y * 0.35) # bounce
			ap[0].y = 467.0
		else:
			ap[0].y = 470.0
	_apples = _apples.filter(func(ap): return ap[2] < 6.0)
	for k in _worms.keys():
		_worms[k] += delta
		if _worms[k] > 2.6:
			_worms.erase(k)
	# long press on a being: it shrinks and yawns (let go to stop), then becomes a seed again
	for i in beds.size():
		var b = beds[i]
		if b:
			var target := 0.0
			if _hold_t >= 0.0 and i == _hold_bed and state == State.DAY:
				target = clampf((_t - _hold_t - 0.4) / 1.4, 0.0, 1.0)
			b.shrink = move_toward(b.shrink, target, delta * 3.0)
			if target > 0.3:
				b.yawn_amt = maxf(b.yawn_amt, target)
	if _hold_t >= 0.0 and _hold_bed >= 0 and state == State.DAY and _t - _hold_t > 1.9:
		var i := _hold_bed
		_hold_t = -1.0
		_hold_bed = -1
		if beds[i]:
			_uproot(i)


func _uproot(i: int) -> void:
	var c = beds[i]
	_mini_burst(c.global_position + Vector2(0, -c.height() * 0.5))
	Audio.play_music(_pluck, _shift() - 5.0, -4.0)
	var tw = c.create_tween()
	tw.tween_property(c, "scale", Vector2(0.05, 0.05), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_remove_bed(i)
		_save())


## A seed floats down from the balloon on a little parachute and grows in an empty bed.
func _balloon_seed(from: Vector2) -> void:
	var free := -1
	for i in BED_POSITIONS.size():
		if beds[i] == null and i != _rec_bed:
			free = i
			break
	for k in 16:
		_confetti.append([from, Vector2.from_angle(randf() * TAU) * randf_range(60, 180), -k * 0.02, [Color("ffd45c"), Color("ff8fb8"), Color("4cc3b5")][k % 3], randf() * TAU, 7.0])
	Audio.play_music(_pluck, _shift() + 12.0, -4.0)
	if free < 0:
		return
	get_tree().create_timer(1.0).timeout.connect(func():
		if beds[free] == null and state == State.DAY:
			_grow_preset(free))


func _hedgehog_pos() -> Vector2:
	var cyc := fmod(_t + 40.0, 150.0)
	if cyc < 100.0 or cyc > 128.0 or state != State.DAY or weather == Weather.RAIN or season == Season.WINTER or _evening() > 0.5:
		return Vector2.ZERO
	var u := (cyc - 100.0) / 28.0
	return Vector2(lerpf(1340.0, -60.0, u), 704.0)


## A shy hedgehog visits now and then; tapped, it rolls into a ball and giggles.
func _draw_hedgehog(night: float) -> void:
	var p := _hedgehog_pos()
	if p == Vector2.ZERO:
		return
	if _hog_curl > 0.0:
		p.x += 0.0
	var spine := Color("8a6448").lerp(Color("2a2430"), night)
	var face := Color("e8c9a0").lerp(Color("2a2430"), night)
	var curl := clampf(_hog_curl, 0.0, 1.0)
	var bob := absf(sin(_t * 8.0)) * 2.0 * (1.0 - curl)
	var pts := PackedVector2Array()
	for i in 19:
		var a := PI + PI * i / 18.0
		var r := 26.0 + (5.0 if i % 2 == 0 else 0.0)
		pts.append(p + Vector2(cos(a) * r, sin(a) * r * lerpf(0.75, 1.0, curl) - bob))
	pts.append(p + Vector2(26, 0))
	_draw_ellipse(p + Vector2(0, 4), Vector2(30, 6), Color(0, 0, 0, 0.15))
	draw_colored_polygon(pts, spine)
	if curl < 0.5:
		_draw_ellipse(p + Vector2(-26, -8 - bob), Vector2(12, 9), face)
		draw_circle(p + Vector2(-37, -9 - bob), 3.0, Color("2b2340"))
		draw_circle(p + Vector2(-26, -12 - bob), 2.4, Color("2b2340"))
		for f in [-12.0, 10.0]:
			draw_circle(p + Vector2(f + sin(_t * 8.0 + f) * 3.0, 1), 4.0, face.darkened(0.2))
	else:
		draw_arc(p + Vector2(-6, -12), 5, 0.3, PI - 0.3, 6, Color("2b2340"), 2.0, true)
		draw_arc(p + Vector2(8, -12), 5, 0.3, PI - 0.3, 6, Color("2b2340"), 2.0, true)


## A little worm peeks out from under a stepping stone and giggles.
func _draw_worm(at: Vector2, age: float, night: float) -> void:
	var up := clampf(minf(age * 3.0, (2.6 - age) * 3.0), 0.0, 1.0)
	var col := Color("f2a0a8").lerp(Color("3b3050"), night * 0.6)
	var wig := sin(age * 14.0) * 4.0
	for k in 4:
		draw_circle(at + Vector2(k * 3.0 + wig * k * 0.3, -k * 8.0 * up), 6.0, col)
	var head := at + Vector2(9.0 + wig, -30.0 * up)
	draw_circle(head, 7.5, col)
	if up > 0.5:
		draw_circle(head + Vector2(-2.5, -1.5), 1.6, Color("2b2340"))
		draw_circle(head + Vector2(2.5, -1.5), 1.6, Color("2b2340"))
		draw_arc(head + Vector2(0, 1.5), 3.0, 0.2, PI - 0.2, 6, Color("2b2340"), 1.5, true)


## Two friends in the garden answer each other and share a little hug.
func _duet(c: Node2D) -> void:
	if not FRIENDS.has(c.species):
		return
	for f in beds:
		if f and f != c and f.species == FRIENDS[c.species]:
			var beat := 60.0 / _bpm()
			get_tree().create_timer(beat).timeout.connect(func():
				if is_instance_valid(f) and is_instance_valid(c):
					f.sing(_shift() + 4.0)
					f.love()
					c.love())
			return


## Bedtime: a painted picture of today's garden goes into the parents' postcard box.
func _save_postcard() -> void:
	if screenshot_mode or "--windowed" in OS.get_cmdline_args() and OS.get_cmdline_user_args().size() > 0:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(960, int(960.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute("user://postcards")
	img.save_jpg("user://postcards/%s.jpg" % Time.get_datetime_string_from_system().replace(":", "-"), 0.85)
	var files := Array(DirAccess.get_files_at("user://postcards"))
	files.sort()
	while files.size() > 60:
		DirAccess.remove_absolute("user://postcards/" + files.pop_front())


func _go_to_sleep() -> void:
	_save_postcard()
	if state == State.RECORDING:
		Audio.stop_recording()
		_rec_bed = -1
	state = State.NIGHT
	_can_held = false
	_can_pos = CAN_HOME
	weather = Weather.NONE
	var delay := 0.3
	for c in beds:
		if c:
			c.sleeping = true
			c.raining = false
			var pitch := randf_range(0.8, 1.4)
			get_tree().create_timer(delay).timeout.connect(func():
				Audio.play_ambient(_yawn, pitch, 6.0)
				if is_instance_valid(c):
					c.yawn())
			delay += 0.7


func _wake_up() -> void:
	state = State.DAY
	day_time = 0.0
	if not screenshot_mode:
		_auto_season = (_auto_season + 1) % 4
	_apply_season()
	_save()
	for c in beds:
		if c:
			c.sleeping = false
	_greet()


# ---------------------------------------------------------------- frame

func _process(delta: float) -> void:
	_t += delta
	if state != State.NIGHT:
		day_time += delta
		if day_time >= day_length() and state == State.DAY and _t - _last_input > 12.0 and not _can_held:
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
	_tick_water(delta)
	_tick_toys(delta)
	if _can_follow and _can_held and _pour <= 0.0:
		_can_pos = _can_pos.lerp(_can_goal, minf(1.0, delta * 16.0))
	_state_time = 0.0 if state != _last_state else _state_time + delta
	_last_state = state
	if _state_time > 75.0 and state in [State.CONCERT, State.ECHO, State.RECORDING]:
		_recover() # never leave a child stuck in a mode that stopped responding
	_beat_kick = maxf(0.0, _beat_kick - delta * 4.0)
	for i in _wet.size():
		_wet[i] = maxf(0.0, _wet[i] - delta * 0.4)
	for r in _song_rings:
		r[0] += delta
	_song_rings = _song_rings.filter(func(r): return r[0] < 2.2)
	_ev_smooth = move_toward(_ev_smooth, _evening_raw(), delta * 0.6)
	_season_fade = maxf(0.0, _season_fade - delta * 0.8)
	_tick_light()
	_help_all = maxf(0.0, _help_all - delta)
	for k in _help_one.keys():
		_help_one[k] -= delta
		if _help_one[k] <= 0.0:
			_help_one.erase(k)
	_pour = maxf(0.0, _pour - delta)
	for dr in _pour_drops:
		dr[2] += delta
		if dr[2] > 0.0:
			dr[0] += dr[1] * delta
			dr[1].y += 700.0 * delta
	_pour_drops = _pour_drops.filter(func(dr): return dr[2] < 0.7)
	_rain_amount = move_toward(_rain_amount, 1.0 if weather == Weather.RAIN else 0.0, delta * 0.5)
	_rainbow = maxf(0.0, _rainbow - delta / 12.0)
	var fall := 70.0 if season == Season.WINTER else 45.0
	for sp in _season_parts:
		sp[1] += delta * (1.2 if season != Season.WINTER else 0.6)
		sp[0] += Vector2(sin(sp[1]) * 30.0 - 12.0, fall) * delta
		if sp[0].y > 770:
			sp[0] = Vector2(randf() * 1400 - 60, -10)
	for fl in _flashes:
		fl[1] += delta
	_flashes = _flashes.filter(func(fl): return fl[1] < 0.2)
	_shake = move_toward(_shake, 0.0, delta * 20.0)
	_cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_cam.position = _cam.position.lerp(_cam_target, minf(1.0, delta * 2.2))
	var z := lerpf(_cam.zoom.x, _cam_zoom, minf(1.0, delta * 2.0))
	_cam.zoom = Vector2(z, z)
	for sp in _spots:
		sp[1] = maxf(0.0, sp[1] - delta * 0.9)
	_spots = _spots.filter(func(sp): return sp[1] > 0.0)
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
	for bf in _bed_fronts:
		bf.queue_redraw()


## Explanation bubbles for parents and older children: [key, target, side].
func _help_items() -> Array:
	var items := [
		["HELP_CONDUCTOR", BTN_CONDUCTOR, Vector2.RIGHT],
		["HELP_ECHO", BTN_ECHO, Vector2.RIGHT],
		["HELP_SUN", BTN_SUN, Vector2.DOWN],
		["HELP_RAIN", BTN_RAIN, Vector2.DOWN],
		["HELP_CAN", CAN_HOME + Vector2(0, -70), Vector2.UP],
	]
	if _help_one.has("MIC_ASK"):
		items.append(["MIC_ASK", BTN_PARENT + Vector2(-30, 0), Vector2.LEFT])
	if _help_one.has("HELP_MIC"):
		items.append(["HELP_MIC", BTN_PARENT + Vector2(-30, 0), Vector2.LEFT])
	for i in BED_POSITIONS.size():
		if beds[i] == null:
			items.append(["HELP_BED", BED_POSITIONS[i] + Vector2(0, -40), Vector2.UP])
			break
	return items


func _draw_help() -> void:
	if (_help_all <= 0.0 and _help_one.is_empty()) or hide_ui or state == State.NIGHT:
		return
	if _help_font == null:
		_help_font = ParentPanel.cjk_font()
	var items := _help_items()
	var shown := []
	if _help_all > 0.0:
		# tour: one bubble after another, so nothing is covered for long
		var elapsed := HELP_STEP * items.size() - _help_all
		var idx := clampi(int(elapsed / HELP_STEP), 0, items.size() - 1)
		var phase := fmod(elapsed, HELP_STEP)
		shown.append([items[idx], minf(phase * 3.0, (HELP_STEP - phase) * 3.0), phase])
	else:
		for it in items:
			if _help_one.has(it[0]):
				shown.append([it, minf(float(_help_one[it[0]]) * 2.0, 1.0), 4.0 - float(_help_one[it[0]])])
	for sh in shown:
		_draw_help_bubble(sh[0], clampf(sh[1], 0.0, 1.0), sh[2])


func _draw_help_bubble(it: Array, a: float, phase: float) -> void:
	var ink := Color("2f2a4a")
	var paper := Color(1, 0.98, 0.93, a)
	var key: String = it[0]
	var text := tr(key)
	var fs := 16
	var size := _help_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, 230, fs)
	var icon_h := 58.0
	var box := Vector2(maxf(size.x, 150.0) + 28, size.y + icon_h + 24)
	var target: Vector2 = it[1]
	var side: Vector2 = it[2]
	var gap := BTN_R + 22.0
	var pos: Vector2
	if side == Vector2.RIGHT:
		pos = target + Vector2(gap, -box.y * 0.5)
	elif side == Vector2.DOWN:
		pos = target + Vector2(-box.x * 0.5, gap)
	else:
		pos = target + Vector2(-box.x * 0.5, -box.y - 40)
	pos.x = clampf(pos.x, 10, 1200 - box.x)
	pos.y = clampf(pos.y, 10, 700 - box.y)
	pos.y += sin(_t * 2.0) * 2.0
	var r := Rect2(pos, box)
	var tip := target + side * (BTN_R + 4.0) if side != Vector2.UP else target
	var base := r.get_center().clamp(r.position + Vector2(24, 18), r.end - Vector2(24, 18))
	var n := (tip - base).normalized().orthogonal() * 12.0
	_overlay.draw_colored_polygon(PackedVector2Array([base + n, tip, base - n]), Color(ink, a))
	_overlay.draw_style_box(_help_box(Color(ink, a)), r.grow(3))
	_overlay.draw_colored_polygon(PackedVector2Array([base + n * 0.7, tip.lerp(base, 0.12), base - n * 0.7]), paper)
	_overlay.draw_style_box(_help_box(paper), r)
	_draw_help_icon(key, Vector2(r.get_center().x, pos.y + 12 + icon_h * 0.5), a)
	_overlay.draw_multiline_string(_help_font, pos + Vector2(14, icon_h + 14 + _help_font.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_CENTER, box.x - 28, fs, -1, Color(ink, 0.75 * a))
	_draw_tap_hand(target, phase, a)


## A pointing hand that taps the target twice per bubble.
func _draw_tap_hand(target: Vector2, phase: float, a: float) -> void:
	var tap := absf(sin(phase * PI * 1.1))
	var p := target + Vector2(26, 34) + Vector2(10, 14) * tap
	var skin := Color("ffd9b8")
	var ink := Color("2f2a4a")
	if tap < 0.15:
		_overlay.draw_arc(target, 20 + (0.15 - tap) * 120, 0, TAU, 24, Color(1, 1, 1, 0.8 * a), 4.0, true)
	_overlay.draw_set_transform(p, -0.5, Vector2.ONE)
	_overlay.draw_rect(Rect2(Vector2(-6, -40), Vector2(12, 30)), Color(ink, a))
	_overlay.draw_circle(Vector2(0, -40), 6, Color(ink, a))
	_overlay.draw_circle(Vector2(0, 0), 20, Color(ink, a))
	_overlay.draw_rect(Rect2(Vector2(-4, -40), Vector2(8, 30)), Color(skin, a))
	_overlay.draw_circle(Vector2(0, -40), 4, Color(skin, a))
	_overlay.draw_circle(Vector2(0, 0), 18, Color(skin, a))
	for k in 3:
		_overlay.draw_arc(Vector2(-10 + k * 9, -14), 5, PI, TAU, 8, Color(ink, 0.6 * a), 2.0)
	_overlay.draw_set_transform(Vector2.ZERO)


## Picture first: what the button does, readable without text.
func _draw_help_icon(key: String, c: Vector2, a: float) -> void:
	match key:
		"HELP_CONDUCTOR":
			for k in 3:
				_overlay.draw_circle(c + Vector2(-30 + k * 30, 12), 11, Color([Color("9b6bd6"), Color("ffc93c"), Color("7cc86a")][k], a))
				_help_note(c + Vector2(-26 + k * 30, -12 - (k % 2) * 6), a)
		"HELP_ECHO":
			_overlay.draw_circle(c + Vector2(-30, 6), 13, Color(Color("4cc3b5"), a))
			_help_note(c + Vector2(-26, -18), a)
			_help_arrow(c + Vector2(-8, 4), c + Vector2(12, 4), a)
			_help_face(c + Vector2(34, 6), a)
			_help_note(c + Vector2(40, -18), a)
		"HELP_SUN":
			for k in 8:
				var d := Vector2.from_angle(k * TAU / 8.0 + _t * 0.5)
				_overlay.draw_line(c + d * 18, c + d * 26, Color(Color("ffb02e"), a), 4.0)
			_overlay.draw_circle(c, 15, Color(Color("ffd84d"), a))
		"HELP_RAIN":
			_overlay.draw_circle(c + Vector2(-10, -10), 12, Color(Color("9fb3cc"), a))
			_overlay.draw_circle(c + Vector2(8, -12), 15, Color(Color("9fb3cc"), a))
			for k in 3:
				_help_drop(c + Vector2(-14 + k * 14, 14 + fmod(_t * 30.0 + k * 7, 10.0)), a)
		"HELP_CAN":
			_help_drop(c + Vector2(-34, 4), a)
			_help_arrow(c + Vector2(-20, 4), c + Vector2(-2, 4), a)
			_overlay.draw_line(c + Vector2(18, 20), c + Vector2(18, 0), Color(Color("4f8f3a"), a), 4.0)
			_overlay.draw_circle(c + Vector2(18, -6), 10 + 3 * sin(_t * 3.0), Color(Color("ff8fb8"), a))
			_help_arrow(c + Vector2(40, 18), c + Vector2(40, -16), a)
		_:
			# empty bed: sing into it (mouth with notes), a sprout appears
			_help_face(c + Vector2(-26, 4), a, true)
			_help_note(c + Vector2(0, -12), a)
			_overlay.draw_line(c + Vector2(32, 20), c + Vector2(32, 0), Color(Color("4f8f3a"), a), 4.0)
			_overlay.draw_colored_polygon(_front_ellipse(c + Vector2(42, -2), Vector2(10, 5), -0.4), Color(Color("7cc86a"), a))


func _help_note(c: Vector2, a: float) -> void:
	var ink := Color(Color("2f2a4a"), a)
	_overlay.draw_circle(c, 5, ink)
	_overlay.draw_line(c + Vector2(4, 0), c + Vector2(4, -16), ink, 2.5)
	_overlay.draw_line(c + Vector2(4, -16), c + Vector2(11, -12), ink, 2.5)


func _help_drop(c: Vector2, a: float) -> void:
	var col := Color(Color("3d8fe0"), a)
	_overlay.draw_circle(c, 7, col)
	_overlay.draw_colored_polygon(PackedVector2Array([c + Vector2(-6.4, -3), c + Vector2(0, -15), c + Vector2(6.4, -3)]), col)


func _help_arrow(from: Vector2, to: Vector2, a: float) -> void:
	var ink := Color(Color("2f2a4a"), a)
	var d := (to - from).normalized()
	_overlay.draw_line(from, to, ink, 3.5)
	_overlay.draw_line(to, to - d.rotated(0.6) * 9, ink, 3.5)
	_overlay.draw_line(to, to - d.rotated(-0.6) * 9, ink, 3.5)


func _help_face(c: Vector2, a: float, singing := false) -> void:
	var ink := Color(Color("2f2a4a"), a)
	_overlay.draw_circle(c, 15, Color(Color("ffd9b8"), a))
	_overlay.draw_circle(c + Vector2(-5, -3), 2, ink)
	_overlay.draw_circle(c + Vector2(5, -3), 2, ink)
	if singing:
		_overlay.draw_circle(c + Vector2(0, 6), 4, ink)
	else:
		_overlay.draw_arc(c + Vector2(0, 2), 6, 0.4, PI - 0.4, 8, ink, 2.0)


func _help_box(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(16)
	return sb


## The can glows softly while somebody in the garden is thirsty.
func _can_hint() -> float:
	if state != State.DAY:
		return 0.0
	for c in beds:
		if c and c.thirst > 0.55:
			return 0.6 + 0.4 * sin(_t * 3.0)
	return 0.0


## Beings get thirsty over about one garden day; rain waters everyone.
func _tick_water(delta: float) -> void:
	if state == State.NIGHT or screenshot_mode:
		return
	var change := -delta / (day_length() * 0.9)
	if weather == Weather.RAIN:
		change = delta * 0.25
	for i in beds.size():
		var c = beds[i]
		if not c:
			continue
		var d: Dictionary = bed_data[i]
		var w := clampf(float(d.get("water", 1.0)) + change, 0.0, 1.0)
		d["water"] = w
		c.thirst = 1.0 - w
	_water_save += delta
	if _water_save > 20.0:
		_water_save = 0.0
		_save()


func _tick_ambience(delta: float) -> void:
	Audio.set_rain(weather == Weather.RAIN and state != State.RECORDING and not _echo_listen)
	if state == State.RECORDING or _echo_listen:
		return
	_amb_timer -= delta
	if _amb_timer > 0.0:
		return
	if state == State.NIGHT:
		Audio.play_ambient(_cricket, randf_range(0.9, 1.1), randf_range(-6.0, 0.0))
		_amb_timer = randf_range(1.2, 3.0)
	elif weather != Weather.RAIN and _evening() < 0.6 and season != Season.WINTER:
		Audio.play_ambient(_bird, randf_range(0.8, 1.3), randf_range(-8.0, -2.0))
		_amb_timer = randf_range(4.0, 10.0)
	else:
		_amb_timer = 2.0


## Gentle accompaniment: bass on 1 and 3, music-box notes on the off-beats.
## Quiet while recording so the child can hear itself; silent at night.
func _tick_music(delta: float) -> void:
	if state == State.NIGHT or state == State.RECORDING or _echo_listen or _creature_count() == 0:
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
	if half % 2 == 0:
		_beat_kick = 1.0
		for c in beds:
			if c:
				c.pulse()
	if half % 4 == 0:
		Audio.play_music(_bass, root, linear_to_db(0.9 * fade + 0.01))
	elif half % 2 == 1 and randf() < 0.55:
		var steps := [0.0, 2.0, 4.0, 7.0, 9.0, 12.0]
		Audio.play_music(_pluck, steps[randi() % steps.size()] + _shift() - 12.0, linear_to_db(0.5 * fade + 0.01))


## Smoothed evening amount 0 day .. 1 night (waking up fades, never jumps).
func _evening() -> float:
	return _ev_smooth


func _evening_raw() -> float:
	if state == State.NIGHT:
		return 1.0
	return clampf((day_time - day_length() * 0.8) / (day_length() * 0.2), 0.0, 1.0)


func _draw() -> void:
	var ev := _evening()
	var night := clampf(ev * 2.0 - 1.0, 0.0, 1.0)
	var dusk := clampf(ev * 2.0, 0.0, 1.0)
	var vivid := clampf(1.0 - _rain_mood(), 0.0, 1.0) # rain greys the world, the rainbow brings colour back
	var top := Color("5cb6f0").lerp(Color("7b6fc4"), dusk).lerp(Color("1e2246"), night)
	var bottom := Color("e8f4f8").lerp(Color("ffb36b"), dusk).lerp(Color("3b3f7a"), night)
	if season == Season.WINTER:
		top = top.lerp(Color("b9c8d8"), 0.75 * (1.0 - dusk))
		bottom = bottom.lerp(Color("dfe6ee"), 0.8 * (1.0 - dusk))
	elif season == Season.AUTUMN:
		bottom = bottom.lerp(Color("f6dcb4"), 0.35 * (1.0 - dusk))
	top = top.lerp(Color("6f7c8c"), 0.35 * (1.0 - vivid))
	bottom = bottom.lerp(Color("b4bec9"), 0.3 * (1.0 - vivid))
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
		var sun_c := Vector2(560, lerpf(70.0, 330.0, ev))
		var sun_col := Color("ffe27a").lerp(Color("ff8a4a"), ev)
		sun_col.a = lerpf(0.1, 0.75, vivid) # pale: the sun *button* is the one to tap; rain hides it
		if season == Season.WINTER:
			sun_col = Color(sun_col.lerp(Color.WHITE, 0.55), sun_col.a * 0.8)
		for k in 3:
			draw_circle(sun_c, 48 + k * 22 + sin(_t * 1.5) * 3, Color(sun_col, 0.10 * sun_col.a))
		draw_circle(sun_c, 32, sun_col)
		draw_circle(sun_c + Vector2(-11, -11), 15, Color(1, 1, 1, 0.3 * sun_col.a))

	# Rainbow after a rainy concert
	if _rainbow * (1.0 - dusk) > 0.0:
		var rb := [Color("ff6b6b"), Color("ffa94d"), Color("ffd84d"), Color("7cc86a"), Color("4cc3b5"), Color("6fa8e8"), Color("9b6bd6")]
		for k in rb.size():
			draw_arc(Vector2(640, 470), 470 - k * 16, PI, TAU, 96, Color(rb[k], 0.55 * _rainbow * (1.0 - dusk)), 16.0, true)

	# Drifting clouds
	var cloud_col := Color(1, 1, 1, 0.92).lerp(Color("c9a0b8"), dusk * 0.5).lerp(Color("39406e"), night)
	cloud_col = cloud_col.lerp(Color("8e98a6"), 1.0 - vivid)
	if season == Season.WINTER:
		cloud_col = cloud_col.lerp(Color("e4e8ef"), 0.6 * (1.0 - night)) # heavy snow clouds
	# far layer: small, pale, slow (parallax)
	var far_cloud := Color(cloud_col.lerp(top, 0.45), cloud_col.a * 0.5)
	for i in 4:
		var x := fmod(i * 410.0 + 120.0 + _t * 3.5, 1800.0) - 300.0
		_draw_cloud(Vector2(x, 150 + fmod(i * 37.0, 60.0)), 0.42 + fmod(i * 0.21, 0.2), far_cloud, i + 7)
	_draw_balloon(night, vivid)
	_draw_birds(night)
	# rain: a heavy grey blanket closes over the sky
	if _rain_amount > 0.0:
		var heavy := Color(Color("7d8796").lerp(Color("2b3150"), night), 0.85 * _rain_amount)
		for i in 7:
			var x := fmod(i * 220.0 + _t * 4.0, 1700.0) - 200.0
			_draw_cloud(Vector2(x, 40 + (i % 2) * 40), 1.4, heavy, i + 20)
	for i in 5:
		var speed := 8.0 + i * 3.0
		var x := fmod(i * 330.0 + _t * speed, 1700.0) - 250.0
		_draw_cloud(Vector2(x, 60 + fmod(i * 61.0, 150.0)), 0.7 + fmod(i * 0.37, 0.6), cloud_col, i)

	# Hills with aerial perspective: the far one is pale and bluish
	var haze := Color("a6c8e0")
	var sc: Array = SEASONS[season]
	var far: Color = sc[3].lerp(haze, 0.3).lerp(Color("c7a487"), dusk * 0.4).lerp(Color("2a3558"), night)
	var mid: Color = sc[1].lerp(haze, 0.15).lerp(Color("b08a62"), dusk * 0.3).lerp(Color("1d3a3c"), night)
	var mid2: Color = sc[2].lerp(Color("a07a52"), dusk * 0.3).lerp(Color("1a3634"), night)
	var near: Color = sc[0].lerp(Color("8a7a4a"), dusk * 0.3).lerp(Color("183232"), night)
	far = far.lerp(far.darkened(0.2), 1.0 - vivid)
	mid = mid.lerp(mid.darkened(0.2), 1.0 - vivid)
	near = near.lerp(near.darkened(0.15), 1.0 - vivid)
	_draw_hill(325, 110, 0.004, 1.0, far)
	_draw_windmill(Vector2(600, 277), far, night)
	_draw_tree(Vector2(1070, 350), 0.72, night, vivid) # a little tree far away
	_draw_hill(355, 70, 0.006, 2.3, mid)
	_draw_hill(386, 30, 0.009, 4.1, mid2)
	_gradient_rect(Rect2(-2000, 385, 5280, 2400), near.lightened(0.06), Color("5fa14a").lerp(near, 0.4 + night * 0.6).darkened(0.08))
	draw_rect(Rect2(-2000, 2785, 5280, 2000), near.darkened(0.12))

	# Mid-ground: big tree on the left, fence on the right
	_draw_tree(Vector2(232 + sin(_t * 40.0) * 5.0 * _tree_shake, 440), 1.1, night, vivid)
	for ap in _apples:
		_draw_ellipse(ap[0], Vector2(8, 7.5), Color("d9473f").lerp(Color("3b2a40"), night * 0.6))
		draw_line(ap[0] + Vector2(0, -6), ap[0] + Vector2(2, -11), Color("6b4a2e"), 2.0)
	_draw_fence(Vector2(690, 418), night)

	# Winding path from the front into the garden
	var path_col: Color = sc[6].lerp(Color("4a4560"), night * 0.8).lerp(Color("bfae8c"), 1.0 - vivid)
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
	var tuft := near.darkened(0.22) if season != Season.WINTER else Color("b9c8d8").lerp(Color("2a3558"), night)
	for i in 34:
		var gp := Vector2(fmod(i * 157.0, 1320.0) - 20, 400 + fmod(i * 89.0, 320.0))
		if _in_rest_zone(gp):
			continue
		var sway := sin(_t * 1.3 + i) * 3.0 + _beat_kick * 2.0
		for k in 3:
			draw_line(gp + Vector2((k - 1) * 4, 0), gp + Vector2((k - 1) * 7 + sway, -12 - k * 3), tuft, 2.5)
		if i % 6 == 0 and season != Season.WINTER:
			var fc: Color = [Color("ffffff"), Color("ffc93c"), Color("ff8fb8")][i % 3]
			draw_circle(gp + Vector2(sway, -16), 4.0, fc.lerp(tuft, night * 0.7))

	for i in int(sc[7]):
		var fp := Vector2(fmod(i * 233.0 + 40.0, 1300.0) - 10, 405 + fmod(i * 131.0, 300.0))
		if _in_rest_zone(fp):
			continue
		var fc: Color = [Color("ff8fb1"), Color("ffe066"), Color("ffffff")][i % 3]
		var r := 3.0 + fmod(i, 3.0)
		for q in 4:
			draw_circle(fp + Vector2.from_angle(q * PI / 2) * r, r * 0.8, fc.lerp(tuft, night * 0.7))
		draw_circle(fp, r * 0.6, Color("ffc93c").lerp(tuft, night * 0.7))

	# Cloud shadows drifting over the meadow
	if weather != Weather.RAIN and night < 0.5:
		for i in 3:
			var x := fmod(i * 520.0 + _t * (10.0 + i * 3.0), 1900.0) - 300.0
			draw_colored_polygon(_ellipse_pts(Vector2(x, 470 + i * 90), Vector2(170, 34)), Color(0.1, 0.2, 0.15, 0.07 * (1.0 - dusk)))

	if _rain_amount > 0.0:
		for pd in [Vector3(560, 640, 46), Vector3(760, 560, 34), Vector3(420, 470, 28)]:
			_draw_ellipse(Vector2(pd.x, pd.y), Vector2(pd.z, pd.z * 0.28) * _rain_amount, Color(Color("8fb8d8").lerp(top, 0.4), 0.55))
	_draw_pond(Vector2(1195, 452), top, night)
	_draw_dragonfly(Vector2(1190, 415), night)
	_draw_ladybug(Vector2(690, 418), night)
	for fc in [Vector3(700, 432, 0), Vector3(905, 426, 1), Vector3(452, 418, 2), Vector3(30, 470, 4)]:
		_draw_flower_cluster(Vector2(fc.x, fc.y), int(fc.z), night)

	# Stones and the watering can
	for si in STONES.size():
		var st: Vector3 = STONES[si]
		if _in_rest_zone(Vector2(st.x, st.y)):
			continue
		if _worms.has(si):
			_draw_worm(Vector2(st.x + st.z * 0.6, st.y), float(_worms[si]), night)
		var stone := Color("c9c2b8").lerp(Color("3b3d55"), night * 0.8)
		_draw_ellipse(Vector2(st.x, st.y), Vector2(st.z + 3, st.z * 0.6 + 3), stone.darkened(0.45))
		_draw_ellipse(Vector2(st.x, st.y), Vector2(st.z, st.z * 0.6), stone)
		draw_arc(Vector2(st.x, st.y), st.z, PI + 0.3, TAU - 0.3, 10, Color(1, 1, 1, 0.35 * (1.0 - night)), 2.0)
	# the can's home: a round stepping-stone slab, always in the same place
	var slab := Color("e9dfcf").lerp(Color("3b3d55"), night * 0.8)
	_draw_ellipse(CAN_HOME + Vector2(0, 6), Vector2(74, 22), slab.darkened(0.35))
	_draw_ellipse(CAN_HOME + Vector2(0, 2), Vector2(70, 19), slab)
	draw_arc(CAN_HOME + Vector2(0, 2), 62, PI + 0.5, TAU - 0.5, 12, Color(1, 1, 1, 0.4 * (1.0 - night)), 3.0)


	# Beds: organic, different sizes, three depths
	for i in BED_POSITIONS.size():
		if hide_ui and beds[i] == null:
			continue
		var b: Vector2 = BED_POSITIONS[i]
		var k: float = BED_SCALE[i]
		var soil := Color("7a4a2e").lerp(Color("2a2430"), ev * 0.6)
		if season == Season.WINTER:
			soil = Color("8a6a55").lerp(Color("2a2430"), ev * 0.6)
		_draw_ellipse(b + Vector2(0, 14 * k), Vector2(118, 34) * k, Color("9fb3cc", 0.35) if season == Season.WINTER else Color(0, 0, 0, 0.12))
		_draw_ellipse(b + Vector2(0, 8 * k), Vector2(112, 32) * k, soil.darkened(0.3))
		_draw_ellipse(b + Vector2(0, 4 * k), Vector2(102, 25) * k, soil)
		for j in 6:
			draw_circle(b + Vector2((-70 + j * 28) * k, (4 + (j % 2) * 7) * k), 3.5 * k, soil.lightened(0.15))
		if _wet[i] > 0.0:
			_draw_ellipse(b + Vector2(0, 4 * k), Vector2(102, 25) * k, Color(0.15, 0.07, 0.05, 0.35 * _wet[i]))
			draw_arc(b + Vector2(-30, -2) * k, 22 * k, PI + 0.3, TAU - 0.3, 10, Color(1, 1, 1, 0.35 * _wet[i]), 2.0)
		# dry, cracked soil when the being is thirsty
		if beds[i] and beds[i].thirst > 0.5:
			var dry := clampf((beds[i].thirst - 0.5) * 2.5, 0.0, 1.0)
			_draw_ellipse(b + Vector2(0, 4 * k), Vector2(102, 25) * k, Color(Color("c8a27a"), 0.45 * dry))
			for j in 5:
				var x0 := (-80 + j * 38) * k
				var crack := PackedVector2Array()
				for q in 4:
					crack.append(b + Vector2(x0 + q * 9 * k, (-6 + (q % 2) * 9 + (j % 2) * 5) * k))
				draw_polyline(crack, Color(soil.darkened(0.5), dry), 2.2, true)
		# little pebble rim
		for j in 9:
			var a := PI * 0.1 + PI * 0.8 * j / 8.0
			_draw_ellipse(b + Vector2(cos(a) * 110, sin(a) * 32 + 8) * k, Vector2(9, 6) * k, Color("bdb2a3").lerp(Color("3b3d55"), night * 0.8))
		if beds[i] == null and state != State.NIGHT:
			var glow := 0.5 + 0.5 * sin(_t * 3.0 + i)
			for g in 3:
				draw_circle(b + Vector2(0, -8 * k), (22 + g * 11 + glow * 6) * k, Color(1, 0.95, 0.6, (0.24 - g * 0.06) * (0.6 + glow * 0.4)))
			var ring := fmod(_t * 0.8 + i * 0.3, 1.0)
			draw_arc(b + Vector2(0, -8 * k), (30 + ring * 50) * k, 0, TAU, 40, Color(1, 1, 1, (0.6 - ring * 0.6) * 0.9), 4.0 * k, true)
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
	elif weather != Weather.RAIN and season != Season.WINTER:
		for i in 3:
			var bp := Vector2(fmod(_t * 40.0 + i * 450.0, 1500.0) - 100, 250 + sin(_t * 0.9 + i * 2.0) * 80 + i * 40)
			var flap := absf(sin(_t * 12.0 + i))
			var bc: Color = [Color("ff8fb8"), Color("ffc93c"), Color("6fa8e8")][i]
			_draw_ellipse(bp + Vector2(-8 * flap, 0), Vector2(9 * flap + 1, 11), bc)
			_draw_ellipse(bp + Vector2(8 * flap, 0), Vector2(9 * flap + 1, 11), bc)
			draw_line(bp + Vector2(0, -7), bp + Vector2(0, 7), Color("3a2f40"), 2.5)

	_draw_hedgehog(night)
	var warm := dusk * (1.0 - night)
	if warm > 0.0:
		_gradient_rect(Rect2(-2000, 0, 5280, 800), Color(1.0, 0.55, 0.25, 0.14 * warm), Color(1.0, 0.45, 0.3, 0.04 * warm))
	if ev > 0.0:
		draw_rect(Rect2(-2000, -2000, 5280, 4720), Color(0.05, 0.05, 0.2, ev * 0.22))
	# pollen motes floating in the sunlight
	if state != State.NIGHT and weather != Weather.RAIN and season == Season.SUMMER and _confetti.is_empty():
		for i in 24:
			var mp := Vector2(fmod(i * 173.0 + _t * (6.0 + i % 4), 1320.0) - 20, 200 + fmod(i * 97.0, 420.0) + sin(_t * 0.7 + i) * 18.0)
			var tw := 0.5 + 0.5 * sin(_t * 2.0 + i * 1.3)
			draw_circle(mp, 2.2, Color(1, 0.97, 0.75, 0.55 * tw * (1.0 - dusk)))


## Foreground layer above the beings: framing leaves, rain, buttons.
func _draw_front() -> void:
	var ev := _evening()
	var night := clampf(ev * 2.0 - 1.0, 0.0, 1.0)
	var leaf := Color("3e7d3a").lerp(Color("10241f"), night)
	var leaf2 := Color("4f9442").lerp(Color("15302a"), night)
	# corner foliage frames the scene like a picture book
	var sw := sin(_t * 0.9) * 0.04
	var dy := get_viewport_rect().size.y - 720.0 # keep framing on the real bottom edge (16:10 Steam Deck)
	for l in [Vector4(-30, 760, -1.2, 150), Vector4(20, 770, -0.8, 120), Vector4(-40, 700, -1.5, 110),
			Vector4(1310, 760, -1.95, 150), Vector4(1260, 775, -2.35, 120), Vector4(1320, 690, -1.65, 105)]:
		_front_leaf(Vector2(l.x, l.y + dy), l.z + sw, l.w, leaf if int(l.w) % 2 == 0 else leaf2)
	for i in 18:
		var x := -20.0 + i * 78.0
		var h := 26.0 + fmod(i * 37.0, 22.0)
		var s := sin(_t * 1.2 + i) * 4.0
		_front.draw_colored_polygon(PackedVector2Array([Vector2(x - 12, 740 + dy), Vector2(x + s, 740 + dy - h), Vector2(x + 12, 740 + dy)]), leaf2)

	for sp in _season_parts:
		var p: Vector2 = sp[0]
		var ph: float = sp[1]
		match season:
			Season.SPRING:
				_front.draw_colored_polygon(_front_ellipse(p, Vector2(6, 3.5), ph), Color("ffc1da").lerp(Color("3b3f7a"), night * 0.6))
			Season.AUTUMN:
				_front_leaf(p, ph * 0.7, 20.0, [Color("e08a3c"), Color("c9674e"), Color("e0a83e")][int(sp[0].x) % 3].lerp(Color("3b3f7a"), night * 0.6))
			Season.WINTER:
				_front.draw_circle(p, 3.0 + fmod(ph * 7.0, 2.5), Color(1, 1, 1, 0.9))
	if _rain_amount > 0.0:
		for r in _rain:
			_front.draw_line(r, r + Vector2(-7, 22), Color(0.85, 0.9, 1.0, 0.7 * _rain_amount), 3.0, true)
		for i in 10:
			var sp := Vector2(fmod(i * 137.0, 1280.0), 420 + fmod(i * 61.0, 280.0))
			var ph := fmod(_t * 1.7 + i * 0.31, 1.0)
			_front.draw_arc(sp, 3 + ph * 9, PI, TAU, 8, Color(1, 1, 1, 0.6 * (1.0 - ph) * _rain_amount), 2.0, true)

	if not _can_held:
		var nt := clampf(_evening() * 2.0 - 1.0, 0.0, 1.0)
		_draw_can(_front, CAN_HOME, nt, 0.0, _can_hint())
	if hide_ui or state == State.CONCERT:
		return # during the concert the stage belongs to the singers
	# Buttons: thick icons on coloured discs
	var can_concert := _creature_count() >= 3 and state == State.DAY
	_draw_button(BTN_CONDUCTOR, Color("ff8a7a"), can_concert, state == State.CONCERT)
	_draw_baton(BTN_CONDUCTOR)
	var sun_active := weather == Weather.SUN or state == State.NIGHT
	_draw_button(BTN_SUN, Color("ffd45c"), state != State.CONCERT, sun_active)
	_draw_sun_icon(BTN_SUN)
	_draw_button(BTN_RAIN, Color("7fb6f0"), state == State.DAY, weather == Weather.RAIN)
	_draw_cloud_icon(BTN_RAIN)
	_draw_button(BTN_ECHO, Color("b58cf0"), (_creature_count() >= 2 and state == State.DAY) or state == State.ECHO, state == State.ECHO)
	_draw_ear_icon(BTN_ECHO)
	if _pad_active and _panel == null:
		var fp: Vector2 = _focus_targets()[_focus]
		var pulse := 1.0 + 0.03 * (1.0 + sin(_t * TAU / 1.2))
		if _focus < 4:
			var r := (BTN_R + 14.0) * pulse
			_front.draw_arc(fp, r, 0, TAU, 48, Color("2f2a4a"), 12.0, true)
			_front.draw_arc(fp, r, 0, TAU, 48, Color("ffd23f"), 8.0, true)
		elif _focus - 4 >= BED_POSITIONS.size():
			_sticker_ring(CAN_HOME + Vector2(0, -32), Vector2(84, 66) * pulse)
		else:
			# soft sticker ring around the whole being (never across its face)
			var i := _focus - 4
			var c = beds[i]
			var h: float = c.height() if c else 60.0
			var w: float = (c.radius() + 34.0) if c else 120.0 * BED_SCALE[i]
			_sticker_ring(BED_POSITIONS[i] + Vector2(0, -h * 0.5 + 6), Vector2(w, h * 0.5 + 40) * pulse)
	# parent button: small but clearly visible padlock
	if state == State.CONCERT:
		return # the stage belongs to the singers (and the zoom would cut these)
	_small_stone(BTN_PARENT, Color("fbf6ee"))
	_front.draw_arc(BTN_PARENT + Vector2(0, -4), 8, PI, TAU, 12, Color("2f2a4a"), 4.0, true)
	_front.draw_rect(Rect2(BTN_PARENT + Vector2(-11, -4), Vector2(22, 16)), Color("2f2a4a"))
	_front.draw_circle(BTN_PARENT + Vector2(0, 3), 3, Color("fbf6ee"))
	# help: a friendly question mark below the lock
	var hp := BTN_HELP + Vector2(0, -absf(sin(_t * 2.0)) * 2.0 if _help_all <= 0.0 else 0.0)
	_small_stone(hp, Color("fff3a0") if _help_all > 0.0 else Color("fbf6ee"))
	_front.draw_arc(hp + Vector2(0, -6), 8, PI * 0.95, PI * 2.45, 14, Color("2f2a4a"), 4.5, true)
	_front.draw_line(hp + Vector2(0, 1), hp + Vector2(0, 6), Color("2f2a4a"), 4.5)
	_front.draw_circle(hp + Vector2(0, 13), 3, Color("2f2a4a"))


## Front lip of one bed, drawn right after its being (same z) so the being
## stands *in* the soil but nothing ever covers a being standing further front.
func _draw_bed_front(node: Node2D, i: int) -> void:
	if beds[i] == null:
		return
	var ev := _evening()
	var night := clampf(ev * 2.0 - 1.0, 0.0, 1.0)
	var b := Vector2.ZERO
	var k: float = BED_SCALE[i]
	var soil := Color("7a4a2e").lerp(Color("2a2430"), ev * 0.6)
	var lip := PackedVector2Array()
	for j in 17:
		var a := PI * j / 16.0
		lip.append(b + Vector2(cos(a) * 102, 4 + sin(a) * 25) * k)
	for j in range(15, 0, -1):
		var a := PI * j / 16.0
		lip.append(b + Vector2(cos(a) * 70, 8 + sin(a) * 6) * k)
	node.draw_colored_polygon(lip, soil)
	for j in 7:
		var a := PI * 0.15 + PI * 0.7 * j / 6.0
		var pp := b + Vector2(cos(a) * 110, sin(a) * 32 + 8) * k
		node.draw_colored_polygon(_front_ellipse(pp, Vector2(9, 6) * k, 0.0), Color("a99c8c").lerp(Color("3b3d55"), night * 0.8))
		node.draw_colored_polygon(_front_ellipse(pp + Vector2(-1, -1) * k, Vector2(7, 4.5) * k, 0.0), Color("cfc5b6").lerp(Color("3b3d55"), night * 0.8))
	var tuft := Color("5fa14a").lerp(Color("15302a"), night) if season != Season.WINTER else Color("b9c8d8")
	for j in [0, 2]:
		var g := b + Vector2((-70 + j * 70) * k, 24 * k)
		var gsw := sin(_t * 1.4 + j + i) * 2.0
		for q in 3:
			node.draw_line(g + Vector2((q - 1) * 4, 0), g + Vector2((q - 1) * 6 + gsw, -12 - q * 3), tuft, 3.0, true)


func _sticker_ring(c: Vector2, r: Vector2) -> void:
	var ring := _ellipse_pts(c, r, 48)
	ring.append(ring[0])
	_front.draw_polyline(ring, Color(1, 1, 1, 0.9), 14.0, true)
	_front.draw_polyline(ring, Color("ffd23f"), 7.0, true)
	var glow := _ellipse_pts(c, r + Vector2(10, 10), 48)
	glow.append(glow[0])
	_front.draw_polyline(glow, Color(1, 0.9, 0.4, 0.25 + 0.15 * sin(_t * 4.0)), 8.0, true)


func _rounded_frame(r: Rect2, rad: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(r.size.x - rad, rad), r.position + Vector2(r.size.x - rad, r.size.y - rad),
		r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for ci in 4:
		for j in 7:
			var a := -PI / 2 + (ci + j / 6.0) * PI / 2
			pts.append(corners[ci] + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	_front.draw_polyline(pts, col, width, true)


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


func _front_ellipse(c: Vector2, r: Vector2, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


## Calm space around every bed and the can's slab: no decoration there,
## so beings and empty beds read clearly.
func _in_rest_zone(p: Vector2) -> bool:
	for i in BED_POSITIONS.size():
		var d: Vector2 = (p - BED_POSITIONS[i] - Vector2(0, -10)) / (Vector2(170, 70) * BED_SCALE[i])
		if d.length() < 1.0:
			return true
	return (p - CAN_HOME).length() < 95.0


## Light on the beings: warm at dusk, cool moonlight at night, and the
## shadow direction follows the sky sun (it falls away from it, longer at dusk).
func _tick_light() -> void:
	var ev := _evening()
	var night := clampf(ev * 2.0 - 1.0, 0.0, 1.0)
	var dusk := clampf(ev * 2.0, 0.0, 1.0) * (1.0 - night)
	dusk = maxf(dusk, _stage_light * 0.45)
	var tint := Color.WHITE.lerp(Color(1.0, 0.86, 0.74), dusk * 0.7).lerp(Color(0.6, 0.66, 0.92), night * 0.75)
	if _paper_mat:
		# season and time of day grade the whole picture, sky and ground included
		var sh: Vector3 = [Vector3(0.0, 0.0, 0.02), Vector3(-0.01, 0.0, 0.02), Vector3(0.02, -0.01, 0.02), Vector3(-0.02, 0.0, 0.05)][season]
		var li: Vector3 = [Vector3(0.03, 0.01, 0.02), Vector3(0.03, 0.02, -0.01), Vector3(0.05, 0.025, -0.02), Vector3(0.0, 0.01, 0.03)][season]
		sh = sh.lerp(Vector3(0.03, -0.01, 0.06), dusk).lerp(Vector3(-0.02, 0.0, 0.06), night)
		li = li.lerp(Vector3(0.08, 0.02, -0.03), dusk).lerp(Vector3(0.0, 0.01, 0.04), night)
		_paper_mat.set_shader_parameter("grade_shadow", sh)
		_paper_mat.set_shader_parameter("grade_light", li)
		_paper_mat.set_shader_parameter("grade_amount", 1.0)
		_paper_mat.set_shader_parameter("vignette", 1.0 + _stage_light * 3.0)
	for c in beds:
		if c:
			c.light = tint
			c.shadow_dir = clampf((c.global_position.x - 560.0) / 700.0, -1.0, 1.0) * (0.35 + ev * 1.2) * (1.0 - night)


func set_season(s_: int) -> void:
	if s_ != season and is_inside_tree() and not screenshot_mode:
		_season_fade = 1.0
	season = s_
	_season_parts.clear()
	if season != Season.SUMMER:
		var n := 30 if season == Season.WINTER else 10
		for i in n:
			_season_parts.append([Vector2(randf() * 1400 - 60, randf() * 760), randf() * TAU])
	for c in beds:
		if c:
			c.season = season


func _apply_season() -> void:
	var chosen := int(settings.get("season", -1))
	set_season(chosen if chosen >= 0 else _auto_season)


func _rain_mood() -> float:
	return _rain_amount


func _draw_tree(base: Vector2, k: float, night: float, vivid: float) -> void:
	var trunk := Color("8a5a3b").lerp(Color("2a2430"), night * 0.8)
	var crown: Color = SEASONS[season][4].lerp(Color("1d3a3c"), night).lerp(Color("4f7a50"), 1.0 - vivid)
	var trunk_pts := PackedVector2Array([base + Vector2(-14, 0) * k, base + Vector2(-9, -110) * k, base + Vector2(9, -110) * k, base + Vector2(14, 0) * k])
	draw_colored_polygon(trunk_pts, trunk)
	trunk_pts.append(trunk_pts[0])
	draw_polyline(trunk_pts, trunk.darkened(0.5), 3.5, true)
	var blobs := [Vector3(-40, -130, 52), Vector3(36, -138, 50), Vector3(0, -180, 60), Vector3(-10, -120, 44)]
	for b in blobs:
		draw_circle(base + Vector2(b.x, b.y) * k, b.z * k + 3.5, crown.darkened(0.5))
	for b in blobs:
		draw_circle(base + Vector2(b.x, b.y) * k, b.z * k, crown)
	draw_circle(base + Vector2(14, -120) * k, 34 * k, crown.darkened(0.1))
	draw_circle(base + Vector2(-22, -196) * k, 20 * k, crown.lightened(0.12))
	for a in [Vector2(-30, -150), Vector2(26, -170), Vector2(4, -128)]:
		draw_circle(base + a * k, (9 if season == Season.SPRING else 6) * k, SEASONS[season][5].lerp(crown, night * 0.8))
	if season == Season.WINTER:
		for b in [Vector3(-40, -170, 34), Vector3(36, -176, 30), Vector3(0, -226, 40)]:
			draw_circle(base + Vector2(b.x, b.y) * k, b.z * k, Color("f6f9fc").lerp(Color("2a3558"), night * 0.7))


## A small tuft of flowers that sways; colours follow the season.
func _draw_flower_cluster(at: Vector2, seed_i: int, night: float) -> void:
	var stem := Color("4f8f3a").lerp(Color("1d3a3c"), night * 0.8)
	if season == Season.WINTER:
		_draw_ellipse(at + Vector2(0, 2), Vector2(26, 9), Color("f4f7fb").lerp(Color("3b3f7a"), night * 0.7))
		return
	var cols := [Color("ff8fb8"), Color("ffd45c"), Color("b58cf0"), Color("ff7a6b"), Color("ffffff")]
	if season == Season.AUTUMN:
		cols = [Color("c9674e"), Color("e09a3e"), Color("9b6bd6"), Color("d4704f"), Color("f0c05a")]
	for j in 5:
		var h := 22.0 + fmod(seed_i * 7.0 + j * 5.3, 14.0)
		var base := at + Vector2(-20 + j * 10, (j % 2) * 3)
		var sway := sin(_t * 1.8 + seed_i + j * 0.7) * 4.0 + _beat_kick * 3.0 * (1.0 if j % 2 == 0 else -1.0)
		var top := base + Vector2(sway, -h)
		draw_line(base, top, stem, 2.5)
		_draw_ellipse(base + Vector2(sway * 0.4 - 4, -h * 0.45), Vector2(5, 2.5), stem.lightened(0.2))
		var c: Color = cols[(seed_i + j) % cols.size()].lerp(Color("2a3558"), night * 0.75)
		for q in 5:
			var a := TAU * q / 5.0 + seed_i
			draw_circle(top + Vector2.from_angle(a) * 4.5, 4.0, c)
		draw_circle(top, 2.8, Color("ffe27a").lerp(Color("2a3558"), night * 0.6))


## A turquoise dragonfly hovering and darting above the pond.
func _draw_dragonfly(c: Vector2, night: float) -> void:
	if night > 0.3 or weather == Weather.RAIN or season == Season.WINTER:
		return
	var hop := floorf(_t / 2.5)
	var p := c + Vector2(sin(hop * 2.3) * 50, cos(hop * 1.7) * 22 - 20) + Vector2(sin(_t * 3.0) * 2, cos(_t * 4.0) * 2)
	var body := Color("2f8f9a")
	var wing := Color(0.85, 0.95, 1.0, 0.45 + 0.2 * sin(_t * 40.0))
	for side in [-1.0, 1.0]:
		_draw_ellipse(p + Vector2(-3, side * 7), Vector2(9, 3.5), wing)
		_draw_ellipse(p + Vector2(4, side * 6), Vector2(8, 3), wing)
	draw_line(p + Vector2(-20, 0), p + Vector2(6, 0), body, 3.0)
	draw_circle(p + Vector2(8, 0), 3.5, body.darkened(0.2))


## A ladybug walking along the fence rail.
func _draw_ladybug(fence: Vector2, night: float) -> void:
	if night > 0.3 or season == Season.WINTER:
		return
	var u := fmod(_t * 0.03, 2.0)
	u = u if u < 1.0 else 2.0 - u
	var p := fence + Vector2(u * 250.0, -26.0 - u * 6.0 - 4.0)
	var dir := 1.0 if fmod(_t * 0.03, 2.0) < 1.0 else -1.0
	draw_circle(p, 5.5, Color("d93b3b"))
	draw_circle(p + Vector2(5 * dir, 0), 3, Color("2b2340"))
	draw_line(p + Vector2(0, -5), p + Vector2(0, 5), Color("2b2340"), 1.0)
	draw_circle(p + Vector2(-2, -2), 1.2, Color("2b2340"))
	draw_circle(p + Vector2(-2, 2.5), 1.2, Color("2b2340"))


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


func _ellipse_pts(c: Vector2, r: Vector2, n := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


func _draw_pond(c: Vector2, sky: Color, night: float) -> void:
	var frozen := season == Season.WINTER
	var rim := Color("9c8f7e").lerp(Color("2a2a40"), night * 0.8)
	draw_colored_polygon(_ellipse_pts(c + Vector2(0, 3), Vector2(98, 30)), rim.darkened(0.3))
	draw_colored_polygon(_ellipse_pts(c, Vector2(94, 27)), rim)
	var water := Color("5fb7d9").lerp(sky, 0.35).lerp(Color("1b2a50"), night * 0.8)
	if frozen:
		water = Color("cfe7f3").lerp(Color("3b4a70"), night * 0.8)
	draw_colored_polygon(_ellipse_pts(c + Vector2(0, 2), Vector2(84, 21)), water.darkened(0.12))
	draw_colored_polygon(_ellipse_pts(c + Vector2(0, -1), Vector2(80, 18)), water)
	# sky reflection streaks
	for k in 3:
		var y := c.y - 6 + k * 6
		var w := 46.0 - k * 10.0
		var shift := sin(_t * 0.8 + k) * 6.0
		draw_line(Vector2(c.x - w + shift, y), Vector2(c.x + w * 0.4 + shift, y), Color(1, 1, 1, 0.35 if not frozen else 0.7), 2.5, true)
	if state == State.NIGHT and not frozen:
		_draw_ellipse(c + Vector2(-20 + sin(_t * 1.3) * 2.0, 2), Vector2(13, 4.5), Color(0.97, 0.95, 0.78, 0.7))
	if frozen:
		return
	# lily pads with a blossom
	for lp in [Vector3(-40, 4, 15), Vector3(28, -5, 12), Vector3(52, 8, 10)]:
		var pc := c + Vector2(lp.x, lp.y)
		var pad := PackedVector2Array([pc])
		for i in 15:
			var a := 0.35 + (TAU - 0.7) * i / 14.0
			pad.append(pc + Vector2(cos(a) * lp.z, sin(a) * lp.z * 0.45))
		draw_colored_polygon(pad, Color("5fa14a").lerp(Color("15302a"), night))
	if season != Season.AUTUMN:
		for i in 5:
			var a := TAU * i / 5.0
			draw_circle(c + Vector2(-40, -1) + Vector2(cos(a) * 5, sin(a) * 2.5), 4.0, Color("ffc1da").lerp(Color("3b3f7a"), night * 0.6))
		draw_circle(c + Vector2(-40, -2), 2.5, Color("ffd84d"))
	# every sung note sends a coloured ring across the pond
	for r in _song_rings:
		var u: float = r[0] / 2.2
		var ring := _ellipse_pts(c + Vector2(10, 0), Vector2(10 + u * 70, (10 + u * 70) * 0.26), 40)
		ring.append(ring[0])
		draw_polyline(ring, Color(Color(r[1]).lightened(0.3), 0.8 * (1.0 - u)), 3.0, true)
	# ripples: rain drops or a gentle periodic ring
	var rings := 3 if weather == Weather.RAIN else 1
	for i in rings:
		var ph := fmod(_t * (0.9 if rings > 1 else 0.35) + i * 0.37, 1.0)
		var rc := c + Vector2(fmod(i * 47.0 + floor(_t * 0.9 + i * 0.37) * 31.0, 110.0) - 55.0, fmod(i * 13.0, 14.0) - 7.0)
		draw_arc(rc, 4 + ph * 18, 0, TAU, 20, Color(1, 1, 1, 0.5 * (1.0 - ph)), 1.5, true)


func _draw_can(ci: CanvasItem, at: Vector2, night: float, rot := 0.0, glow := 0.0, held := false) -> void:
	var c := Color("6fa8e8").lerp(Color("2a3558"), night * 0.8)
	var ink := c.darkened(0.55)
	ci.draw_set_transform(at, rot, Vector2.ONE)
	var o := Vector2.ZERO
	if held:
		# white sticker outline so the tool reads clearly over anything
		var halo := PackedVector2Array([o + Vector2(-42, 6), o + Vector2(-36, -68), o + Vector2(38, -68), o + Vector2(42, 6)])
		ci.draw_colored_polygon(halo, Color.WHITE)
		ci.draw_line(o + Vector2(-30, -30), o + Vector2(-76, -68), Color.WHITE, 18.0)
		ci.draw_circle(o + Vector2(-80, -70), 17, Color.WHITE)
		ci.draw_arc(o + Vector2(0, -62), 24, PI, TAU, 16, Color.WHITE, 14.0, true)
	if glow > 0.0:
		ci.draw_circle(o + Vector2(10, -35), 66 + sin(_t * 4.0) * 4.0, Color(1, 0.95, 0.6, 0.25 * glow))
	ci.draw_line(o + Vector2(-30, -30), o + Vector2(-74, -66), ink, 10.0)
	ci.draw_line(o + Vector2(-30, -30), o + Vector2(-74, -66), c, 6.0)
	var rose := PackedVector2Array()
	for k in 12:
		var t := TAU * k / 12.0
		rose.append(o + Vector2(-80, -70) + Vector2(cos(t) * 8, sin(t) * 13).rotated(-0.8))
	ci.draw_colored_polygon(rose, c.lightened(0.2))
	var body := PackedVector2Array([o + Vector2(-36, 0), o + Vector2(-30, -62), o + Vector2(32, -62), o + Vector2(36, 0)])
	ci.draw_colored_polygon(body, c)
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-36, 0), o + Vector2(-33, -24), o + Vector2(34, -24), o + Vector2(36, 0)]), c.darkened(0.12))
	var closed := body.duplicate()
	closed.append(body[0])
	ci.draw_polyline(closed, ink, 3.0, true)
	ci.draw_arc(o + Vector2(0, -62), 24, PI, TAU, 16, ink, 6.0, true)
	ci.draw_circle(o + Vector2(14, -42), 7, Color(1, 1, 1, 0.35))
	ci.draw_set_transform(Vector2.ZERO)


func _draw_overlay() -> void:
	_draw_spots()
	if _hold_t >= 0.0 and _hold_bed >= 0 and beds[_hold_bed] and _t - _hold_t > 0.3:
		var c = beds[_hold_bed]
		var u := clampf((_t - _hold_t - 0.3) / 1.6, 0.0, 1.0)
		var at: Vector2 = c.global_position + Vector2(0, -c.height() * 0.5)
		_overlay.draw_arc(at, c.height() * 0.6, -PI / 2, -PI / 2 + TAU * u, 48, Color(1, 1, 1, 0.85), 8.0, true)
	if state == State.ECHO and not _echo_listen:
		_draw_echo_badge()
	if _season_fade > 0.0:
		_overlay.draw_rect(Rect2(-100, -100, 1480, 920), Color(0.99, 0.97, 0.92, 0.85 * _season_fade * _season_fade))
	_draw_help()
	for dr in _pour_drops:
		if dr[2] > 0.0:
			_overlay.draw_circle(dr[0], 6.5, Color(0.45, 0.72, 0.98, 0.95 - float(dr[2])))
			_overlay.draw_circle(dr[0] + Vector2(-2, -2), 2.2, Color(1, 1, 1, 0.8 - float(dr[2])))
	if _can_held:
		var tilt := -0.55 * clampf(_pour * 3.0, 0.0, 1.0) if _pour > 0.0 else sin(_t * 3.0) * 0.06
		_draw_can(_overlay, _can_pos + Vector2(0, 30), 0.0, tilt, 0.0, true)
	for fl in _flashes:
		var u: float = fl[1] / 0.12
		_overlay.draw_circle(fl[0], 60.0 * minf(u, 1.0), Color(1, 1, 1, 0.5 * (1.0 - minf(fl[1] / 0.2, 1.0))))
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
	if (state == State.RECORDING and _rec_bed >= 0) or _echo_listen:
		var c: Vector2 = _mic_pos if _echo_listen else BED_POSITIONS[_rec_bed] + Vector2(0, -130 * BED_SCALE[_rec_bed])
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
		var prog := _rec_time / (_rec_len if _echo_listen else Audio.RECORD_SECONDS)
		_overlay.draw_arc(c, 68, -PI / 2, -PI / 2 + TAU * prog, 48, Color("ffd45c"), 9.0, true)


## Small round buttons in the same painted style as the big ones.
## Warm stage light cones from above onto the singing beings.
func _draw_spots() -> void:
	for sp in _spots:
		var p: Vector2 = sp[0]
		var a: float = sp[1]
		var w: float = sp[2]
		var top := Vector2(p.x + (640.0 - p.x) * 0.2, -40)
		for k in 3:
			var ww := w * (1.0 + k * 0.25)
			_overlay.draw_colored_polygon(PackedVector2Array([top + Vector2(-14 - k * 8, 0), top + Vector2(14 + k * 8, 0), p + Vector2(ww, 10), p + Vector2(-ww, 10)]), Color(1, 0.95, 0.75, 0.11 * a))
		for k in 3:
			_overlay.draw_colored_polygon(_ellipse_pts(p + Vector2(0, 6), Vector2(w * (1.25 - k * 0.15), 30 - k * 4), 32), Color(1, 0.93, 0.65, 0.14 * a))


## Echo game: a badge at the top says "listen" (ear + notes) while the
## beings sing, and "your turn" (tapping hand) while they wait.
func _draw_echo_badge() -> void:
	var c := Vector2(640, 92)
	var pulse := 1.0 + 0.06 * sin(_t * 5.0)
	_overlay.draw_circle(c + Vector2(0, 6), 50 * pulse, Color(0, 0, 0, 0.18))
	_overlay.draw_circle(c, 50 * pulse, Color("3a2e4a"))
	_overlay.draw_circle(c, 44 * pulse, Color("b58cf0") if not _echo_waiting else Color("fff3a0"))
	if _echo_waiting:
		_draw_tap_hand(c + Vector2(-14, -22), fmod(_t, 2.0), 1.0)
	else:
		_overlay.draw_arc(c + Vector2(-6, 0), 18, -PI * 0.6, PI * 0.75, 16, Color("2f2a4a"), 6.0, true)
		_overlay.draw_arc(c + Vector2(-6, 0), 8, -PI * 0.5, PI * 0.5, 10, Color("2f2a4a"), 4.0, true)
		for k in 2:
			_help_note(c + Vector2(18 + k * 14, -10 - sin(_t * 4.0 + k) * 5.0), 1.0)


func _small_stone(c: Vector2, col: Color) -> void:
	_front.draw_circle(c + Vector2(0, 5), 28, Color(0, 0, 0, 0.22))
	_front.draw_circle(c, 28, Color("3a2e4a"))
	_front.draw_circle(c, 23, col)
	_front.draw_arc(c, 17, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.7), 4.0, true)


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
	# matte painted stone: ink ring, flat fill, a darker belly instead of a glossy glint
	var r := BTN_R * press * (0.78 if c == BTN_SUN or c == BTN_RAIN else 0.9)
	col = col.lerp(Color("bdb6c8"), 0.12)
	_front.draw_circle(c + Vector2(0, 7), r + 4, Color(0.12, 0.06, 0.1, 0.2))
	_front.draw_circle(p, r + 4, Color("3a2e4a"))
	_front.draw_circle(p, r - 2, col)
	var belly := PackedVector2Array()
	for i in 17:
		var a := PI * 0.15 + PI * 0.7 * i / 16.0
		belly.append(p + Vector2(cos(a), sin(a)) * (r - 2))
	for i in range(16, -1, -1):
		var a := PI * 0.15 + PI * 0.7 * i / 16.0
		belly.append(p + Vector2(cos(a) * (r - 2), sin(a) * (r - 2) * 0.55 + (r - 2) * 0.2))
	_front.draw_colored_polygon(belly, col.darkened(0.12))
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


## "Sing it back": two speech bubbles, a note going out and one coming back.
func _draw_ear_icon(c: Vector2) -> void:
	c += _btn_offset
	var ink := Color(0.17, 0.14, 0.27, _btn_alpha)
	var white := Color(1, 1, 1, _btn_alpha)
	for side in [-1, 1]:
		var bc := c + Vector2(side * 13, side * -9)
		var r := 17.0 if side < 0 else 14.0
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(bc + Vector2(cos(a) * r * 1.15, sin(a) * r))
		_front.draw_colored_polygon(pts, white)
		var tail := PackedVector2Array([bc + Vector2(side * -6, r - 3), bc + Vector2(side * -16, r + 9), bc + Vector2(side * 4, r - 2)])
		_front.draw_colored_polygon(tail, white)
		var closed := pts.duplicate()
		closed.append(pts[0])
		_front.draw_polyline(closed, ink, 3.0, true)
		var nc := bc + Vector2(-3, 5) * (r / 17.0)
		_front.draw_circle(nc, 4.5 * r / 17.0, ink)
		_front.draw_line(nc + Vector2(4, 0) * r / 17.0, nc + Vector2(4, -14) * r / 17.0, ink, 3.0)
		_front.draw_line(nc + Vector2(4, -14) * r / 17.0, nc + Vector2(10, -10) * r / 17.0, ink, 3.0)


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
	var ridge := pts.duplicate()
	pts.append(Vector2(1900, 900))
	pts.append(Vector2(-600, 900))
	draw_colored_polygon(pts, col)
	draw_polyline(ridge, col.darkened(0.18), 3.0, true)


## Picture-book cloud: puffs with a shaded belly, a flat bottom and a sunny top.
func _draw_cloud(c: Vector2, k: float, col: Color, seed_i := 0) -> void:
	var puffs := [Vector3(-46, 2, 26), Vector3(-16, -16, 34), Vector3(20, -24, 30), Vector3(50, -4, 24), Vector3(4, 4, 30), Vector3(72, 8, 16)]
	if seed_i % 2 == 1:
		puffs = [Vector3(-38, 0, 22), Vector3(-8, -12, 28), Vector3(26, -6, 26), Vector3(52, 6, 16)]
	var rim := Color(col.darkened(0.22), col.a * 0.55)
	var belly := Color(col.darkened(0.1).lerp(Color("b9c6e6"), 0.25), col.a)
	for b in puffs:
		draw_circle(c + Vector2(b.x, b.y) * k, b.z * k + 3.0, rim)
	for b in puffs:
		draw_circle(c + Vector2(b.x, b.y) * k, b.z * k, belly)
	for b in puffs:
		draw_circle(c + Vector2(b.x - 2, b.y - 6) * k, b.z * k * 0.86, col)
	# flat, slightly shaded underside
	draw_rect(Rect2(c + Vector2(-50, 10) * k, Vector2(110, 14) * k), belly)
	draw_line(c + Vector2(-50, 24) * k, c + Vector2(60, 24) * k, rim, 2.0)
	for b in puffs.slice(1, 3):
		draw_circle(c + Vector2(b.x - 6, b.y - 14) * k, b.z * k * 0.35, Color(1, 1, 1, col.a * 0.45))


## A little windmill on the far hill, slowly turning (faster with wind/rain).
func _draw_windmill(base: Vector2, hill: Color, night: float) -> void:
	var wall := Color("f3e6d0").lerp(hill, 0.35).lerp(Color("2a3558"), night * 0.7)
	var roof := Color("c9674e").lerp(hill, 0.3).lerp(Color("2a3558"), night * 0.7)
	var ink := wall.darkened(0.45)
	var body := PackedVector2Array([base + Vector2(-13, 0), base + Vector2(-8, -42), base + Vector2(8, -42), base + Vector2(13, 0)])
	draw_colored_polygon(body, wall)
	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3]]), ink, 1.5, true)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-11, -41), base + Vector2(0, -55), base + Vector2(11, -41)]), roof)
	draw_rect(Rect2(base + Vector2(-3, -12), Vector2(6, 12)), ink)
	if night > 0.3:
		draw_circle(base + Vector2(0, -28), 12, Color(1, 0.8, 0.4, 0.25 * night))
		draw_circle(base + Vector2(0, -28), 4, Color(1, 0.85, 0.4, night))
	var hub := base + Vector2(0, -44)
	var spin := _mill_angle
	for k in 4:
		var a := spin + k * TAU / 4.0
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * 4.0
		draw_line(hub, hub + dir * 30, ink, 2.0)
		draw_colored_polygon(PackedVector2Array([hub + dir * 9, hub + dir * 30, hub + dir * 30 + side, hub + dir * 9 + side]), Color(wall.lightened(0.15), 0.95))
	draw_circle(hub, 3, ink)


## A flock of little birds crossing the sky now and then (by day only).
func _draw_birds(night: float) -> void:
	if night > 0.2 or weather == Weather.RAIN:
		return
	var cyc := fmod(_t + 20.0, 120.0)
	if cyc < 75.0 or cyc > 89.0:
		return
	var u := (cyc - 75.0) / 14.0 # crossing takes 14 s
	var lead := Vector2(lerpf(-80.0, 1360.0, u), 175.0 - sin(u * PI) * 50.0)
	var ink := Color("3a3550", 0.75 * (1.0 - night * 4.0))
	for i in 5:
		var off := Vector2(-i * 26 - (i % 2) * 8, (i % 3) * 14 - 10 + i * 4)
		var p := lead + off
		var flap := sin(_t * 9.0 + i * 1.3) * 5.0
		var w := 9.0 - i * 0.6
		draw_polyline(PackedVector2Array([p + Vector2(-w, -flap), p + Vector2(-w * 0.4, -flap * 0.3 - 1), p, p + Vector2(w * 0.4, -flap * 0.3 - 1), p + Vector2(w, -flap)]), ink, 2.2, true)


func _balloon_pos() -> Vector2:
	var cyc := fmod(_t + 20.0, 120.0)
	if cyc > 60.0 or _evening() > 0.6 or weather == Weather.RAIN or season == Season.WINTER or state == State.CONCERT:
		return Vector2.ZERO
	return Vector2(lerpf(-60.0, 1340.0, cyc / 60.0), 120.0 + sin(_t * 0.4) * 10.0)


## A hot-air balloon drifting very slowly across the far sky.
func _draw_balloon(night: float, vivid: float) -> void:
	# one sky event at a time: balloon first, birds later in the 120 s cycle
	var cyc := fmod(_t + 20.0, 120.0)
	if cyc > 60.0 or night > 0.2 or weather == Weather.RAIN or season == Season.WINTER or state == State.CONCERT:
		return
	var c := _balloon_pos()
	var cols := [Color("ff8fb8"), Color("ffd45c"), Color("4cc3b5"), Color("ffd45c")]
	var dim := night * 0.7 + (1.0 - vivid) * 0.3
	var r := 22.0
	draw_circle(c, r + 2, Color(Color("3a2e4a"), 0.6))
	# gores: nested lens shapes, widest first
	for k in 4:
		var w := r * (1.0 - k * 0.27)
		draw_colored_polygon(_ellipse_pts(c, Vector2(w, r), 28), cols[k].lerp(Color("2a3558"), dim))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.95, 4), c + Vector2(0, r * 1.45), c + Vector2(r * 0.95, 4)]), Color(cols[0].lerp(Color("2a3558"), dim).darkened(0.1)))
	draw_line(c + Vector2(-6, r * 1.2), c + Vector2(-5, r * 1.75), Color("3a2e4a"), 1.2)
	draw_line(c + Vector2(6, r * 1.2), c + Vector2(5, r * 1.75), Color("3a2e4a"), 1.2)
	draw_rect(Rect2(c + Vector2(-6, r * 1.75), Vector2(12, 8)), Color("a0714a").lerp(Color("2a3558"), dim))
	draw_circle(c + Vector2(-8, -10), 5, Color(1, 1, 1, 0.35 * (1.0 - dim)))


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
	if not settings.mic:
		Audio.release_mic()
	Audio.set_volume(settings.volume)
	_apply_language()
	_help_font = null
	_save()


func _delete_recordings() -> void:
	for i in bed_data.size():
		var d = bed_data[i]
		if d and d.has("file"):
			_remove_bed(i)
		elif d and d.has("voice"):
			d.erase("voice")
			if beds[i]:
				var keep: Dictionary = d.duplicate()
				_remove_bed(i)
				bed_data[i] = keep
				_spawn(i, null, false)
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
	if d and d.has("voice"):
		DirAccess.remove_absolute("user://" + str(d.voice))
	if beds[i]:
		beds[i].queue_free()
	beds[i] = null
	bed_data[i] = null


func _apply_language() -> void:
	var lang: String = settings.get("lang", "")
	TranslationServer.set_locale(lang if lang != "" else OS.get_locale())


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
		f.store_string(JSON.stringify({"version": 1, "settings": settings, "beds": bed_data, "next_preset": _next_preset, "auto_season": _auto_season}))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	if data.has("settings"):
		settings.merge(data.settings, true)
	_next_preset = int(data.get("next_preset", 0))
	_auto_season = int(data.get("auto_season", 1))
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
