class_name SoundLab
## Pure sound helpers: analysis, pentatonic snapping, synthesis, WAV building.
## Kept free of scene state so it can be unit-tested headless.

const BASE_FREQ := 261.63 # C4
const PENTA := [0, 2, 4, 7, 9] # major pentatonic in semitones
const SILENCE_PEAK := 0.02
const PRESET_COUNT := 12

enum Pitch { LOW, MID, HIGH }
enum Loud { QUIET, MEDIUM, LOUD }


## Analyses mono samples. Returns {} for silence, otherwise
## {samples, freq, pitch, loud}. `samples` is trimmed, normalised and faded.
## Removes rumble, hiss and the noise floor between sounds (microphones of
## tablets are noisy, and normalising would make that crackle audibly).
static func clean(x: PackedFloat32Array, rate: float) -> PackedFloat32Array:
	var y := PackedFloat32Array()
	y.resize(x.size())
	var hp := exp(-TAU * 90.0 / rate) # high-pass ~90 Hz
	var lp := 1.0 - exp(-TAU * 7000.0 / rate) # low-pass ~7 kHz
	var px := 0.0
	var py := 0.0
	var l := 0.0
	for i in x.size():
		py = hp * (py + x[i] - px)
		px = x[i]
		l += lp * (py - l)
		y[i] = l
	# noise floor from the quietest 10 ms blocks, then a soft gate
	var block := maxi(1, int(rate * 0.01))
	var levels := []
	for b in range(0, y.size() - block, block):
		var e := 0.0
		for i in range(b, b + block):
			e = maxf(e, absf(y[i]))
		levels.append(e)
	if levels.size() < 4:
		return y
	var sorted := levels.duplicate()
	sorted.sort()
	var floor_l: float = sorted[int(sorted.size() * 0.1)]
	# Per-sample gain smoothing: a fast-chattering gate on a voice sounds gritty,
	# so it opens in ~5 ms and closes over ~80 ms.
	var att := 1.0 / (rate * 0.005)
	var rel := 1.0 / (rate * 0.08)
	var g := 1.0
	for bi in levels.size():
		var target := clampf((float(levels[bi]) - floor_l * 1.3) / maxf(floor_l * 3.0, 0.0001), 0.0, 1.0)
		target = 0.15 + 0.85 * target # duck noise, never cut to hard silence
		for i in range(bi * block, (bi + 1) * block):
			g += (target - g) * (att if target > g else rel)
			y[i] *= g
	return y


## When the microphone delivers late (iPad), the engine fills the gap with exact
## zeros. Those holes click hard after normalising, so they are cut out and the
## two sides are joined with a short crossfade.
static func remove_dropouts(x: PackedFloat32Array) -> PackedFloat32Array:
	const MIN_RUN := 4
	const XF := 16
	var out := PackedFloat32Array()
	var i := 0
	var n := x.size()
	while i < n:
		if x[i] == 0.0:
			var j := i
			while j < n and x[j] == 0.0:
				j += 1
			if j - i >= MIN_RUN and i > 0 and j < n:
				# join: fade the tail of what we have into the samples after the hole
				var m := mini(XF, mini(out.size(), n - j))
				for k in m:
					var a := float(k + 1) / float(m + 1)
					var idx := out.size() - m + k
					out[idx] = out[idx] * (1.0 - a) + x[j + k] * a
				i = j + m
				continue
			if j - i >= MIN_RUN:
				i = j # leading or trailing silence from the engine
				continue
			for k in range(i, j):
				out.append(0.0)
			i = j
			continue
		out.append(x[i])
		i += 1
	return out


## Close to the phone a loud child hits full scale: the flat-topped runs are
## rebuilt with a smooth curve through their neighbours instead of the harsh edge.
static func declip(x: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	if peak < 0.95:
		return x
	var y := x.duplicate()
	var lim := peak * 0.97
	var i := 1
	while i < y.size() - 1:
		if absf(y[i]) < lim:
			i += 1
			continue
		var a := i - 1
		var b := i
		while b < y.size() - 1 and absf(y[b]) >= lim:
			b += 1
		var n := b - a
		if n > 1:
			var sgn := signf(y[i])
			var lift := lim * (0.12 + 0.02 * minf(n, 20))
			for k in range(1, n):
				var u := float(k) / n
				y[a + k] = lerpf(y[a], y[b], u) + sgn * lift * sin(u * PI)
		i = b
	# the rebuilt peaks can exceed 1.0; scale back into range
	var m := 0.0
	for v in y:
		m = maxf(m, absf(v))
	if m > 1.0:
		for k in y.size():
			y[k] /= m
	return y


## Gentle saturation above 0.5 instead of a hard edge at 1.0.
static func soft_clip(v: float) -> float:
	var a := absf(v)
	if a <= 0.5:
		return v
	return signf(v) * (0.5 + 0.5 * tanh((a - 0.5) * 2.0))


static func analyze(samples: PackedFloat32Array, rate: float) -> Dictionary:
	samples = remove_dropouts(samples)
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	if peak < SILENCE_PEAK:
		return {}

	# Trim leading/trailing quiet parts.
	var gate := peak * 0.1
	var first := 0
	var last := samples.size() - 1
	while first < last and absf(samples[first]) < gate:
		first += 1
	while last > first and absf(samples[last]) < gate:
		last -= 1
	var pad := int(rate * 0.03)
	first = maxi(0, first - pad)
	last = mini(samples.size() - 1, last + pad)
	var active := samples.slice(first, last + 1)

	var sum_sq := 0.0
	for s in active:
		sum_sq += s * s
	var rms := sqrt(sum_sq / maxf(1.0, active.size()))

	var freq := estimate_freq(active, rate)
	var out := clean(declip(active, peak), rate)
	var opeak := 0.0
	for v in out:
		opeak = maxf(opeak, absf(v))
	# normalise with headroom (several beings sing at once), and never pump
	# quiet room noise up into a hiss
	var gain := minf(0.6 / maxf(opeak, 0.0001), 4.0)
	var fade := mini(int(rate * 0.025), out.size() / 2)
	for i in out.size():
		var env := 1.0
		if i < fade:
			env = float(i) / fade
		elif i > out.size() - fade:
			env = float(out.size() - i) / fade
		out[i] = soft_clip(out[i] * gain * env)

	return {
		"samples": out,
		"freq": freq,
		"pitch": pitch_class(freq),
		"loud": loud_class(rms),
	}


## Fundamental estimate via autocorrelation on a downsampled window around
## the loudest part; falls back to zero-crossing rate for noisy sounds.
static func estimate_freq(samples: PackedFloat32Array, rate: float) -> float:
	var step := maxi(1, int(rate / 11025.0))
	var sr := rate / step
	var ds := PackedFloat32Array()
	for i in range(0, samples.size(), step):
		ds.append(samples[i])
	if ds.size() < 64:
		return BASE_FREQ

	var win := mini(1024, ds.size())
	var best_start := 0
	var best_energy := -1.0
	var hop := maxi(1, win / 2)
	for start in range(0, ds.size() - win + 1, hop):
		var e := 0.0
		for i in range(start, start + win, 4):
			e += ds[i] * ds[i]
		if e > best_energy:
			best_energy = e
			best_start = start

	var min_lag := int(sr / 1000.0)
	var max_lag := mini(int(sr / 80.0), win / 2)
	var energy := 0.0
	for i in win:
		var v := ds[best_start + i]
		energy += v * v
	if energy <= 0.0:
		return BASE_FREQ

	var best_lag := 0
	var best_corr := 0.0
	var corrs := {}
	for lag in range(min_lag, max_lag + 1):
		var c := 0.0
		for i in range(0, win - lag):
			c += ds[best_start + i] * ds[best_start + i + lag]
		c /= energy
		corrs[lag] = c
		if c > best_corr:
			best_corr = c
			best_lag = lag
	# Prefer the shortest lag that is nearly as good (avoids octave errors).
	for lag in range(min_lag, best_lag):
		if corrs[lag] > best_corr * 0.9 and corrs.get(lag - 1, 0.0) < corrs[lag] and corrs.get(lag + 1, 0.0) <= corrs[lag]:
			best_lag = lag
			break

	if best_corr > 0.3 and best_lag > 0:
		return sr / best_lag

	var crossings := 0
	for i in range(1, ds.size()):
		if (ds[i - 1] < 0.0) != (ds[i] < 0.0):
			crossings += 1
	return clampf(crossings * sr / (2.0 * ds.size()), 80.0, 2000.0)


static func pitch_class(freq: float) -> int:
	if freq < 240.0:
		return Pitch.LOW
	if freq < 400.0:
		return Pitch.MID
	return Pitch.HIGH


static func loud_class(rms: float) -> int:
	if rms < 0.05:
		return Loud.QUIET
	if rms < 0.15:
		return Loud.MEDIUM
	return Loud.LOUD


## Nearest frequency on the C major pentatonic scale.
static func snap_to_pentatonic(freq: float) -> float:
	if freq <= 0.0:
		return BASE_FREQ
	var semis := 12.0 * log(freq / BASE_FREQ) / log(2.0)
	var best: float = 0.0
	var best_dist := INF
	var octave := floori(semis / 12.0)
	for o in range(octave - 1, octave + 2):
		for p in PENTA:
			var cand: float = o * 12 + p
			var d := absf(cand - semis)
			if d < best_dist:
				best_dist = d
				best = cand
	return BASE_FREQ * pow(2.0, best / 12.0)


## Pitch scale that moves `freq` onto the scale, then transposes by `shift` semitones.
static func pitch_scale_for(freq: float, shift: float) -> float:
	var ratio := snap_to_pentatonic(freq) / maxf(freq, 1.0)
	return clampf(ratio * pow(2.0, shift / 12.0), 0.25, 4.0)


static func make_wav(samples: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


## Species index (pitch * 3 + loud) a preset grows into, without synthesising it.
static func preset_species(index: int) -> int:
	var notes := [-12, -8, -5, -3, 0, 2, 4, 7, 9, 12, 14, 16]
	var freq := BASE_FREQ * pow(2.0, notes[index % PRESET_COUNT] / 12.0)
	return pitch_class(freq) * 3 + index % 3


## Twelve friendly built-in sounds for playing without a microphone.
## Returns {samples, freq, pitch, loud}.
static func preset(index: int, rate: int = 22050) -> Dictionary:
	var notes := [-12, -8, -5, -3, 0, 2, 4, 7, 9, 12, 14, 16]
	var semis: int = notes[index % PRESET_COUNT]
	var freq := BASE_FREQ * pow(2.0, semis / 12.0)
	var timbre := index % 4
	var length := 0.7
	var n := int(rate * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = index
	var phase := 0.0
	for i in n:
		var t := float(i) / rate
		var env := minf(1.0, t / 0.02) * exp(-t * 4.0)
		var f := freq
		var v := 0.0
		match timbre:
			0: # bell
				phase += TAU * f / rate
				v = sin(phase) * 0.7 + sin(phase * 2.76) * 0.2 * exp(-t * 8.0)
			1: # bird: vibrato chirp
				f = freq * (1.0 + 0.04 * sin(TAU * 7.0 * t)) * (1.0 + 0.15 * exp(-t * 10.0))
				phase += TAU * f / rate
				v = sin(phase) * 0.8
			2: # soft quack: rounded square
				phase += TAU * f / rate
				v = tanh(sin(phase) * 3.0) * 0.45 + sin(phase * 2.0) * 0.1
				env *= 1.0 - 0.5 * t
			3: # wooden knock with a pitched body
				phase += TAU * f / rate
				v = sin(phase) * 0.6 + rng.randf_range(-1.0, 1.0) * 0.4 * exp(-t * 40.0)
				env = minf(1.0, t / 0.005) * exp(-t * 7.0)
		out[i] = v * env * 0.9
	return {
		"samples": out,
		"freq": freq,
		"pitch": pitch_class(freq),
		"loud": index % 3,
	}


## Soft accompaniment voices: 0 = warm bass, 1 = music-box pluck, 2 = tap "plop".
static func instrument(kind: int, freq: float, rate: int = 22050) -> PackedFloat32Array:
	var length: float = [1.2, 0.9, 0.18][kind]
	var n := int(rate * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		match kind:
			0:
				phase += TAU * freq / rate
				v = (sin(phase) + 0.25 * sin(phase * 2.0)) * minf(1.0, t / 0.03) * exp(-t * 2.2) * 0.8
			1:
				phase += TAU * freq / rate
				v = (sin(phase) + 0.3 * sin(phase * 3.0) * exp(-t * 6.0)) * minf(1.0, t / 0.004) * exp(-t * 4.5) * 0.5
			2:
				var f := freq * (1.0 + 1.5 * exp(-t * 30.0))
				phase += TAU * f / rate
				v = sin(phase) * minf(1.0, t / 0.002) * exp(-t * 25.0) * 0.7
		out[i] = v
	return out


## Ambience: 0 = bird chirp, 1 = cricket, 2 = rain (seamless loop), 3 = yawn.
static func ambient(kind: int, rate: int = 22050, seed_value: int = 1) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var length: float = [0.5, 0.6, 2.0, 1.3][kind]
	var n := int(rate * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		match kind:
			0:
				# two quick rising chirps
				var local := fmod(t, 0.22)
				var f := 2600.0 + 1800.0 * local / 0.22
				phase += TAU * f / rate
				v = sin(phase) * sin(PI * clampf(local / 0.16, 0.0, 1.0)) * (1.0 if t < 0.44 else 0.0) * 0.4
			1:
				# cricket: pulsed high tone
				phase += TAU * 4200.0 / rate
				var pulse := 1.0 if fmod(t, 0.05) < 0.025 else 0.0
				v = sin(phase) * pulse * sin(PI * t / length) * 0.18
			2:
				# soft rain: low-passed noise, crossfaded ends for looping
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.25)
				lp2 = lerpf(lp2, lp, 0.5)
				v = lp2 * 0.5
				if rng.randf() < 0.0015:
					v += 0.4
			3:
				# yawn: falling "aah" with two formants
				var f := lerpf(330.0, 170.0, t / length)
				phase += TAU * f / rate
				var env := sin(PI * t / length)
				v = (sin(phase) * 0.6 + sin(phase * 3.0) * 0.25 + sin(phase * 5.0) * 0.1) * env * env * 0.5
		out[i] = v
	if kind == 2:
		var xf := int(rate * 0.2)
		for i in xf:
			var w := float(i) / xf
			out[i] = out[i] * w + out[n - xf + i] * (1.0 - w)
		out.resize(n - xf)
	return out
