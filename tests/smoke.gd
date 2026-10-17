extends Node
## Plays a short round without microphone and saves screenshots.
## godot --path . res://tests/smoke.tscn -- <outdir>

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() else "user://"
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	main._clear_garden()
	main.settings.mic = false
	for i in [0, 1, 2, 4, 5]:
		main._plant(i)
		await get_tree().create_timer(0.3).timeout
	await _shot(out + "/growing.png")
	await get_tree().create_timer(2.5).timeout
	for c in main.beds:
		if c:
			c.cheer()
			break
	await get_tree().create_timer(0.15).timeout
	await _shot(out + "/day.png")
	main._set_weather(main.Weather.RAIN)
	main._concert()
	await get_tree().create_timer(0.8).timeout
	await _shot(out + "/rain_concert.png")
	while main.state == main.State.CONCERT and main._confetti.is_empty():
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await _shot(out + "/fireworks.png")
	while main.state == main.State.CONCERT:
		await get_tree().process_frame
	main._open_parent_gate()
	await get_tree().create_timer(0.3).timeout
	await _shot(out + "/parent_gate.png")
	var wav_path: String = main.export_concert()
	print("EXPORT ", wav_path, " ", FileAccess.get_file_as_bytes(wav_path).size() if wav_path else 0)
	if wav_path:
		DirAccess.remove_absolute(wav_path)
	main._panel._show_settings()
	await get_tree().create_timer(0.3).timeout
	await _shot(out + "/parents.png")
	main.settings.lang = "zh_CN"
	main._apply_language()
	main._panel.settings = main.settings
	main._panel._show_settings()
	await get_tree().create_timer(0.3).timeout
	await _shot(out + "/parents_zh.png")
	main.settings.lang = ""
	main._apply_language()
	main._panel.queue_free()
	main.state = main.State.DAY
	main.day_time = main.day_length()
	await get_tree().create_timer(3.0).timeout
	await _shot(out + "/night.png")
	main._plant(3)
	main.settings.mic = true
	main._wake_up()
	main._plant(3)
	await get_tree().create_timer(1.0).timeout
	await _shot(out + "/recording.png")
	print("SMOKE_OK beds=", main._creature_count(), " state=", main.state)
	main._clear_garden()
	get_tree().quit()

func _shot(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
