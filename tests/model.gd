extends Node2D
## Model sheet: one species in four moods next to its reference.
## godot --path . --windowed res://tests/model.tscn -- <outdir> <species>

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var sp := int(args[1]) if args.size() > 1 else 0
	RenderingServer.set_default_clear_color(Color("fbf6ee"))
	var cs := []
	for i in 4:
		var c: Node2D = load("res://scripts/creature.gd").new()
		c.setup(sp / 3, sp % 3, null, 261.0)
		c.stage = 2.0
		c.grow = 1.0
		c.position = Vector2(170 + i * 310, 560)
		c.scale = Vector2(1.5, 1.5)
		add_child(c)
		cs.append(c)
	cs[1].sing_amp = 0.6
	cs[2].sleeping = true
	cs[2]._sleep_blend = 1.0
	cs[3].thirst = 1.0
	cs[3]._thirst_shown = 1.0
	for c in cs:
		c.set_process(false)
		c._idle_in = 999.0
	cs[1].set_process(false)
	await get_tree().create_timer(0.3).timeout
	for c in cs:
		c.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out.path_join("model_%d.png" % sp))
	get_tree().quit()
