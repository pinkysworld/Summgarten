class_name MinhStudioIntro
extends CanvasLayer
## Studio intro "minh.studios" (Minh Nguyen Studios). Self-contained Godot 4 addon: no autoloads, no game code.
##
## Full animation (theme.duration, default 2.95 s):
##   the accent dot appears -> "minh" types itself in front of it -> "minh.systems" is typed, "ystems" deleted and
##   "tudios" typed (the brand's own correction) while the loop in the round sign runs one loader round (segment
##   gradient tail -> head, then settles to the solid accent) -> "MINH NGUYEN STUDIOS" fades in, tracking closing
##   -> fade out. Everything is drawn live as vectors (fonts, antialiased polylines): sharp at any resolution.
## Modes: FULL, SHORT (static logo, fade in / hold / out; e.g. from the second start on), STATIC (reduced motion:
## static logo with fades only, no typing / spinning / tracking motion).
## Skip: any key, mouse button, touch or pad button -> `skipped`, short fade, then `finished`.
##
##   var intro := MinhStudioIntro.play(self, preload("res://addons/minh_studio_intro/presets/germ_theory.tres"))
##   await intro.finished

signal fade_started  ## the fade-out begins (put the next screen underneath now)
signal skipped       ## the player skipped (before `finished`)
signal finished      ## the intro is gone (the node frees itself)

enum Mode { FULL, SHORT, STATIC }

const ADDON := "res://addons/minh_studio_intro/"
const DEFAULT_THEME := ADDON + "presets/neutral_hell.tres"
const BASE_DURATION := 2.95
const SKIP_FADE := 0.28

## Timeline of the full version in seconds at BASE_DURATION (scaled to theme.duration).
const T_DOT := 0.06
const L_DOT := 0.34
const T_SIGN := 0.26
const L_SIGN := 0.5
const T_MINH := 0.42
const S_MINH := 0.085
const T_SYS := 0.82
const S_SYS := 0.052
const T_DEL := 1.3
const S_DEL := 0.03
const T_TUD := 1.52
const S_TUD := 0.052
const T_SPIN := 0.7
const L_SPIN := 1.24
const T_SETTLE := 1.78
const L_SETTLE := 0.34
const T_SUB := 1.86
const L_SUB := 0.62
const T_OUT := 2.45
const L_OUT := 0.5
const L_LETTER := 0.05
const SOUND_AT := [0.42, 0.82, 1.52]
const CLOSE_AT := 1.84

const WORD_L := "minh"
const WORD_TYPO := "systems"
const WORD_R := "studios"
const SUB := "MINH NGUYEN STUDIOS"

@export var theme: MinhIntroTheme
@export var mode := Mode.FULL
## Host switches (the addon never reads game settings itself).
@export var show_caption := false
@export var autostart := true

var t := 0.0
var paused := false  ## screenshots / tests: hold the timeline (see seek)
var _k := 1.0  ## timeline scale
var _out_start := -1.0
var _out_len := L_OUT
var _skipped := false
var _done := false
var _cues: Array = []  # [{at, stream, db}]
var _root: Control
var _bg: ColorRect
var _art: _Art
var _caption: Label
var _players: Array[AudioStreamPlayer] = []

## Creates the intro on `parent` and starts it. theme == null -> neutral light preset.
static func play(parent: Node, p_theme: MinhIntroTheme = null, p_mode := Mode.FULL, p_caption := false) -> MinhStudioIntro:
	var intro := MinhStudioIntro.new()
	intro.theme = p_theme
	intro.mode = p_mode
	intro.show_caption = p_caption
	parent.add_child(intro)
	return intro

func _init() -> void:
	layer = 95
	name = "MinhStudioIntro"
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	if theme == null:
		theme = load(DEFAULT_THEME) as MinhIntroTheme
	_k = theme.duration / BASE_DURATION
	_build()
	_schedule_sound()
	if not autostart:
		paused = true
	_layout()

# --- public API ----------------------------------------------------------------------------------------------

## Total length of the current mode (without skipping).
func length() -> float:
	return theme.short_duration if mode != Mode.FULL else theme.duration + theme.hold

func skip() -> void:
	if _skipped or _done:
		return
	_skipped = true
	paused = false
	skipped.emit()
	if _out_start < 0.0:
		_begin_out(SKIP_FADE)
	else:
		_out_len = minf(_out_len, (t - _out_start) + SKIP_FADE)
	for p in _players:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -60.0, SKIP_FADE)

## True until the fade-out has begun.
func is_showing() -> bool:
	return _out_start < 0.0 and not _done

## Jumps to `time` and holds there (screenshots, tests). Sound cues before `time` are dropped.
func seek(time: float, hold := true) -> void:
	t = time
	paused = hold
	_cues = _cues.filter(func(c: Dictionary) -> bool: return float(c["at"]) > time)
	if _art != null:
		_art.queue_redraw()

# --- build ---------------------------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.color = theme.background
	if theme.paper:
		var mat := ShaderMaterial.new()
		mat.shader = load(ADDON + "shaders/paper.gdshader")
		mat.set_shader_parameter("paper", theme.background)
		mat.set_shader_parameter("edge", theme.paper_edge)
		_bg.material = mat
	_root.add_child(_bg)
	if theme.background_texture != null:
		var tr := TextureRect.new()
		tr.texture = theme.background_texture
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(tr)
	_art = _Art.new()
	_art.intro = self
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if theme.ink_tooth > 0.0:
		var tm := ShaderMaterial.new()
		tm.shader = load(ADDON + "shaders/ink_tooth.gdshader")
		tm.set_shader_parameter("amount", theme.ink_tooth)
		_art.material = tm
	_root.add_child(_art)
	if show_caption and theme.caption_text != "":
		_caption = Label.new()
		_caption.name = "Caption"
		_caption.text = theme.caption_text
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.09, 0.08, 0.82)
		bg.set_content_margin_all(6)
		bg.content_margin_left = 14
		bg.content_margin_right = 14
		_caption.add_theme_stylebox_override("normal", bg)
		_caption.add_theme_color_override("font_color", Color("f4f2ed"))
		var cf := theme.caption_font if theme.caption_font != null else theme.sub_font
		if cf != null:
			_caption.add_theme_font_override("font", cf)
		_caption.add_theme_font_size_override("font_size", 18)
		_root.add_child(_caption)

func _schedule_sound() -> void:
	if not theme.sound:
		return
	var bus := theme.audio_bus if AudioServer.get_bus_index(theme.audio_bus) >= 0 else &"Master"
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_players.append(p)
	if mode == Mode.FULL and not theme.key_sounds.is_empty():
		for i in SOUND_AT.size():
			_cues.append({"at": float(SOUND_AT[i]) * _k, "stream": theme.key_sounds[i % theme.key_sounds.size()], "db": theme.key_volume_db})
	if theme.close_sound != null:
		var at := CLOSE_AT * _k if mode == Mode.FULL else 0.12
		_cues.append({"at": at, "stream": theme.close_sound, "db": theme.close_volume_db - (3.0 if mode == Mode.SHORT else 0.0)})

func _layout() -> void:
	var sz := _root.get_viewport_rect().size
	if _bg.material is ShaderMaterial:
		(_bg.material as ShaderMaterial).set_shader_parameter("px_size", sz)
	if _art.material is ShaderMaterial:
		# screen pixels per design pixel (1080 p), so the tooth has the same grain at 1280x800 and 4K
		var u := minf(sz.x / 1920.0, sz.y / 1080.0)
		var xf := get_viewport().get_final_transform()
		(_art.material as ShaderMaterial).set_shader_parameter("px_scale", maxf(0.25, u * xf.get_scale().y))
	if _caption != null:
		_caption.offset_bottom = -0.07 * sz.y

# --- run -----------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _done:
		return
	if not paused:
		# Lade-Ruckler beim Spielstart dürfen die Animation nicht überspringen
		t += minf(delta, 1.0 / 30.0)
	_layout()
	while not _cues.is_empty() and t >= float(_cues[0]["at"]) and not _skipped:
		var c: Dictionary = _cues.pop_front()
		_play(c["stream"], float(c["db"]))
	# FULL: after the wordmark has settled it holds for theme.hold seconds; fade_started only after that
	var out_at := (maxf(T_OUT, T_SUB + L_SUB) * _k + theme.hold) if mode == Mode.FULL else (length() - _calm_out())
	if _out_start < 0.0 and t >= out_at and not paused:
		_begin_out(L_OUT * _k if mode == Mode.FULL else _calm_out())
	var a := 1.0
	if _out_start >= 0.0:
		var k := clampf((t - _out_start) / _out_len, 0.0, 1.0)
		a = 1.0 - _smooth(k)
		if k >= 1.0:
			_finish()
			return
	_root.modulate.a = a
	_art.queue_redraw()

func _play(stream: AudioStream, db: float) -> void:
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = db
			p.play()
			return

func _begin_out(len_s: float) -> void:
	if _out_start >= 0.0:
		return
	_out_start = t
	_out_len = maxf(0.05, len_s)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_started.emit()

func _finish() -> void:
	if _done:
		return
	_done = true
	visible = false
	finished.emit()
	# let a sound tail ring out without holding the screen
	var tail := 0.0
	for p in _players:
		if p.playing:
			tail = 1.2
	if tail > 0.0 and is_inside_tree():
		await get_tree().create_timer(tail).timeout
	queue_free()

func _input(event: InputEvent) -> void:
	if _skipped or _done or not visible:
		return
	var hit := false
	if event is InputEventKey:
		hit = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventScreenTouch:
		hit = event.is_pressed()
	if hit:
		get_viewport().set_input_as_handled()
		skip()

func _calm_out() -> float:
	return 0.38 if mode == Mode.SHORT else 0.45

# --- state of the drawing at time t ----------------------------------------------------------------------------

static func _smooth(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)

static func _out_cubic(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)

static func _in_out_cubic(k: float) -> float:
	return 4.0 * k * k * k if k < 0.5 else 1.0 - pow(-2.0 * k + 2.0, 3.0) / 2.0

static func _out_back(k: float) -> float:
	var c1 := 1.30
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(k - 1.0, 3.0) + c1 * pow(k - 1.0, 2.0)

func _ph(start: float, len_s: float) -> float:
	return clampf((t - start * _k) / (len_s * _k), 0.0, 1.0)

## Everything the drawing needs at the current time (static modes: the finished logo, fade-in alpha).
func state() -> Dictionary:
	var s := {}
	if mode != Mode.FULL:
		var a_in := _smooth(clampf(t / (0.28 if mode == Mode.SHORT else 0.45), 0.0, 1.0))
		s = {"dot_a": a_in, "dot_s": 1.0, "sign_a": a_in, "sign_s": 1.0, "left": WORD_L, "left_a": [1.0, 1.0, 1.0, 1.0],
			"right": WORD_R, "right_a": [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0], "spin": 0.0, "grad": 0.0, "caret_a": 0.0,
			"caret": "", "sub_a": a_in, "sub_track": 0.30, "pres_a": a_in, "all_a": 1.0}
		return s
	var kd := _ph(T_DOT, L_DOT)
	s["dot_a"] = _smooth(minf(1.0, kd * 1.8))
	s["dot_s"] = _out_back(kd)
	var ks := _ph(T_SIGN, L_SIGN)
	s["sign_a"] = _smooth(ks)
	s["sign_s"] = lerpf(0.86, 1.0, _out_cubic(ks))
	# left word: letters typed at T_MINH + i * S_MINH
	var la: Array = []
	for i in WORD_L.length():
		la.append(_ph(T_MINH + i * S_MINH, L_LETTER))
	s["left"] = WORD_L
	s["left_a"] = la
	# right word: "systems" typed, "ystems" deleted (last first), "tudios" typed
	var ra: Array = []
	var right := WORD_TYPO
	if t < (T_TUD - 0.001) * _k:
		var deleted := 0
		for j in WORD_TYPO.length() - 1:
			if t >= (T_DEL + j * S_DEL) * _k:
				deleted += 1
		for i in WORD_TYPO.length():
			var a := _ph(T_SYS + i * S_SYS, L_LETTER)
			if i >= WORD_TYPO.length() - deleted:
				a = 0.0
			ra.append(a)
	else:
		right = WORD_R
		ra.append(1.0)
		for i in range(1, WORD_R.length()):
			ra.append(_ph(T_TUD + (i - 1) * S_TUD, L_LETTER))
	s["right"] = right
	s["right_a"] = ra
	# caret: after the last visible letter; solid right after a key, blinking in the pauses, gone with the sub line
	var caret := ""
	var last_key := -1.0
	var times: Array = []
	for i in WORD_L.length():
		times.append(T_MINH + i * S_MINH)
	for i in WORD_TYPO.length():
		times.append(T_SYS + i * S_SYS)
	for j in WORD_TYPO.length() - 1:
		times.append(T_DEL + j * S_DEL)
	for i in range(1, WORD_R.length()):
		times.append(T_TUD + (i - 1) * S_TUD)
	for tk: float in times:
		if t >= tk * _k:
			last_key = maxf(last_key, tk * _k)
	if t < (T_MINH + (WORD_L.length() - 1) * S_MINH + 0.06) * _k:
		caret = "left"  # then it hops over the dot and waits where "systems" begins
	else:
		caret = "right"
	var c_on := _ph(0.3, 0.08)
	var c_off := 1.0 - _ph(T_SUB, 0.16)
	var blink := 1.0
	if last_key < 0.0 or t - last_key > 0.32:
		blink = 1.0 if fmod(t - maxf(0.0, last_key), 0.53) < 0.3 else 0.0
	s["caret"] = caret
	s["caret_a"] = c_on * c_off * blink
	# loader round: offset -TAU -> 0 (ends at the rest position), gradient fades into the solid accent
	s["spin"] = -TAU * (1.0 - _in_out_cubic(_ph(T_SPIN, L_SPIN)))
	s["grad"] = 1.0 - _smooth(_ph(T_SETTLE, L_SETTLE)) if t >= T_SPIN * _k else 1.0
	var ku := _ph(T_SUB, L_SUB)
	s["sub_a"] = _smooth(ku)
	s["sub_track"] = lerpf(0.52, 0.30, _out_cubic(ku))
	s["pres_a"] = _smooth(_ph(T_SUB + 0.16, L_SUB))
	s["all_a"] = 1.0
	return s


## The drawing: sign, wordmark, caret, sub line, frame. Layout in design units of a 1920x1080 page (Python
## build_minh_brand.py lock3 at 960/560, scale 1.35), scaled to the screen (u = min(w/1920, h/1080)).
class _Art extends Control:
	var intro: MinhStudioIntro
	var _wf: Font
	var _sf: Font

	func _ready() -> void:
		_wf = intro.theme.wordmark_font if intro.theme.wordmark_font != null else load(MinhStudioIntro.ADDON + "fonts/InterDisplay-SemiBold.ttf")
		_sf = intro.theme.sub_font if intro.theme.sub_font != null else load(MinhStudioIntro.ADDON + "fonts/Inter-SemiBold.ttf")

	## x offsets of each glyph (kerning via shaped prefixes) plus tracking (em) and the total advance.
	static func advances(font: Font, s: String, fsize: int, track_em: float) -> Array:
		var xs: Array = []
		for i in s.length():
			xs.append(font.get_string_size(s.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + i * track_em * fsize)
		var total := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + (s.length() - 1) * track_em * fsize
		xs.append(total)
		return xs

	func _draw() -> void:
		var th := intro.theme
		var st := intro.state()
		var sz := size
		var u := minf(sz.x / 1920.0, sz.y / 1080.0)
		if th.frame:
			_frame(sz, u, th.frame_color)
		var S := 175.5 * u  # wordmark size (lock3 130 * 1.35)
		var fs := maxi(1, int(round(S)))
		var track := -0.025
		var xl: Array = advances(_wf, WORD_L, fs, track)
		var xr: Array = advances(_wf, WORD_R, fs, track)
		var w1: float = xl[-1]
		var w2: float = xr[-1]
		var gap := S * 0.22
		var R := S * 0.42
		var signw := 2.0 * R + S * 0.32
		var total := signw + w1 + gap + w2
		var x0 := sz.x * 0.5 - total * 0.5
		var y := sz.y * 0.5 + 20.0 * u
		var tx := x0 + signw
		# sign
		_sign(Vector2(x0 + R, y - S * 0.27), R, st)
		# left word
		for i in WORD_L.length():
			var a: float = st["left_a"][i]
			if a > 0.0:
				_wf.draw_char(get_canvas_item(), Vector2(tx + float(xl[i]), y), WORD_L.unicode_at(i), fs, Color(th.ink, a))
		# dot
		var dc := Vector2(tx + w1 + gap * 0.5, y - S * 0.072)
		var dr := S * 0.072 * float(st["dot_s"])
		if float(st["dot_a"]) > 0.0 and dr > 0.05:
			draw_circle(dc, dr, Color(th.accent, st["dot_a"]), true, -1.0, true)
		# right word (fixed start; "systems" may run past the final edge for a moment)
		var rx := tx + w1 + gap
		var rword: String = st["right"]
		var xw: Array = advances(_wf, rword, fs, track)
		var last_x := rx
		for i in rword.length():
			var a: float = st["right_a"][i]
			if a > 0.0:
				_wf.draw_char(get_canvas_item(), Vector2(rx + float(xw[i]), y), rword.unicode_at(i), fs, Color(th.ink, a))
				last_x = rx + float(xw[i + 1]) - track * fs
		# caret
		var ca: float = st["caret_a"]
		if ca > 0.0:
			var cx := last_x
			if st["caret"] == "left":
				cx = tx
				for i in WORD_L.length():
					if float(st["left_a"][i]) > 0.0:
						cx = tx + float(xl[i + 1]) - track * fs
			cx += S * 0.03
			var cw := maxf(1.0, S * 0.036)
			draw_rect(Rect2(cx, y - S * 0.74, cw, S * 0.82), Color(th.caret, ca * 0.9))
		# sub line: tracked caps, centred on its final position, tracking closing in
		var sub_a: float = st["sub_a"]
		if sub_a > 0.0:
			var ss := maxi(1, int(round(S * 0.20)))
			var tr: float = st["sub_track"]
			var fin: Array = advances(_sf, SUB, ss, 0.30)
			var cur: Array = advances(_sf, SUB, ss, tr)
			var centre := tx + float(fin[-1]) * 0.5
			var sx := centre - float(cur[-1]) * 0.5
			for i in SUB.length():
				_sf.draw_char(get_canvas_item(), Vector2(sx + float(cur[i]), y + S * 0.52), SUB.unicode_at(i), ss, Color(th.sub_ink, sub_a))
		# optional "presents" line
		var pa: float = st["pres_a"]
		if th.presents_text != "" and pa > 0.0:
			var ps := maxi(1, int(round(18.0 * u * 1.0)))
			var p_text := th.presents_text.to_upper()
			var pc: Array = advances(_sf, p_text, ps, 0.5)
			var px := sz.x * 0.5 - float(pc[-1]) * 0.5
			for i in p_text.length():
				_sf.draw_char(get_canvas_item(), Vector2(px + float(pc[i]), y + 340.0 * u), p_text.unicode_at(i), ps, Color(th.sub_ink, pa * 0.9))

	func _sign(c: Vector2, R: float, st: Dictionary) -> void:
		var th := intro.theme
		var a: float = st["sign_a"]
		if a <= 0.0:
			return
		var sc: float = st["sign_s"]
		R *= sc
		draw_circle(c, R, Color(th.sign_fill, a), true, -1.0, true)
		var W := R * 1.36
		var H := W * 0.46
		var sw := R * 0.17
		var base := MinhStudioIntro.lem_pts(c, W, H, 240, 0.0, TAU)
		draw_polyline(base, Color(th.sign_loop, a), sw, true)
		var off: float = st["spin"]
		var seg := MinhStudioIntro.lem_pts(c, W, H, 120, -1.05 + off, 1.0 + off)
		var g: float = st["grad"]
		var cols := PackedColorArray()
		for i in seg.size():
			var k := float(i) / float(seg.size() - 1)
			var col := th.segment_from.lerp(th.segment_to, k).lerp(th.accent, 1.0 - g)
			cols.append(Color(col, a))
		draw_polyline_colors(seg, cols, sw, true)
		draw_circle(seg[0], sw * 0.5, cols[0], true, -1.0, true)
		draw_circle(seg[seg.size() - 1], sw * 0.5, cols[cols.size() - 1], true, -1.0, true)

	func _frame(sz: Vector2, u: float, col: Color) -> void:
		var r1 := Rect2(Vector2(70, 60) * u, sz - Vector2(140, 120) * u)
		var r2 := Rect2(Vector2(82, 72) * u, sz - Vector2(164, 144) * u)
		draw_rect(r1, Color(col, 0.85), false, maxf(1.0, 2.4 * u), true)
		draw_rect(r2, Color(col, 0.7), false, maxf(1.0, 0.9 * u), true)


## Bernoulli lemniscate stretched to height H (the brand's loop), points from t0 to t1.
static func lem_pts(c: Vector2, W: float, H: float, n: int, t0: float, t1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var tt := t0 + (t1 - t0) * float(i) / float(n)
		var s := sin(tt)
		var co := cos(tt)
		var den := 1.0 + s * s
		pts.append(Vector2(c.x + (W * 0.5) * co / den, c.y + (H * 0.5) * (s * co / den) / 0.3536))
	return pts
