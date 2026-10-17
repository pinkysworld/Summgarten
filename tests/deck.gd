extends Node
## Steam Deck check: 1280x800, gamepad only. Plants a seed and opens the parent gate with the pad.
## godot --path . --resolution 1280x800 res://tests/deck.tscn -- <outdir>

func _pad(button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().create_timer(0.25).timeout


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._clear_garden()
	main.settings.mic = false
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	await _pad(JOY_BUTTON_A) # plant via pad
	await _pad(JOY_BUTTON_DPAD_LEFT)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	await get_tree().create_timer(2.6).timeout
	get_viewport().get_texture().get_image().save_png(out.path_join("deck_garden.png"))
	print("DECK beds=", main._creature_count(), " focus=", main._focus, " size=", get_viewport().get_visible_rect().size)
	await _pad(JOY_BUTTON_START)
	await get_tree().create_timer(0.3).timeout
	var focused := get_viewport().gui_get_focus_owner()
	print("DECK gate_focus=", focused.get_class() if focused else "none")
	get_viewport().get_texture().get_image().save_png(out.path_join("deck_gate.png"))
	main._clear_garden()
	get_tree().quit()
