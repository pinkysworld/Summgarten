extends Node
## Plays the echo game in tap mode: one wrong tap, then correct answers.
## godot --path . res://tests/echo.tscn -- <outdir>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._clear_garden()
	main.settings.mic = false
	for i in [0, 1, 4, 5]:
		main._grow_preset(i)
	await get_tree().create_timer(3.0).timeout
	main._echo_game()
	var shots := 0
	var wrong_done := false
	var rounds := 0
	var t := 0.0
	while main.state == main.State.ECHO and t < 60.0:
		await get_tree().process_frame
		t += get_process_delta_time()
		if shots == 0 and main._echo_seq.size() > 0 and not main._echo_waiting:
			await get_tree().create_timer(0.3).timeout
			get_viewport().get_texture().get_image().save_png(out.path_join("echo_phrase.png"))
			shots = 1
		if main._echo_waiting:
			if shots == 1:
				get_viewport().get_texture().get_image().save_png(out.path_join("echo_wait.png"))
				shots = 2
			var target = main._echo_seq[main._echo_pos]
			if not wrong_done:
				for c in main.beds:
					if c and c != target:
						target = c
						break
				wrong_done = true
			var tap: Vector2 = target.global_position + Vector2(0, -target.height() * 0.5)
			main._echo_tap(tap)
			if main._echo_result == 1:
				rounds += 1
			await get_tree().create_timer(0.3).timeout
	print("ECHO_DONE rounds=", rounds, " state=", main.state, " t=", snapped(t, 0.1))
	main._clear_garden()
	get_tree().quit()
