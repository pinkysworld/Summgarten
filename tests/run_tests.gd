extends SceneTree
## Headless tests: godot --headless --path . -s tests/run_tests.gd

var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)

func sine(freq: float, amp: float, rate := 44100, secs := 1.0) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(rate * secs))
	for i in a.size():
		a[i] = sin(TAU * freq * i / rate) * amp
	return a

func _init() -> void:
	var SL = load("res://scripts/sound_lab.gd")
	check(SL.analyze(sine(300, 0.005), 44100).is_empty(), "silence detected")
	for f in [150.0, 300.0, 600.0]:
		var est: float = SL.estimate_freq(sine(f, 0.5), 44100)
		check(absf(est - f) / f < 0.05, "freq %d estimated as %.1f" % [f, est])
	check(SL.analyze(sine(150, 0.5), 44100).pitch == 0, "150 Hz -> low")
	check(SL.analyze(sine(300, 0.5), 44100).pitch == 1, "300 Hz -> mid")
	check(SL.analyze(sine(600, 0.5), 44100).pitch == 2, "600 Hz -> high")
	check(SL.analyze(sine(300, 0.04), 44100).loud == 0, "quiet -> small")
	check(SL.analyze(sine(300, 0.6), 44100).loud == 2, "loud -> large")
	check(absf(SL.snap_to_pentatonic(270.0) - 261.63) < 0.1, "270 Hz snaps to C4")
	check(absf(SL.snap_to_pentatonic(340.0) - 329.63) < 0.1, "340 Hz snaps to E4")
	check(absf(SL.snap_to_pentatonic(360.0) - 392.0) < 0.1, "360 Hz snaps to G4 (no F)")
	var pitches := {}
	for i in SL.PRESET_COUNT:
		var p: Dictionary = SL.preset(i)
		check(p.samples.size() > 1000, "preset %d has audio" % i)
		pitches[[p.pitch, p.loud]] = true
	check(pitches.size() == 9, "presets cover all 9 beings (%d)" % pitches.size())
	var wav: AudioStreamWAV = SL.make_wav(sine(300, 0.5, 22050, 0.5), 22050)
	check(wav.data.size() == 22050, "wav has 16-bit data")
	print("FAILURES: %d" % failures)
	quit(1 if failures else 0)
