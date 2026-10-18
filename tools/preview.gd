extends Node
## App Store preview: a scripted ~29 s walk through the garden, played like a child would.
## godot --path . --resolution 1600x1200 --fixed-fps 30 --write-movie out.avi res://tools/preview.tscn

const LENGTH := 29.0
var main


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.screenshot_mode = true
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main._clear_garden()
	main.settings.mic = false
	main.set_season(1)
	get_tree().create_timer(LENGTH).timeout.connect(get_tree().quit)
	await _wait(1.0)
	# a child plants: every tap grows a singing being
	for i in [2, 0, 4, 1, 5]:
		main._press_at(main.BED_POSITIONS[i])
		await _wait(1.1)
	await _wait(0.6)
	main._press_at(main.beds[2].global_position + Vector2(0, -60))
	main._hold_t = -1.0 # a tap, not a long press (that would uproot it)
	await _wait(1.2)
	main._press_at(main.BED_POSITIONS[3])
	await _wait(1.4)
	# sunshine, then the conductor's concert with fireworks
	main._press_at(main.BTN_SUN)
	await _wait(1.6)
	main._press_at(main.BTN_CONDUCTOR)
	await _wait(8.5)
	# rain and the rainbow after it
	main._press_at(main.BTN_RAIN)
	await _wait(3.0)
	main._set_weather(main.Weather.NONE)
	main._rain_amount = 0.0
	create_tween().tween_property(main, "_rainbow", 1.0, 0.8)
	await _wait(2.5)
	# evening: everyone falls asleep
	main._go_to_sleep()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
