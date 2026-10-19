extends Control
## Wordless "turn the device" hint while a phone or tablet is held upright.
## Sits below the studio intro (layer 95), which plays in any orientation.

const SKY := Color(0.53, 0.78, 0.93)
const INK := Color("2f2a4a")

var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP # the garden waits underneath
	visible = false


func _process(delta: float) -> void:
	var sz := get_viewport_rect().size
	var upright := sz.y > sz.x
	if upright != visible:
		visible = upright
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), SKY)
	var c := sz / 2.0
	var u := minf(sz.x, sz.y) / 720.0
	# a device turning from upright to sideways, resting, then again
	var k := clampf(fmod(_t, 2.6) / 1.2, 0.0, 1.0)
	var ang := PI / 2.0 * (k * k * (3.0 - 2.0 * k))
	var w := 170.0 * u
	var h := 260.0 * u
	draw_set_transform(c, ang, Vector2.ONE)
	var r := Rect2(-w / 2.0, -h / 2.0, w, h)
	draw_rect(r.grow(10.0 * u), INK)
	draw_rect(r, Color.WHITE)
	draw_rect(r.grow(-14.0 * u), Color(0.62, 0.85, 0.55))
	draw_circle(Vector2(0, h / 2.0 - 2.0 * u), 5.0 * u, INK)
	draw_set_transform(Vector2.ZERO)
	# curved arrow showing the turn
	var rad := 200.0 * u
	var pts := PackedVector2Array()
	for i in 17:
		var a := -PI * 0.85 + i / 16.0 * PI * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	draw_polyline(pts, Color(1, 1, 1, 0.9), 12.0 * u, true)
	var tip := pts[pts.size() - 1]
	var dir := (tip - pts[pts.size() - 2]).normalized()
	var n := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip + dir * 26.0 * u, tip + n * 20.0 * u, tip - n * 20.0 * u]), Color(1, 1, 1, 0.9))
