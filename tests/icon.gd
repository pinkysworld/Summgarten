extends Node2D
## App icon candidates drawn with the game's own beings and paper shader.
## godot --path . --windowed --resolution 1024x1024 res://tests/icon.tscn -- <outdir> <name> <species>[,<species>...]

const INK := Color("2b2340")
var _beings: Array = []


func _ready() -> void:
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var args := OS.get_cmdline_user_args()
	var list: PackedStringArray = args[2].split(",")
	var n := list.size()
	for k in n:
		var sp := int(list[k])
		var c: Node2D = load("res://scripts/creature.gd").new()
		c.setup(sp / 3, sp % 3, null, 261.0)
		c.stage = 2.0
		c.grow = 1.0
		c.sing_amp = 0.7 if k == n / 2 else 0.35
		c._idle_in = 999.0
		var sc := 4.3 if n == 1 else (3.0 if k == n / 2 else 2.2)
		var x := 512.0 if n == 1 else 512.0 + (k - n / 2) * 360.0
		c.position = Vector2(x, 1040 if n == 1 else (1000 if k == n / 2 else 990))
		c.scale = Vector2(sc, sc)
		c.z_index = 2 if k == n / 2 else 1
		add_child(c)
		_beings.append(c)
	var paper := CanvasLayer.new()
	paper.layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/paper.gdshader")
	mat.set_shader_parameter("vignette", 0.5)
	rect.material = mat
	paper.add_child(rect)
	add_child(paper)
	await get_tree().create_timer(0.5).timeout
	for c in _beings:
		c.set_process(false)
		c.queue_redraw()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(args[0].path_join(args[1] + ".png"))
	get_tree().quit()


func _draw() -> void:
	# sky
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1024, 0), Vector2(1024, 760), Vector2(0, 760)]),
		PackedColorArray([Color("5cb6f0"), Color("5cb6f0"), Color("bfe6fb"), Color("bfe6fb")]))
	draw_circle(Vector2(820, 190), 150, Color(1, 0.95, 0.6, 0.25))
	draw_circle(Vector2(820, 190), 90, Color("ffd84a"))
	# hills
	for h in [[Color("9fd486"), 640.0, 0.7], [Color("7cc86a"), 720.0, 1.6]]:
		var pts := PackedVector2Array()
		for i in 33:
			var x := i * 32.0
			pts.append(Vector2(x, float(h[1]) - sin(x / 1024.0 * PI * float(h[2]) + 0.6) * 70.0))
		pts.append(Vector2(1024, 1024))
		pts.append(Vector2(0, 1024))
		draw_colored_polygon(pts, h[0])
		draw_polyline(pts.slice(0, 33), INK.lerp(h[0], 0.55), 6.0, true)
	# notes
	for nt in [[Vector2(250, 250), 1.6, Color("ff8fb8")], [Vector2(160, 420), 1.15, Color("9b6bd6")], [Vector2(780, 400), 1.25, Color("ff9a3c")]]:
		_note(nt[0], nt[1], nt[2])


func _note(c: Vector2, s: float, col: Color) -> void:
	draw_set_transform(c, -0.15, Vector2.ONE * s * 2.2)
	draw_circle(Vector2.ZERO, 15, INK)
	draw_line(Vector2(11, 0), Vector2(11, -46), INK, 9.0)
	draw_line(Vector2(11, -46), Vector2(30, -32), INK, 9.0)
	draw_circle(Vector2.ZERO, 11, col)
	draw_line(Vector2(11, -2), Vector2(11, -44), col, 4.0)
	draw_line(Vector2(11, -44), Vector2(28, -32), col, 4.0)
	draw_set_transform(Vector2.ZERO)
