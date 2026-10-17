extends Node2D
## One garden being. Its look comes from pitch (shape) and loudness (size, colour).

const SIZES := [0.62, 0.8, 1.0]
const COLORS := [
	# LOW: mushrooms
	[Color("c98bd9"), Color("e0604f"), Color("8a5bd1")],
	# MID: round critters
	[Color("7fd6c2"), Color("f2a93b"), Color("4fa3e8")],
	# HIGH: flowers
	[Color("ffb3d1"), Color("ff7fa8"), Color("f25f9a")],
]

var pitch := 1
var loud := 1
var stream: AudioStream
var freq := 261.63

var grow := 0.0
var sing_amp := 0.0
var sleeping := false
var _t := randf() * 10.0
var _sleep_blend := 0.0


func setup(p: int, l: int, s: AudioStream, f: float) -> void:
	pitch = p
	loud = l
	stream = s
	freq = f


func grow_in(duration := 1.4) -> void:
	grow = 0.0
	var tw := create_tween()
	tw.tween_property(self, "grow", 1.0, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func sing(shift: float) -> void:
	Audio.play(stream, freq, shift)
	var tw := create_tween()
	tw.tween_property(self, "sing_amp", 1.0, 0.08)
	tw.tween_property(self, "sing_amp", 0.0, 0.6).set_trans(Tween.TRANS_SINE)


func radius() -> float:
	return 80.0 * SIZES[loud]


func _process(delta: float) -> void:
	_t += delta
	_sleep_blend = move_toward(_sleep_blend, 1.0 if sleeping else 0.0, delta * 0.7)
	queue_redraw()


func _draw() -> void:
	var s: float = SIZES[loud] * grow
	if s <= 0.01:
		return
	var sway := sin(_t * (0.6 if sleeping else 1.6)) * 0.05 * (1.0 - _sleep_blend * 0.7)
	var squash := 1.0 + 0.18 * sing_amp
	draw_set_transform(Vector2.ZERO, sway, Vector2(s / sqrt(squash), s * squash))
	var col: Color = COLORS[pitch][loud]
	col = col.lerp(Color("4a4f7a"), _sleep_blend * 0.45)
	match pitch:
		0: _draw_mushroom(col)
		1: _draw_critter(col)
		_: _draw_flower(col)
	draw_set_transform(Vector2.ZERO)
	if _sleep_blend > 0.5:
		_draw_zzz(s)


func _draw_mushroom(col: Color) -> void:
	var stem := Color("f3e6cf").lerp(Color("6a6a8a"), _sleep_blend * 0.4)
	draw_rect(Rect2(-22, -70, 44, 70), stem)
	draw_circle(Vector2(0, -2), 22, stem)
	var cap := PackedVector2Array()
	for i in 25:
		var a := PI + PI * i / 24.0
		cap.append(Vector2(cos(a) * 62, -66 + sin(a) * 52))
	draw_colored_polygon(cap, col)
	for d in [Vector2(-30, -88), Vector2(8, -104), Vector2(32, -80), Vector2(-6, -78)]:
		draw_circle(d, 8, Color(1, 1, 1, 0.85))
	_draw_face(Vector2(0, -40), 0.8)


func _draw_critter(col: Color) -> void:
	draw_circle(Vector2(-20, -6), 12, col.darkened(0.25))
	draw_circle(Vector2(20, -6), 12, col.darkened(0.25))
	draw_circle(Vector2(0, -50), 48, col)
	draw_circle(Vector2(0, -36), 28, col.lightened(0.25))
	for side in [-1, 1]:
		var tip := Vector2(side * 26, -122 + sin(_t * 3.0 + side) * 4)
		draw_line(Vector2(side * 14, -92), tip, col.darkened(0.3), 4.0)
		draw_circle(tip, 8, Color("ffe066"))
	_draw_face(Vector2(0, -58), 1.0)


func _draw_flower(col: Color) -> void:
	var green := Color("4f9e45").lerp(Color("3b4d5c"), _sleep_blend * 0.5)
	draw_line(Vector2(0, 0), Vector2(0, -100), green, 8.0)
	_draw_leaf(Vector2(0, -40), -1, green)
	_draw_leaf(Vector2(0, -62), 1, green)
	var center := Vector2(0, -120)
	var petals := 5 + loud
	var spin := _t * 0.3 * (1.0 - _sleep_blend)
	for i in petals:
		var a := TAU * i / petals + spin
		draw_circle(center + Vector2(cos(a), sin(a)) * 34, 22, col)
	draw_circle(center, 28, Color("ffd84d").lerp(Color("8a8060"), _sleep_blend * 0.4))
	_draw_face(center, 0.75)


func _draw_leaf(at: Vector2, side: int, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		pts.append(at + Vector2(side * u * 36, -sin(u * PI) * 12 - u * 10))
	for i in range(12, -1, -1):
		var u := float(i) / 12.0
		pts.append(at + Vector2(side * u * 36, sin(u * PI) * 8 - u * 10))
	draw_colored_polygon(pts, col)


func _draw_face(c: Vector2, k: float) -> void:
	var ink := Color("2b2340")
	var eye_dx := 14.0 * k
	for side in [-1, 1]:
		var e := c + Vector2(side * eye_dx, -6 * k)
		if _sleep_blend > 0.5:
			draw_arc(e, 6 * k, 0.2, PI - 0.2, 8, ink, 3.0)
		else:
			draw_circle(e, 8 * k, Color.WHITE)
			draw_circle(e + Vector2(0, 1), 4.5 * k, ink)
	draw_circle(c + Vector2(-22 * k, 6 * k), 5 * k, Color(1, 0.5, 0.6, 0.5))
	draw_circle(c + Vector2(22 * k, 6 * k), 5 * k, Color(1, 0.5, 0.6, 0.5))
	var m := c + Vector2(0, 10 * k)
	if sing_amp > 0.08:
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			pts.append(m + Vector2(cos(a) * 7 * k, sin(a) * (3 + 9 * sing_amp) * k))
		draw_colored_polygon(pts, ink)
	elif _sleep_blend > 0.5:
		draw_circle(m, 3 * k, ink)
	else:
		draw_arc(m + Vector2(0, -4 * k), 8 * k, 0.4, PI - 0.4, 10, ink, 3.0)


func _draw_zzz(s: float) -> void:
	var font := ThemeDB.fallback_font
	for i in 3:
		var ph := fmod(_t * 0.5 + i / 3.0, 1.0)
		var pos := Vector2(30 + ph * 30, -150 * s - ph * 60)
		draw_string(font, pos, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 + 14 * ph), Color(1, 1, 1, 1.0 - ph))
