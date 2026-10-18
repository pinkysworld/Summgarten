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
var light := Color.WHITE ## colour of the light (dusk / moon), set by the garden
var shadow_dir := 0.0 ## -1..1 shadow leans away from the sun
var raining := false ## the frog loves rain, everyone else looks up
var crouch := 0.0 ## anticipation: squashes down before a hop or a song
var _hat_swing := 0.0 ## follow-through: hats and leaves lag behind and wobble
var _hat_vel := 0.0
var _prev_motion := 0.0
var _idle_in := randf_range(4.0, 9.0)
var _head := Vector2.ZERO ## top of the head in local space (after lean), for the thirst bubble
var shrink := 0.0 ## held down: shrinks and yawns before turning back into a seed
var golden := false ## rare: a golden being with twinkling stars
var thirst := 0.0 ## 0 fresh .. 1 very thirsty: droops and fades until watered
var _thirst_shown := 0.0
var _drops: Array = [] ## [pos, vel, age] water splash

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


func sing(shift: float, note_count := 2) -> void:
	Audio.play(stream, freq, shift)
	sang.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "crouch", 0.6, 0.05)
	tw.tween_property(self, "crouch", 0.0, 0.08)
	tw.parallel().tween_property(self, "sing_amp", 1.0, 0.08)
	tw.tween_property(self, "sing_amp", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	var top: float = -HEIGHTS[species] - 10.0
	for i in note_count:
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
	tw.tween_property(self, "crouch", 1.0, 0.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "crouch", 0.0, 0.08)
	tw.parallel().tween_property(self, "hop", 1.0, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "hop", 0.0, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


## Small idle moments, different for every species (personality).
func _idle_act() -> void:
	if sleeping or grow < 0.9 or sing_amp > 0.05 or _thirst_shown > 0.6:
		return
	var tw := create_tween()
	match species:
		Species.FROG, Species.BIRD, Species.BEETLE: # springy: a little hop
			tw.tween_property(self, "crouch", 0.8, 0.14).set_trans(Tween.TRANS_SINE)
			tw.tween_property(self, "crouch", 0.0, 0.06)
			tw.parallel().tween_property(self, "hop", 0.45 if species == Species.FROG else 0.25, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(self, "hop", 0.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		Species.SNAIL: # shy: ducks down, then peeks out again
			tw.tween_property(self, "crouch", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
			tw.tween_interval(0.8)
			tw.tween_property(self, "crouch", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_: # plants: a happy wiggle
			_hat_vel += 5.0
			tw.tween_property(self, "_bob", 0.6, 0.15)
			tw.tween_property(self, "_bob", 0.0, 0.35).set_trans(Tween.TRANS_BACK)


## A neighbour sang: look at it and bob along a little.
func notice(from: Vector2) -> void:
	if sleeping:
		return
	if species == Species.SNAIL and randf() < 0.5: # shy snail flinches first
		var sh := create_tween()
		sh.tween_property(self, "crouch", 0.7, 0.1)
		sh.tween_property(self, "crouch", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
	_idle_in -= delta
	if _idle_in <= 0.0:
		_idle_in = randf_range(1.5, 3.0) if raining and species == Species.FROG else randf_range(5.0, 11.0)
		_idle_act()
		if raining and species == Species.FROG and not sleeping:
			cheer()
		elif raining and not sleeping:
			_look_target = Vector2(randf_range(-0.3, 0.3), -0.6)
			_look_hold = 1.5
	# follow-through spring for hats and leaves
	var motion := hop * 1.6 + sing_amp * 0.8 + _bob * 0.8 - crouch * 0.6
	if delta > 0.0:
		_hat_vel += (motion - _prev_motion) / delta * 0.9
	_prev_motion = motion
	_hat_vel += (-_hat_swing * 120.0 - _hat_vel * 9.0) * delta
	_hat_swing = clampf(_hat_swing + _hat_vel * delta * 0.06, -0.45, 0.45)
	_thirst_shown = move_toward(_thirst_shown, thirst, delta * 0.8)
	var dry := clampf((_thirst_shown - 0.4) / 0.6, 0.0, 1.0)
	modulate = Color.WHITE.lerp(Color(0.8, 0.76, 0.64), dry * 0.8) * light
	for d in _drops:
		d[2] += delta
		d[0] += d[1] * delta
		d[1].y += 520.0 * delta
	_drops = _drops.filter(func(d): return d[2] < 0.9)
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
	# warm, saturated dark of the fill, pulled toward the plum ink like the model sheets
	return _col(c).darkened(0.55).lerp(INK, 0.35)


## Filled circle with coloured contour.
func _circ(p: Vector2, r: float, c: Color, outline := true) -> void:
	draw_circle(p, r, _col(c))
	if outline:
		draw_arc(p, r, 0, TAU, 40, _ink(c), 4.2, true)


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
		draw_polyline(closed, _ink(c), 4.2, true)


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
	var sl := absf(shadow_dir)
	draw_colored_polygon(_ell_pts(Vector2(shadow_dir * 34 * s, 4), Vector2((62 + sl * 40) * s, 14 * s), 0.0, 24), Color(0.1, 0.05, 0.1, 0.22 - sl * 0.05))
	var sway := sin(_t * (0.6 if sleeping else 1.6)) * 0.045 * (1.0 - _sleep_blend * 0.7)
	var breath := 0.018 * sin(_t * 2.2) * (1.0 - _sleep_blend * 0.3) * (0.6 if not sleeping else 1.4)
	var squash := 1.0 + 0.16 * sing_amp + 0.06 * beat_pulse + breath - 0.2 * crouch
	var droop := clampf((_thirst_shown - 0.4) / 0.6, 0.0, 1.0)
	squash *= 1.0 - droop * 0.16
	var sun_lean := 0.0
	if species == Species.SUNFLOWER and not sleeping:
		sun_lean = clampf((560.0 - global_position.x) / 1600.0, -0.14, 0.14) # follows the sun
	var lean := sun_lean + sway * (1.0 - droop * 0.6) + bow_amt * 0.45 + _look.x * 0.05 + droop * 0.22
	_head = Vector2(0, -hop * 40.0 - _bob * 8.0) + Vector2(0, -HEIGHTS[species] * s * squash).rotated(lean)
	s *= 1.0 - 0.45 * shrink
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
	if golden:
		for k in 4:
			var ang := _t * 0.8 + TAU * k / 4.0
			var tw := 0.5 + 0.5 * sin(_t * 3.0 + k * 1.7)
			_star(_head + Vector2(0, HEIGHTS[species] * 0.35 * s) + Vector2(cos(ang) * 70, sin(ang) * 24) * s, (6.0 + 4.0 * tw) * s, Color(1, 0.86, 0.3, 0.6 + 0.4 * tw))
	if _sleep_blend > 0.5:
		_draw_zzz()
	elif droop > 0.3 and stage >= 2.0:
		_draw_thirst_bubble(droop)
	for d in _drops:
		var al: float = 1.0 - float(d[2]) / 0.9
		_drop(d[0], 7.0, Color(0.55, 0.8, 1.0, al))
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
	# model sheet: pointed lilac cap with gills, cream face, ruffled collar,
	# little lilac dress, clasped hands and two stubby legs
	var cap: Color = PALETTE[Species.MUSHROOM].lightened(0.18)
	var dress := Color("c8b0e6")
	var cream := Color("f8ecd4")
	var droop := _sad()
	# legs and feet
	for side in [-1, 1]:
		_poly(PackedVector2Array([Vector2(side * 7, -26), Vector2(side * 19, -26), Vector2(side * 18, -6), Vector2(side * 8, -6)]), dress.darkened(0.08))
		_ell(Vector2(side * 15, -5), Vector2(13, 6), dress.darkened(0.12))
	# dress: a bell with a rounded hem
	var d := PackedVector2Array()
	d.append(Vector2(-22, -62))
	for i in 13:
		var u := float(i) / 12.0
		d.append(Vector2(lerpf(-42, 42, u), -24 + sin(u * PI) * 4))
	d.append(Vector2(22, -62))
	_poly(d, dress)
	# arms: clasped in front, open wide while singing, hanging when thirsty
	var open := clampf(sing_amp * 2.5, 0.0, 1.0)
	for side in [-1, 1]:
		var sh := Vector2(side * 20, -56)
		var hand := Vector2(side * 7, -34).lerp(Vector2(side * 58, -66), open).lerp(Vector2(side * 22, -32), droop)
		var mid := sh.lerp(hand, 0.5) + Vector2(side * 9, 4 - 10 * open)
		var arm := PackedVector2Array([sh, mid, hand])
		draw_polyline(arm, _ink(dress), 12.0, true)
		draw_polyline(arm, _col(dress), 7.0, true)
		_circ(hand, 6.0, dress)
	# gills under the cap
	var gc := Vector2(0, -118)
	draw_colored_polygon(_ell_pts(gc, Vector2(70, 18), 0.0, 32), _col(cream).darkened(0.04))
	for i in 11:
		var ang := PI * 0.08 + PI * 0.84 * i / 10.0
		var tip := gc + Vector2(-cos(ang) * 62, sin(ang) * 16)
		if absf(tip.x) > 30:
			draw_line(gc + Vector2(-cos(ang) * 30, sin(ang) * 6), tip, _ink(cream), 1.6, true)
	# head with a scalloped collar
	_circ(Vector2(0, -94), 37, cream)
	var col := PackedVector2Array()
	for i in 21:
		var u := float(i) / 20.0
		var x := lerpf(-27, 27, u)
		col.append(Vector2(x, -52 + absf(sin(u * PI * 5.0)) * 6.0))
	col.append(Vector2(22, -62))
	col.append(Vector2(-22, -62))
	_poly(col, cream)
	_face(Vector2(0, -88), 1.05)
	draw_colored_polygon(_ell_pts(Vector2(0, -86), Vector2(4, 2.6), 0.0, 12), _col(cap).darkened(0.1))
	# cap: a soft cone with a slightly rolled rim
	var top := PackedVector2Array()
	for i in 33:
		var t := float(i) / 32.0
		var x := lerpf(-84, 84, t)
		var c := absf(x) / 84.0
		top.append(Vector2(x, -124 - 70 * (1.0 - pow(c, 1.5)) - 6 * (1.0 - c * c)))
	for i in range(31, 0, -1):
		var t := float(i) / 32.0
		top.append(Vector2(lerpf(-84, 84, t), -124 + sin(t * PI) * 8))
	_poly(top, cap)
	for sp in [Vector3(-52, -138, 10), Vector3(-20, -164, 11), Vector3(20, -176, 9), Vector3(46, -150, 12), Vector3(8, -138, 8), Vector3(-70, -126, 6), Vector3(72, -128, 6)]:
		draw_colored_polygon(_ell_pts(Vector2(sp.x, sp.y), Vector2(sp.z * 1.15, sp.z), 0.0, 18), _col(Color("fbf1e2")))


## Arm pose shared by the model sheets: 0 rest, 1 open wide (singing), droops when thirsty.
func _arm_pose(rest: Vector2, open_to: Vector2, hang: Vector2) -> Vector2:
	return rest.lerp(open_to, clampf(sing_amp * 2.5, 0.0, 1.0)).lerp(hang, _sad())


func _limb(from: Vector2, to: Vector2, bend: float, c: Color, w := 7.0, hand := true) -> void:
	var mid := from.lerp(to, 0.5) + (to - from).orthogonal().normalized() * bend
	var pts := PackedVector2Array([from, mid, to])
	draw_polyline(pts, _ink(c), w + 5.0, true)
	draw_polyline(pts, _col(c), w, true)
	if hand:
		_circ(to, w * 0.85, c)


## Two little stem legs with leaf feet, for the flowers.
func _stem_legs(c: Color) -> void:
	for side: float in [-1.0, 1.0]:
		_stem(Vector2(side * 3, -62), Vector2(side * 16, -8), side * 3.0, c, 7.0)
		_ell(Vector2(side * 24, -6), Vector2(14, 6), c)


## Leaf arms: up when singing, hanging when thirsty.
func _leaf_arms(at: Vector2, length: float, c: Color) -> void:
	var o := clampf(sing_amp * 2.5, 0.0, 1.0)
	var d := _sad()
	_leaf(at, lerpf(lerpf(-2.95, -2.4, o), -4.2, d), length, c)
	_leaf(at, lerpf(lerpf(-0.19, -0.75, o), 1.05, d), length, c)


func _draw_pumpkin() -> void:
	var c := PALETTE[Species.PUMPKIN]
	var feet := Color("4a3550")
	for side: float in [-1.0, 1.0]:
		_ell(Vector2(side * 24, -8), Vector2(17, 9), feet)
	# curly stem, tendril and a leaf
	_stem(Vector2(0, -116), Vector2(-4, -150), 5.0, Color("7a5230"), 11.0)
	var curl := PackedVector2Array()
	for i in 24:
		var a := i * 0.42
		curl.append(Vector2(26, -146) + Vector2(cos(a), sin(a)) * (10 - i * 0.35))
	draw_polyline(curl, _ink(Color("6b8e3a")), 3.0, true)
	draw_line(Vector2(2, -128), Vector2(18, -142), _ink(Color("6b8e3a")), 3.0, true)
	_leaf(Vector2(30, -140), 0.7, 26, Color("6fa040"))
	# lobed body
	for x: float in [-34.0, 34.0]:
		_ell(Vector2(x, -64), Vector2(38, 58), c.darkened(0.06))
	_ell(Vector2(0, -66), Vector2(44, 62), c)
	for x: float in [-24.0, 24.0, -50.0, 50.0]:
		var line := PackedVector2Array()
		for i in 9:
			var u := float(i) / 8.0
			line.append(Vector2(x * (0.55 + 0.45 * sin(u * PI)), lerpf(-120, -10, u)))
		draw_polyline(line, _col(c.darkened(0.22)), 2.5, true)
	_shine(Vector2(-20, -104), Vector2(12, 6))
	for side: float in [-1.0, 1.0]:
		_limb(Vector2(side * 40, -70), _arm_pose(Vector2(side * 50, -44), Vector2(side * 80, -104), Vector2(side * 54, -26)), side * -6.0, c, 9.0)
	_face(Vector2(0, -70), 1.1)


func _draw_snail() -> void:
	var body := Color("bfe6c4")
	var shell := PALETTE[Species.SNAIL]
	var head := Vector2(-36, -100)
	# eye stalks, the eyes sit on the tips
	var tips := []
	for side: float in [-1.0, 1.0]:
		var tip := head + Vector2(side * 16 + 4, -78 + side * 8) + Vector2(sin(_t * 3.0 + side) * 3, 0)
		tip.y += _sad() * 18
		_limb(head + Vector2(side * 10, -26), tip, side * 4.0, body, 6.0, false)
		_circ(tip, 13, body)
		tips.append(tip)
	# neck and wavy foot
	_ell(head + Vector2(0, 30), Vector2(30, 66), body)
	var foot := PackedVector2Array()
	for i in 25:
		var u := float(i) / 24.0
		foot.append(Vector2(lerpf(-80, 86, u), -4 + sin(u * TAU * 3.0) * 2.5))
	foot.append(Vector2(84, -18))
	foot.append(Vector2(-10, -26))
	foot.append(Vector2(-60, -22))
	_poly(foot, body)
	draw_colored_polygon(_ell_pts(Vector2(-36, -30), Vector2(26, 12), 0.0, 16), _col(body))
	for sp: Vector2 in [Vector2(-14, -62), Vector2(-22, -48), Vector2(-10, -40)]:
		draw_colored_polygon(_ell_pts(sp, Vector2(4, 3), 0.4, 10), _col(body.darkened(0.18)))
	# spiral shell
	var sc := Vector2(30, -78)
	_circ(sc, 54, shell)
	_shade(sc + Vector2(16, 20), Vector2(30, 26), shell)
	var spiral := PackedVector2Array()
	for i in 56:
		var a := i * 0.2
		spiral.append(sc + Vector2(cos(a), sin(a)) * (3 + i * 0.85))
	draw_polyline(spiral, _ink(shell), 4.0, true)
	_shine(sc + Vector2(-24, -28), Vector2(12, 7))
	_eyes(tips, 1.15)
	_cheeks(head + Vector2(0, -2), 0.75)
	_mouth(head + Vector2(0, 4), 0.8)


func _draw_beetle() -> void:
	var c := PALETTE[Species.BEETLE]
	var dark := Color("3d3050")
	for side: float in [-1.0, 1.0]:
		_limb(Vector2(side * 20, -24), Vector2(side * 24, -6), 0.0, dark, 9.0, false)
		_ell(Vector2(side * 28, -6), Vector2(15, 7), dark)
		_limb(Vector2(side * 52, -86), _arm_pose(Vector2(side * 66, -56), Vector2(side * 84, -112), Vector2(side * 60, -36)), side * -6.0, dark, 7.0)
		var tip := Vector2(side * 30, -180 + sin(_t * 3.0 + side) * 5)
		tip.y += _sad() * 16
		tip.x += _sad() * side * 14
		_limb(Vector2(side * 14, -140), tip, side * -5.0, dark, 3.0, false)
		_circ(tip, 9, Color("ffc93c"))
	_ell(Vector2(0, -80), Vector2(58, 70), c)
	# head band and wing case seam
	var band := PackedVector2Array()
	for i in 17:
		var u := float(i) / 16.0
		band.append(Vector2(lerpf(-56, 56, u), -98 + sin(u * PI) * 10))
	draw_polyline(band, _ink(c), 3.0, true)
	draw_line(Vector2(0, -88), Vector2(0, -12), _ink(c), 3.0, true)
	for sp: Vector2 in [Vector2(-30, -70), Vector2(-22, -40), Vector2(30, -66), Vector2(22, -38), Vector2(-40, -48), Vector2(40, -46)]:
		draw_colored_polygon(_ell_pts(sp, Vector2(4, 7), 0.0, 10), _col(c.darkened(0.15)))
	_shine(Vector2(-26, -132), Vector2(14, 7))
	_face(Vector2(0, -116), 1.15)


func _draw_bird() -> void:
	var c := PALETTE[Species.BIRD]
	var dark := Color("3d3050")
	for side: float in [-1.0, 1.0]:
		var foot := Vector2(side * 18, -2)
		draw_line(Vector2(side * 14, -26), foot, _col(dark), 4.0, true)
		for t: float in [-1.0, 0.0, 1.0]:
			draw_line(foot, foot + Vector2(t * 9 + side * 3, 3), _col(dark), 3.0, true)
	# crest
	for k in 3:
		_ell(Vector2(-6 + k * 9, -150 - (6 if k == 1 else 0)), Vector2(6, 16), c.darkened(0.08), -0.5 + k * 0.45)
	_ell(Vector2(0, -84), Vector2(56, 66), c)
	_ell(Vector2(4, -52), Vector2(36, 34), Color("fbf3e2"), 0.0, false)
	for sp: Vector2 in [Vector2(-8, -60), Vector2(10, -56), Vector2(0, -42), Vector2(18, -40), Vector2(-14, -40)]:
		draw_colored_polygon(_ell_pts(sp, Vector2(2.2, 4), 0.0, 8), _col(c.lightened(0.1)))
	# wings flap open while singing
	var o := clampf(sing_amp * 2.5, 0.0, 1.0)
	for side: float in [-1.0, 1.0]:
		var rot := side * (0.35 + 0.9 * o - _sad() * 0.25) + sin(_t * 2.0) * 0.06
		_ell(Vector2(side * (50 + 10 * o), -76 - 10 * o), Vector2(14, 34), c.darkened(0.1), rot)
	_shine(Vector2(-24, -124), Vector2(14, 7))
	var eye_y := -112.0
	_eyes([Vector2(-20, eye_y), Vector2(20, eye_y)], 1.1)
	_cheeks(Vector2(0, -96), 1.0)
	var gape := 3.0 + 10.0 * sing_amp + 6.0 * yawn_amt
	_poly(PackedVector2Array([Vector2(-10, -100), Vector2(10, -100), Vector2(0, -88)]), Color("ffa63c"))
	if gape > 4.0:
		_poly(PackedVector2Array([Vector2(-8, -96 + gape * 0.4), Vector2(8, -96 + gape * 0.4), Vector2(0, -88 + gape)]), Color("f08a2c"))


func _draw_frog() -> void:
	var c := PALETTE[Species.FROG]
	# hind legs and toes
	for side: float in [-1.0, 1.0]:
		_ell(Vector2(side * 64, -28), Vector2(26, 26), c.darkened(0.04))
		_web_foot(Vector2(side * 76, -6), side, c)
	_ell(Vector2(0, -62), Vector2(72, 58), c)
	_ell(Vector2(0, -44), Vector2(44, 36), Color("f3e6b0"), 0.0, false)
	for side: float in [-1.0, 1.0]:
		_web_foot(Vector2(side * 30, -6), side, c)
		draw_colored_polygon(_ell_pts(Vector2(side * 52, -52), Vector2(5, 4), 0.0, 10), _col(c.darkened(0.15)))
	for x: float in [-40.0, 40.0]:
		_circ(Vector2(x, -108), 26, c)
	_shine(Vector2(-48, -88), Vector2(14, 7))
	_eyes([Vector2(-40, -110), Vector2(40, -110)], 1.4)
	_cheeks(Vector2(0, -78), 2.0)
	_mouth(Vector2(0, -76), 1.8, true)


## Three-toed webbed foot fanning outward.
func _web_foot(at: Vector2, side: float, c: Color) -> void:
	for t in 3:
		var d := Vector2.from_angle(lerpf(-0.6, 0.3, t / 2.0)) * Vector2(side, 1)
		_ell(at + d * 13, Vector2(7, 4.5), c, d.angle())
	_ell(at, Vector2(11, 7), c)


## Look toward a point in the garden (the finger, a sound).
func look_toward(p: Vector2) -> void:
	if sleeping:
		return
	var d := (p - global_position - Vector2(0, -height() * 0.6)) / 400.0
	_look_target = d.limit_length(1.0)
	_look_hold = 1.2


func _draw_daisy() -> void:
	var c := PALETTE[Species.DAISY]
	var green := Color("5fa14a")
	_stem_legs(green)
	_stem(Vector2(0, -60), Vector2(0, -124), 2.0, green, 8.0)
	_leaf_arms(Vector2(0, -72), 48, Color("6cae58"))
	var center := Vector2(0, -150)
	var spin := _t * 0.2 * (1.0 - _sleep_blend)
	var wilt := _sad() * 0.35
	for i in 10:
		var a := TAU * i / 10.0 + spin
		var p := center + Vector2(cos(a), sin(a) + wilt) * 46
		_ell(p, Vector2(26, 15), c, a)
	_circ(center, 36, Color("fbe3b0"))
	for i in 7:
		draw_circle(center + Vector2(-14 + i * 5, -22 + (i % 2) * 3), 1.2, _col(Color("e8b080")))
	_face(center + Vector2(0, 4), 0.95)


func _draw_bell() -> void:
	var c := PALETTE[Species.BELL]
	var green := Color("5fa14a")
	_stem_legs(green)
	_stem(Vector2(0, -60), Vector2(0, -130), -3.0, green, 8.0)
	_leaf_arms(Vector2(0, -76), 50, Color("6cae58"))
	# the bell head: dome, flaring sides, five curled tips
	var top := Vector2(0, -214)
	var hang := sin(_t * 1.5) * 0.06 + sing_amp * 0.2 + _sad() * 0.12
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
		pts.append(Vector2(mx, 112))
		pts.append(Vector2(lerpf(mx, x1, 0.5) - 4, 104))
		if tip < 4:
			pts.append(Vector2(x1, 98))
	for i in range(6, -1, -1):
		var u := float(i) / 6.0
		pts.append(Vector2(-40 - 18 * u * u, 34 + 58 * u))
	for i in pts.size():
		pts[i] = top + pts[i].rotated(hang)
	_poly(pts, c)
	_shine(top + Vector2(-20, 30).rotated(hang), Vector2(10, 7))
	# calyx and a curled stem tip
	var calyx := PackedVector2Array()
	for i in 11:
		var a := PI + PI * i / 10.0
		var r := 26.0 if i % 2 == 0 else 13.0
		calyx.append(top + Vector2(cos(a) * r, 12 + sin(a) * r * 0.55).rotated(hang))
	_poly(calyx, green)
	var curl := PackedVector2Array()
	for i in 20:
		var a := PI - i * 0.32
		curl.append(top + (Vector2(10, -10) + Vector2(cos(a), sin(a)) * (12 - i * 0.45)).rotated(hang))
	draw_polyline(curl, _ink(green), 7.0, true)
	draw_polyline(curl, _col(green), 4.0, true)
	_face(top + Vector2(0, 66).rotated(hang), 0.95)


func _draw_sunflower() -> void:
	var c := PALETTE[Species.SUNFLOWER]
	var green := Color("5fa14a")
	_stem_legs(green)
	_stem(Vector2(0, -60), Vector2(0, -140), -4.0, green, 9.0)
	_leaf_arms(Vector2(0, -82), 72, Color("6cae58"))
	var center := Vector2(0, -178)
	var spin := _t * 0.12 * (1.0 - _sleep_blend)
	var wilt := _sad() * 0.4
	for ring in 2:
		for i in 14:
			var a := TAU * (i + ring * 0.5) / 14.0 + spin
			var col := c.darkened(0.1) if ring == 0 else c
			var dir := Vector2(cos(a), sin(a) + wilt).normalized()
			var base := center + dir * 40
			var side := dir.orthogonal() * 9
			_poly(PackedVector2Array([base + side, base + dir * 18 + side * 1.1, base + dir * 34, base + dir * 18 - side * 1.1, base - side]), col)
	_circ(center, 44, Color("9a6634"))
	for i in 16:
		var a := i * 2.4
		var r := 10.0 + sqrt(float(i)) * 7.0
		draw_circle(center + Vector2(cos(a), sin(a)) * r, 1.8, _col(Color("6e4420")))
	_face(center + Vector2(0, 4), 1.1)


## Accessory anchor per species: (x, y) = centre of the hat brim, z = scale.
## Always well above the eyes so nothing covers a face.
const HAT := [Vector3(0, -186, 0.9), Vector3(-8, -140, 0.9), Vector3(-36, -134, 0.62), Vector3(0, -144, 0.95),
	Vector3(0, -146, 0.9), Vector3(-40, -130, 0.6), Vector3(0, -192, 0.82), Vector3(0, -218, 0.8), Vector3(0, -222, 0.95)]
const HAT_TILT := [-0.12, 0.1, 0.08, -0.1, 0.12, -0.2, 0.1, -0.08, 0.12]


func _draw_accessory() -> void:
	if season == 1:
		return
	var h: Vector3 = HAT[species]
	var at := Vector2(h.x, h.y)
	var k := h.z
	var rot: float = HAT_TILT[species] + _hat_swing
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
		elif _sad() > 0.35:
			# tired, droopy eyes: lower half open, heavy lid, sad brow
			var half := PackedVector2Array()
			for j in 11:
				half.append(e + Vector2.from_angle(PI * j / 10.0) * 9 * k)
			draw_colored_polygon(half, Color.WHITE)
			draw_circle(e + Vector2(0, 4 * k), 4.2 * k, INK)
			var out := signf(e.x) if e.x != 0.0 else 1.0
			draw_line(e + Vector2(-10 * k, 0), e + Vector2(10 * k, 0), INK, 3.0)
			draw_line(e + Vector2(-9 * out * k, -13 * k), e + Vector2(7 * out * k, -9 * k), INK, 2.5)
		else:
			var pupil: Vector2 = e + Vector2(0, 1) + _look * 3.5 * k
			if species == Species.MUSHROOM:
				# soft glossy button eyes with a little star of light
				var ec: Vector2 = e + Vector2(0, 1) + _look * 1.5 * k
				draw_colored_polygon(_ell_pts(ec, Vector2(7.5, 9) * k, 0.0, 20), INK)
				_star(ec + Vector2(-2.2, -3.0) * k, 4.2 * k, Color.WHITE)
				draw_circle(ec + Vector2(2.6, 3.6) * k, 1.4 * k, Color(1, 1, 1, 0.8))
			else:
				draw_circle(e, 10 * k, Color.WHITE)
				draw_arc(e, 10 * k, 0, TAU, 20, INK, 2.6, true)
				pupil = e + Vector2(0, 1) + _look * 3.2 * k
				draw_circle(pupil, 6.6 * k, INK)
				draw_circle(pupil + Vector2(-2.2, -2.4) * k, 2.3 * k, Color.WHITE)


## 0..1 how visibly thirsty (only when not happy or singing).
func _sad() -> float:
	if joy > 0.1 or sing_amp > 0.08:
		return 0.0
	return clampf((_thirst_shown - 0.4) / 0.6, 0.0, 1.0)


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
	elif _sad() > 0.35:
		draw_arc(m + Vector2(0, 8 * k), w, PI + 0.55, TAU - 0.55, 12, INK, 3.0, true)
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


## A big pulsing bubble with a water drop, pinned to the head with a
## speech-bubble tail so it is clear who is thirsty.
func _draw_thirst_bubble(k: float) -> void:
	var a := clampf(k * 1.6, 0.0, 1.0)
	var inv := Vector2(1.0 / maxf(scale.x, 0.01), 1.0 / maxf(scale.y, 0.01)) # same on-screen size for every being
	var pulse := 1.0 + 0.1 * (0.5 + 0.5 * sin(_t * 4.0))
	var r := 30.0 * pulse * inv.x
	var head := _head + Vector2(0, -(18.0 if season != 1 else 4.0))
	var c := head + Vector2(30, -50) * inv + Vector2(0, sin(_t * 2.0) * 3.0)
	var tip := head + Vector2(4, -4) * inv
	var side := (tip - c).normalized().orthogonal() * 11.0 * inv.x
	var edge := c + (tip - c).normalized() * (r - 4 * inv.x)
	draw_colored_polygon(PackedVector2Array([edge + side * 1.2, tip, edge - side * 1.2]), Color(INK, 0.6 * a))
	draw_circle(c, r + 4 * inv.x, Color(INK, 0.6 * a))
	draw_colored_polygon(PackedVector2Array([edge + side, tip.lerp(edge, 0.15), edge - side]), Color(1, 1, 1, a))
	draw_circle(c, r, Color(1, 1, 1, a))
	draw_circle(c, r - 5 * inv.x, Color(Color("d8eeff"), a))
	_drop(c + Vector2(0, 6) * inv, 13.0 * pulse * inv.x, Color(Color("3d8fe0"), a))


func _drop(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c, r, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.92, -r * 0.4), c + Vector2(0, -r * 2.1), c + Vector2(r * 0.92, -r * 0.4)]), col)
	draw_circle(c + Vector2(-r * 0.35, -r * 0.1), r * 0.25, Color(1, 1, 1, col.a * 0.7))


## Watered: splash, a happy hop and a little growth spurt.
## A friend answered: little hearts and a happy hop.
func love() -> void:
	cheer()
	celebrate_hop(0.0)
	for i in 6:
		_sparkles.append([Vector2(randf_range(-30, 30), -height() / scale.y * 0.8), Vector2(randf_range(-60, 60), randf_range(-160, -90)), 0.0, Color("ff7aa8")])


func water() -> void:
	thirst = 0.0
	for i in 18:
		var a := randf_range(-PI * 0.9, -PI * 0.1)
		_drops.append([Vector2(randf_range(-30, 30), -HEIGHTS[species] * 0.6), Vector2(cos(a), sin(a)) * randf_range(80, 220), 0.0])
	cheer()
	celebrate_hop(0.15)
