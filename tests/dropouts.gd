extends SceneTree
## godot --headless --path . -s tests/dropouts.gd
func _init() -> void:
	var x := PackedFloat32Array()
	for i in 4800:
		x.append(sin(i * 0.05) * 0.5)
	for i in range(1000, 1128):
		x[i] = 0.0
	for i in range(3000, 3007):
		x[i] = 0.0
	var y := SoundLab.remove_dropouts(x)
	var zeros := 0
	var jump := 0.0
	for i in y.size():
		if y[i] == 0.0: zeros += 1
		if i > 0: jump = maxf(jump, absf(y[i] - y[i - 1]))
	print("in ", x.size(), " out ", y.size(), " zeros ", zeros, " max step ", snappedf(jump, 0.001))
	assert(y.size() == x.size() - 128 - 7 - 32)
	assert(jump < 0.2)
	var r := SoundLab.analyze(x, 48000.0)
	print("analyze ok ", not r.is_empty())
	quit()
