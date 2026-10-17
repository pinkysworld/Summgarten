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
static func analyze(samples: PackedFloat32Array, rate: float) -> Dictionary:
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
	var out := PackedFloat32Array()
	out.resize(active.size())
	var gain := 0.9 / peak
	var fade := mini(int(rate * 0.01), active.size() / 2)
	for i in active.size():
		var env := 1.0
		if i < fade:
			env = float(i) / fade
		elif i > active.size() - fade:
			env = float(active.size() - i) / fade
		out[i] = active[i] * gain * env

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
