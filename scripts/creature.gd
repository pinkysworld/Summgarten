extends Node2D
## One garden being. Pitch × loudness picks one of nine species, each with its
## own silhouette, palette and personality. Drawn as picture-book gouache:
## flat fills, a soft inner shade, one highlight and a coloured contour.

signal sang(who: Node2D)

enum Species { MUSHROOM, PUMPKIN, SNAIL, BEETLE, BIRD, FROG, DAISY, BELL, SUNFLOWER }

## Height of each species at full growth (for hit boxes and note spawn).
const HEIGHTS := [190.0, 150.0, 170.0, 175.0, 170.0, 150.0, 205.0, 215.0, 235.0]
const PALETTE := [
	Color("9b6bd6"), # mushroom cap: lilac
	Color("ff9a3c"), # pumpkin: orange
	Color("ffc93c"), # snail shell: mustard
	Color("4cc3b5"), # beetle: turquoise
	Color("6fa8e8"), # bird: sky blue
	Color("7cc86a"), # frog: leaf green
	Color("ff8fb8"), # daisy: pink
	Color("b58cf0"), # bellflower: violet
	Color("ffc93c"), # sunflower: mustard
]
const INK := Color("2b2340")

var pitch := 1
var loud := 1
var species := 0
var stream: AudioStream
var freq := 261.63

var grow := 0.0
var stage := 2.0 ## 0..1 sprout, 1..2 bud, then the full being grows in
var joy := 0.0
var beat_pulse := 0.0
var glow := 0.0 ## highlight while singing a phrase in the echo game
var _invite := 0.0
var season := 1 ## 0 spring flower, 1 none, 2 leaf, 3 knit hat
var yawn_amt := 0.0
var bow_amt := 0.0
var hop := 0.0
var sing_amp := 0.0
var sleeping := false

var _t := randf() * 10.0
var _sleep_blend := 0.0
var _look := Vector2.ZERO
var _look_target := Vector2.ZERO
var _look_hold := 0.0
var _blink := 0.0
var _next_blink := randf_range(1.5, 4.5)
var _bob := 0.0
var _notes: Array = [] ## [pos, vel, age, color]
var _sparkles: Array = [] ## [pos, vel, age, color]


func setup(p: int, l: int, s: AudioStream, f: float) -> void:
	pitch = p
	loud = l
	species = p * 3 + l
	stream = s
	freq = f


func height() -> float:
	return HEIGHTS[species] * scale.y


func radius() -> float:
	return 75.0 * scale.x


func grow_in(duration := 1.4, stages := true) -> void:
	grow = 0.0
	var tw := create_tween()
	if stages:
		stage = 0.0
		tw.tween_property(self, "stage", 1.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "stage", 2.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		stage = 2.0
	tw.tween_property(self, "grow", 1.0, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	var cols := [Color("fff3a0"), Color.WHITE, PALETTE[species].lightened(0.3)]
	for i in 26:
		var a := randf() * TAU
		_sparkles.append([Vector2(0, -30), Vector2(cos(a), sin(a) - 0.7) * randf_range(90, 240), 0.0, cols[i % 3]])


func sing(shift: float) -> void:
	Audio.play(stream, freq, shift)
	sang.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "sing_amp", 1.0, 0.08)
	tw.tween_property(self, "sing_amp", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	var top: float = -HEIGHTS[species] - 10.0
	for i in 2:
		_notes.append([Vector2(randf_range(-25, 25), top), Vector2(randf_range(-35, 35), -80), -i * 0.15, PALETTE[species]])


func highlight() -> void:
	var tw := create_tween()
	tw.tween_property(self, "glow", 1.0, 0.1)
	tw.tween_property(self, "glow", 0.0, 0.7)


## Waiting for the child: a soft shimmer that says "tap me".
func invite() -> void:
	_invite = 4.0


## Gentle bop on the music's beat.
func pulse() -> void:
	if sleeping or grow < 0.9:
		return
	beat_pulse = 1.0
	var tw := create_tween()
	tw.tween_property(self, "beat_pulse", 0.0, 0.3).set_trans(Tween.TRANS_SINE)


## Tapped: a happy face with squinted eyes and a big smile.
func cheer() -> void:
	var tw := create_tween()
	tw.tween_property(self, "joy", 1.0, 0.1)
	tw.tween_interval(0.6)
	tw.tween_property(self, "joy", 0.0, 0.3)


func yawn() -> void:
	var tw := create_tween()
	tw.tween_property(self, "yawn_amt", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.4)
	tw.tween_property(self, "yawn_amt", 0.0, 0.5).set_trans(Tween.TRANS_SINE)


func bow() -> void:
	var tw := create_tween()
	tw.tween_property(self, "bow_amt", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.4)
	tw.tween_property(self, "bow_amt", 0.0, 0.45).set_trans(Tween.TRANS_BACK)


func celebrate_hop(delay: float) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(self, "hop", 1.0, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "hop", 0.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## A neighbour sang: look at it and bob along a little.
func notice(from: Vector2) -> void:
	if sleeping:
		return
	_look_target = (from - global_position).normalized()
	_look_hold = 1.6
	var tw := create_tween()
	tw.tween_property(self, "_bob", 1.0, 0.12)
	tw.tween_property(self, "_bob", 0.0, 0.3)


func _process(delta: float) -> void:
	_t += delta
	_sleep_blend = move_toward(_sleep_blend, 1.0 if sleeping else 0.0, delta * 0.7)
	_look_hold -= delta
	if _look_hold <= 0.0:
		_look_target = Vector2.ZERO
		if randf() < delta * 0.3:
			_look_target = Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5))
			_look_hold = randf_range(0.8, 2.0)
	_look = _look.lerp(_look_target, minf(1.0, delta * 8.0))
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 1.0
		_next_blink = randf_range(2.0, 5.0)
	_blink = maxf(0.0, _blink - delta * 7.0)
	_invite = maxf(0.0, _invite - delta)
	for n in _notes:
		n[2] += delta
		if n[2] > 0.0:
			n[0] += n[1] * delta
			n[0].x += sin(n[2] * 8.0) * 0.6
	_notes = _notes.filter(func(n): return n[2] < 1.6)
	for sp in _sparkles:
		sp[2] += delta
		sp[0] += sp[1] * delta
		sp[1].y += 260.0 * delta
	_sparkles = _sparkles.filter(func(sp): return sp[2] < 1.0)
	queue_redraw()


# ------------------------------------------------------------- drawing helpers

func _col(c: Color) -> Color:
	return c.lerp(Color("4a4f7a"), _sleep_blend * 0.45)


func _ink(c: Color) -> Color:
	return _col(c).darkened(0.5)


## Filled circle with coloured contour.
func _circ(p: Vector2, r: float, c: Color, outline := true) -> void:
	draw_circle(p, r, _col(c))
	if outline:
		draw_arc(p, r, 0, TAU, 40, _ink(c), 3.0, true)


func _ell_pts(c: Vector2, r: Vector2, rot := 0.0, n := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


func _poly(pts: PackedVector2Array, c: Color, outline := true) -> void:
	draw_colored_polygon(pts, _col(c))
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, _ink(c), 3.0, true)


func _ell(c: Vector2, r: Vector2, col: Color, rot := 0.0, outline := true) -> void:
	_poly(_ell_pts(c, r, rot), col, outline)


func _shine(p: Vector2, r: Vector2) -> void:
	draw_colored_polygon(_ell_pts(p, r, -0.5, 16), Color(1, 1, 1, 0.45 * (1.0 - _sleep_blend * 0.6)))


func _shade(p: Vector2, r: Vector2, c: Color) -> void:
	draw_colored_polygon(_ell_pts(p, r, 0.0, 24), Color(_col(c).darkened(0.18), 0.55))


func _stem(from: Vector2, to: Vector2, bend: float, c: Color, w := 9.0) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		pts.append(from.lerp(to, u) + Vector2(sin(u * PI) * bend, 0))
	draw_polyline(pts, _ink(c), w + 5.0, true)
	draw_polyline(pts, _col(c), w, true)


func _leaf(at: Vector2, ang: float, length: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		pts.append(Vector2(u * length, -sin(u * PI) * length * 0.32))
	for i in range(11, 0, -1):
		var u := float(i) / 12.0
		pts.append(Vector2(u * length, sin(u * PI) * length * 0.22))
	for i in pts.size():
		pts[i] = at + pts[i].rotated(ang)
	_poly(pts, c)
	draw_line(at, at + Vector2(length * 0.8, 0).rotated(ang), _ink(c), 2.0, true)


# ------------------------------------------------------------- main draw

func _draw() -> void:
	if stage < 2.0:
		_draw_stage()
		return
	var s := grow
	if s <= 0.08:
		return
	var halo := maxf(glow, 0.7 * (0.5 + 0.5 * sin(_t * 5.0)) if _invite > 0.0 else 0.0)
	if halo > 0.01:
		var mid := Vector2(0, -HEIGHTS[species] * 0.5 * s)
		for k in 3:
			draw_circle(mid, (HEIGHTS[species] * 0.55 + k * 14) * s, Color(1, 0.95, 0.55, 0.22 * halo))
		draw_arc(mid, (HEIGHTS[species] * 0.55 + 36) * s, 0, TAU, 48, Color(1, 1, 1, 0.8 * halo), 5.0, true)
	# soft ground shadow
	draw_colored_polygon(_ell_pts(Vector2(0, 4), Vector2(62 * s, 14 * s), 0.0, 24), Color(0.1, 0.05, 0.1, 0.22))
	var sway := sin(_t * (0.6 if sleeping else 1.6)) * 0.045 * (1.0 - _sleep_blend * 0.7)
	var breath := 0.018 * sin(_t * 2.2) * (1.0 - _sleep_blend * 0.3) * (0.6 if not sleeping else 1.4)
	var squash := 1.0 + 0.16 * sing_amp + 0.06 * beat_pulse + breath
	var lean := sway + bow_amt * 0.45 + _look.x * 0.05
	draw_set_transform(Vector2(0, -hop * 40.0 - _bob * 8.0), lean, Vector2(s / sqrt(squash), s * squash * (1.0 - bow_amt * 0.12)))
	match species:
		Species.MUSHROOM: _draw_mushroom()
		Species.PUMPKIN: _draw_pumpkin()
		Species.SNAIL: _draw_snail()
		Species.BEETLE: _draw_beetle()
		Species.BIRD: _draw_bird()
		Species.FROG: _draw_frog()
		Species.DAISY: _draw_daisy()
		Species.BELL: _draw_bell()
		_: _draw_sunflower()
	_draw_accessory()
	draw_set_transform(Vector2.ZERO)
	if _sleep_blend > 0.5:
		_draw_zzz()
	for sp in _sparkles:
		var k: float = 1.0 - float(sp[2])
		_star(sp[0], 9.0 * k, Color(sp[3], k))
	for n in _notes:
		if n[2] > 0.0:
			var life: float = clampf(1.6 - float(n[2]), 0.0, 1.0)
			_note(n[0], maxf(0.6, life), n[3], 0.4 + 0.6 * life)


## Sprout (stage 0..1) and bud (1..2) before the being appears.
func _draw_stage() -> void:
	var green := Color("5fa14a")
	var c: Color = PALETTE[species]
	var k := clampf(stage, 0.0, 1.0)
	var wob := sin(_t * 6.0) * 0.08
	draw_set_transform(Vector2.ZERO, wob, Vector2.ONE * (0.6 + 0.4 * k))
	var h := 30.0 + 40.0 * clampf(stage, 0.0, 2.0) / 2.0
	_stem(Vector2(0, 0), Vector2(0, -h), 4.0, green, 6.0)
	_leaf(Vector2(0, -h * 0.55), -2.6, 26 + 8 * k, Color("7cc86a"))
	_leaf(Vector2(0, -h * 0.65), -0.5, 26 + 8 * k, Color("7cc86a"))
	if stage >= 1.0:
		var b := clampf(stage - 1.0, 0.0, 1.0)
		var bud := _ell_pts(Vector2(0, -h - 14 * b), Vector2(16, 22) * b + Vector2(2, 2), 0.0, 20)
		_poly(bud, c)
		_shine(Vector2(-5, -h - 22 * b), Vector2(4, 6) * b + Vector2(1, 1))
		if b > 0.5:
			draw_arc(Vector2(-6, -h - 12), 3.5, 0.2, PI - 0.2, 6, INK, 2.0, true)
			draw_arc(Vector2(6, -h - 12), 3.5, 0.2, PI - 0.2, 6, INK, 2.0, true)
	draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------- species

func _draw_mushroom() -> void:
	var cap := PALETTE[Species.MUSHROOM]
	var stem := Color("f6ead2")
	var body := PackedVector2Array([Vector2(-30, 0), Vector2(-26, -96), Vector2(26, -96), Vector2(30, 0)])
	_poly(body, stem)
	_shade(Vector2(14, -48), Vector2(10, 40), stem)
	_face(Vector2(0, -52), 1.0)
	var top := PackedVector2Array()
	for i in 29:
		var a := PI + PI * i / 28.0
		top.append(Vector2(cos(a) * 82, -96 + sin(a) * 78))
	for i in range(1, 28):
		var a := PI * i / 28.0
		top.append(Vector2(cos(a) * 82, -96 + sin(a) * 12))
	_poly(top, cap)
	_shade(Vector2(30, -112), Vector2(40, 22), cap)
	for d in [Vector3(-42, -130, 13), Vector3(4, -156, 15), Vector3(44, -122, 11), Vector3(-6, -114, 9)]:
		_circ(Vector2(d.x, d.y), d.z, Color("fff8ec"), false)
	_shine(Vector2(-40, -148), Vector2(18, 9))


func _draw_pumpkin() -> void:
	var c := PALETTE[Species.PUMPKIN]
	_stem(Vector2(0, -118), Vector2(8, -146), 6.0, Color("6b8e3a"), 10.0)
	_leaf(Vector2(8, -136), -0.5, 42, Color("7cc86a"))
	for x in [-46.0, 46.0]:
		_ell(Vector2(x, -60), Vector2(44, 58), c.darkened(0.08))
	_ell(Vector2(0, -62), Vector2(52, 62), c)
	_shade(Vector2(20, -40), Vector2(22, 34), c)
	_shine(Vector2(-22, -96), Vector2(14, 8))
	_face(Vector2(0, -64), 1.1)


func _draw_snail() -> void:
	var body := Color("b8e0a8")
	var shell := PALETTE[Species.SNAIL]
	var foot := PackedVector2Array()
	for i in 21:
		var u := float(i) / 20.0
		foot.append(Vector2(lerpf(-92, 70, u), -6 + sin(u * PI) * 4))
	foot.append(Vector2(96, -40))
	foot.append(Vector2(98, -96))
	foot.append(Vector2(68, -104))
	foot.append(Vector2(56, -44))
	foot.append(Vector2(-60, -30))
	_poly(foot, body)
	for side in [-1.0, 1.0]:
		var tip := Vector2(84 + side * 16, -150 + sin(_t * 3.0 + side) * 4)
		draw_line(Vector2(82 + side * 6, -100), tip, _ink(body), 7.0, true)
		draw_line(Vector2(82 + side * 6, -100), tip, _col(body), 4.0, true)
		_circ(tip, 7, body)
	_face(Vector2(82, -70), 0.8)
	_circ(Vector2(-14, -86), 72, shell)
	_shade(Vector2(14, -66), Vector2(42, 40), shell)
	var spiral := PackedVector2Array()
	for i in 60:
		var a := i * 0.2
		spiral.append(Vector2(-14, -86) + Vector2(cos(a), sin(a)) * (6 + i * 0.95))
	draw_polyline(spiral, _ink(shell), 4.0, true)
	_shine(Vector2(-50, -130), Vector2(16, 9))


func _draw_beetle() -> void:
	var c := PALETTE[Species.BEETLE]
	for x in [-26.0, 26.0]:
		_ell(Vector2(x, -10), Vector2(16, 11), c.darkened(0.3))
	for side in [-1.0, 1.0]:
		var tip := Vector2(side * 32, -168 + sin(_t * 3.0 + side) * 5)
		draw_line(Vector2(side * 16, -126), tip, _ink(c), 5.0, true)
		_circ(tip, 10, Color("ffc93c"))
	_ell(Vector2(0, -72), Vector2(66, 70), c)
	_ell(Vector2(0, -52), Vector2(40, 34), c.lightened(0.35), 0.0, false)
	_shade(Vector2(28, -54), Vector2(24, 36), c)
	_shine(Vector2(-30, -112), Vector2(18, 10))
	_face(Vector2(0, -84), 1.2)


func _draw_bird() -> void:
	var c := PALETTE[Species.BIRD]
	for x in [-14.0, 14.0]:
		draw_line(Vector2(x, 0), Vector2(x, -22), _ink(Color("ff9a3c")), 5.0, true)
	var tail := PackedVector2Array([Vector2(-52, -70), Vector2(-104, -108), Vector2(-96, -60)])
	_poly(tail, c.darkened(0.15))
	_ell(Vector2(0, -78), Vector2(62, 62), c)
	_ell(Vector2(4, -56), Vector2(38, 32), Color("fff1d6"), 0.0, false)
	var flap := sin(_t * 2.0) * 0.12 + sing_amp * 0.5
	_ell(Vector2(-26, -76), Vector2(32, 20), c.darkened(0.12), 0.6 + flap)
	_poly(PackedVector2Array([Vector2(46, -92), Vector2(78, -84 + sing_amp * 6), Vector2(46, -74)]), Color("ffb03c"))
	for k in 3:
		_ell(Vector2(-8 + k * 10, -146 - k * 4), Vector2(5, 14), c.darkened(0.2), -0.3 + k * 0.3)
	_shine(Vector2(-22, -118), Vector2(16, 9))
	_face(Vector2(14, -96), 1.0, false)


func _draw_frog() -> void:
	var c := PALETTE[Species.FROG]
	for x in [-56.0, 56.0]:
		_ell(Vector2(x, -12), Vector2(24, 12), c.darkened(0.15))
	_ell(Vector2(0, -56), Vector2(80, 54), c)
	_ell(Vector2(0, -40), Vector2(52, 26), Color("e9f7c8"), 0.0, false)
	_shade(Vector2(36, -44), Vector2(30, 24), c)
	for x in [-38.0, 38.0]:
		_circ(Vector2(x, -110), 26, c)
	_shine(Vector2(-50, -80), Vector2(18, 9))
	_eyes([Vector2(-38, -112), Vector2(38, -112)], 1.4)
	_cheeks(Vector2(0, -66), 2.2)
	_mouth(Vector2(0, -64), 1.8, true)


func _draw_daisy() -> void:
	var c := PALETTE[Species.DAISY]
	var green := Color("5fa14a")
	_stem(Vector2(0, 0), Vector2(0, -120), 10.0, green)
	_leaf(Vector2(2, -40), -2.6, 52, Color("7cc86a"))
	_leaf(Vector2(4, -74), -0.5, 46, Color("7cc86a"))
	var center := Vector2(0, -140)
	var spin := _t * 0.25 * (1.0 - _sleep_blend)
	for i in 7:
		var a := TAU * i / 7.0 + spin
		_ell(center + Vector2(cos(a), sin(a)) * 44, Vector2(28, 19), c, a)
	_circ(center, 38, Color("ffd84d"))
	_shine(center + Vector2(-14, -18), Vector2(10, 6))
	_face(center, 0.95)


func _draw_bell() -> void:
	var c := PALETTE[Species.BELL]
	var green := Color("5fa14a")
	var stem := PackedVector2Array()
	for i in 17:
		var u := float(i) / 16.0
		stem.append(Vector2(sin(u * 2.4) * 46, -u * 210))
	draw_polyline(stem, _ink(green), 13.0, true)
	draw_polyline(stem, _col(green), 8.0, true)
	_leaf(Vector2(8, -50), -2.9, 50, Color("7cc86a"))
	_leaf(Vector2(30, -110), -0.4, 40, Color("7cc86a"))
	for b in [Vector2(-34, -150), Vector2(64, -176)]:
		var bell := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			bell.append(b + Vector2(-cos(a) * 16, -sin(a) * 18))
		bell.append(b + Vector2(20, 10))
		bell.append(b + Vector2(-20, 10))
		_poly(bell, c.lightened(0.15))
	# the big singing bell hangs from the top: dome, flaring sides, five curled tips
	var top := Vector2(30, -206)
	var hang := sin(_t * 1.5) * 0.08 + sing_amp * 0.25
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(Vector2(cos(a) * 40, 34 + sin(a) * 30))
	for i in 7:
		var u := float(i) / 6.0
		pts.append(Vector2(40 + 18 * u * u, 34 + 58 * u))
	for tip in 5:
		var x0 := lerpf(58, -58, float(tip) / 5.0)
		var x1 := lerpf(58, -58, float(tip + 1) / 5.0)
		var mx := (x0 + x1) / 2.0
		pts.append(Vector2(lerpf(x0, mx, 0.5) + 4, 104))
		pts.append(Vector2(mx, 116))
		pts.append(Vector2(lerpf(mx, x1, 0.5) - 4, 104))
		if tip < 4:
			pts.append(Vector2(x1, 96))
	for i in range(6, -1, -1):
		var u := float(i) / 6.0
		pts.append(Vector2(-40 - 18 * u * u, 34 + 58 * u))
	for i in pts.size():
		pts[i] = top + pts[i].rotated(hang)
	_poly(pts, c)
	_shade(top + Vector2(22, 66).rotated(hang), Vector2(14, 28), c)
	_shine(top + Vector2(-20, 30).rotated(hang), Vector2(10, 7))
	# green calyx joins the bell to the stem
	var calyx := PackedVector2Array()
	for i in 10:
		var a := PI + PI * i / 9.0
		var r := 22.0 if i % 2 == 0 else 12.0
		calyx.append(top + Vector2(cos(a) * r, 8 + sin(a) * r * 0.6).rotated(hang))
	_poly(calyx, green)
	_face(top + Vector2(0, 72).rotated(hang), 0.95)


func _draw_sunflower() -> void:
	var c := PALETTE[Species.SUNFLOWER]
	var green := Color("5fa14a")
	_stem(Vector2(0, 0), Vector2(0, -150), -14.0, green, 11.0)
	_leaf(Vector2(-4, -50), -2.7, 64, Color("6cbf58"))
	_leaf(Vector2(-6, -96), -0.35, 58, Color("6cbf58"))
	var center := Vector2(0, -170)
	var spin := _t * 0.15 * (1.0 - _sleep_blend)
	for ring in 2:
		for i in 12:
			var a := TAU * (i + ring * 0.5) / 12.0 + spin
			var col := c if ring == 1 else c.darkened(0.12)
			_ell(center + Vector2(cos(a), sin(a)) * (58 - ring * 4), Vector2(30, 13), col, a)
	_circ(center, 48, Color("8a5a2b"))
	for i in 18:
		var a := i * 2.4
		var r := sqrt(float(i)) * 9.0
		draw_circle(center + Vector2(cos(a), sin(a)) * r, 2.6, _col(Color("5e3b1a")))
	_face(center + Vector2(0, 6), 1.15)


## Accessory anchor per species: (x, y) = centre of the hat brim, z = scale.
## Always well above the eyes so nothing covers a face.
const HAT := [Vector3(0, -170, 1.0), Vector3(0, -122, 0.95), Vector3(84, -104, 0.62), Vector3(0, -138, 1.0),
	Vector3(6, -138, 0.9), Vector3(-38, -134, 0.62), Vector3(0, -176, 0.82), Vector3(30, -200, 0.8), Vector3(0, -216, 0.95)]
const HAT_TILT := [-0.12, 0.1, 0.08, -0.1, 0.12, -0.2, 0.1, -0.08, 0.12]


func _draw_accessory() -> void:
	if season == 1:
		return
	var h: Vector3 = HAT[species]
	var at := Vector2(h.x, h.y)
	var k := h.z
	var rot: float = HAT_TILT[species]
	match season:
		0: # a little blossom tucked on the side of the head
			var bc := at + Vector2(26, -4).rotated(rot) * k
			for i in 5:
				var a := TAU * i / 5.0
				_circ(bc + Vector2(cos(a), sin(a)) * 7 * k, 6 * k, Color("ffc1da"))
			_circ(bc, 5 * k, Color("ffd84d"))
		2: # an autumn leaf on top
			_leaf(at + Vector2(-4, -2) * k, -1.9 + rot, 34 * k, Color("e08a3c"))
		3: # knitted hat: dome, ribs, curved brim, pompom
			var dome := PackedVector2Array()
			for i in 15:
				var a := PI + PI * i / 14.0
				dome.append(at + Vector2(cos(a) * 32, -4 + sin(a) * 34).rotated(rot) * k)
			_poly(dome, Color("e05a5a"))
			for st in 3:
				var x := -14.0 + st * 14.0
				draw_line(at + Vector2(x, -6).rotated(rot) * k, at + Vector2(x * 0.7, -30).rotated(rot) * k, _col(Color("b83a3a")), 2.5 * k, true)
			var brim := PackedVector2Array()
			for i in 13:
				var u := float(i) / 12.0
				brim.append(at + Vector2(lerpf(-36, 36, u), -8 - sin(u * PI) * 6).rotated(rot) * k)
			for i in range(12, -1, -1):
				var u := float(i) / 12.0
				brim.append(at + Vector2(lerpf(-36, 36, u), 6 - sin(u * PI) * 6).rotated(rot) * k)
			_poly(brim, Color("f4ead8"))
			for st in 5:
				var x := -26.0 + st * 13.0
				draw_line(at + Vector2(x, -10 - sin((x + 36) / 72.0 * PI) * 6).rotated(rot) * k, at + Vector2(x, 4 - sin((x + 36) / 72.0 * PI) * 6).rotated(rot) * k, _col(Color("e8dcc8")).darkened(0.1), 2.0, true)
			_circ(at + Vector2(0, -42).rotated(rot) * k, 10 * k, Color("fff3e0"))


# ------------------------------------------------------------- face

func _face(c: Vector2, k: float, cheeks := true) -> void:
	_eyes([c + Vector2(-16 * k, -6 * k), c + Vector2(16 * k, -6 * k)], k)
	if cheeks:
		_cheeks(c, k)
	_mouth(c + Vector2(0, 12 * k), k)


func _eyes(at: Array, k: float) -> void:
	for e in at:
		if joy > 0.3 and _sleep_blend < 0.5:
			draw_arc(e + Vector2(0, 3 * k), 7 * k, PI + 0.3, TAU - 0.3, 10, INK, 3.5, true)
		elif _sleep_blend > 0.5 or _blink > 0.3 or yawn_amt > 0.4:
			draw_arc(e, 6 * k, 0.2, PI - 0.2, 10, INK, 3.0, true)
		else:
			draw_circle(e, 9 * k, Color.WHITE)
			draw_arc(e, 9 * k, 0, TAU, 20, INK, 2.0, true)
			var pupil: Vector2 = e + Vector2(0, 1) + _look * 3.5 * k
			draw_circle(pupil, 5.2 * k, INK)
			draw_circle(pupil + Vector2(-1.8, -2.0) * k, 1.9 * k, Color.WHITE)


func _cheeks(c: Vector2, k: float) -> void:
	for side in [-1, 1]:
		draw_colored_polygon(_ell_pts(c + Vector2(side * 26 * k, 7 * k), Vector2(7, 4.5) * k, 0.0, 16), Color(1, 0.45, 0.55, 0.45))


func _mouth(m: Vector2, k: float, wide := false) -> void:
	var w := (16.0 if wide else 8.0) * k
	if yawn_amt > 0.05:
		draw_colored_polygon(_ell_pts(m, Vector2(w * 0.8, (4 + 12 * yawn_amt) * k), 0.0, 18), INK)
		draw_colored_polygon(_ell_pts(m + Vector2(0, (3 + 6 * yawn_amt) * k), Vector2(w * 0.45, 3 * k), 0.0, 12), Color("ff7a8a"))
	elif joy > 0.1 and sing_amp <= 0.08:
		var pts := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			pts.append(m + Vector2(cos(a) * w * 1.2, -2 * k + sin(a) * (8 * joy) * k))
		draw_colored_polygon(pts, INK)
		draw_colored_polygon(_ell_pts(m + Vector2(0, 3 * k * joy), Vector2(w * 0.5, 2.5 * k * joy + 0.5), 0.0, 12), Color("ff7a8a"))
	elif sing_amp > 0.08:
		draw_colored_polygon(_ell_pts(m, Vector2(w * 0.9, (3 + 10 * sing_amp) * k), 0.0, 18), INK)
		draw_colored_polygon(_ell_pts(m + Vector2(0, (2 + 5 * sing_amp) * k), Vector2(w * 0.5, 3 * k), 0.0, 12), Color("ff7a8a"))
	elif _sleep_blend > 0.5:
		draw_circle(m, 3 * k, INK)
	else:
		draw_arc(m + Vector2(0, -5 * k), w, 0.45, PI - 0.45, 12, INK, 3.0, true)


# ------------------------------------------------------------- particles

func _star(c: Vector2, r: float, col: Color) -> void:
	if r < 0.8:
		return
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * i / 8.0 - PI / 2
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.42))
	draw_colored_polygon(pts, col)


## Saturated note with a white contour so it reads on any sky.
func _note(c: Vector2, alpha: float, col: Color, size := 1.0) -> void:
	draw_set_transform(c, 0.0, Vector2.ONE * 1.5 * size)
	c = Vector2.ZERO
	var fill := Color(col.darkened(0.15), alpha)
	var rim := Color(1, 1, 1, alpha)
	draw_colored_polygon(_ell_pts(c, Vector2(14, 11), -0.35, 18), rim)
	draw_line(c + Vector2(9, -2), c + Vector2(9, -34), rim, 8.0)
	draw_line(c + Vector2(9, -34), c + Vector2(22, -24), rim, 8.0)
	draw_colored_polygon(_ell_pts(c, Vector2(11, 8), -0.35, 18), fill)
	draw_line(c + Vector2(9, -2), c + Vector2(9, -34), fill, 4.0)
	draw_line(c + Vector2(9, -34), c + Vector2(22, -24), fill, 4.0)
	draw_set_transform(Vector2.ZERO)


func _draw_zzz() -> void:
	var font := ThemeDB.fallback_font
	var top: float = -HEIGHTS[species] * grow
	for i in 3:
		var ph := fmod(_t * 0.5 + i / 3.0, 1.0)
		var pos := Vector2(34 + ph * 30, top - ph * 60)
		var size := int(20 + 16 * ph)
		draw_string_outline(font, pos, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.17, 0.14, 0.3, 1.0 - ph))
		draw_string(font, pos, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 1.0 - ph))
