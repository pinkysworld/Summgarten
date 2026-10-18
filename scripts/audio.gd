extends Node
## Autoload "Audio": microphone capture, garden playback with reverb.

const RECORD_SECONDS := 2.5
const VOICES := 10

var level := 0.0 ## live input level 0..1 while recording
var recording := false

var _capture: AudioEffectCapture
var _mic_player: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: Array[AudioStreamPlayer] = []
var _next_music := 0
var _ambient: Array[AudioStreamPlayer] = []
var _next_amb := 0
var _rain: AudioStreamPlayer
var _buffer := PackedFloat32Array()


func _ready() -> void:
	var rec := AudioServer.bus_count
	AudioServer.add_bus(rec)
	AudioServer.set_bus_name(rec, "Record")
	AudioServer.set_bus_mute(rec, true) # never echo the mic to the speakers
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 1.0
	AudioServer.add_bus_effect(rec, _capture)

	var garden := AudioServer.bus_count
	AudioServer.add_bus(garden)
	AudioServer.set_bus_name(garden, "Garden")
	AudioServer.set_bus_send(garden, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.6
	reverb.damping = 0.6
	reverb.wet = 0.22
	reverb.dry = 0.9
	AudioServer.add_bus_effect(garden, reverb)
	AudioServer.add_bus_effect(garden, AudioEffectHardLimiter.new())

	var music := AudioServer.bus_count
	AudioServer.add_bus(music)
	AudioServer.set_bus_name(music, "Music")
	AudioServer.set_bus_send(music, "Garden")
	AudioServer.set_bus_volume_db(music, -11.0)
	for i in 6:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Music"
		add_child(mp)
		_music.append(mp)

	var amb := AudioServer.bus_count
	AudioServer.add_bus(amb)
	AudioServer.set_bus_name(amb, "Ambient")
	AudioServer.set_bus_send(amb, "Master")
	AudioServer.set_bus_volume_db(amb, -14.0)
	for i in 3:
		var ap := AudioStreamPlayer.new()
		ap.bus = "Ambient"
		add_child(ap)
		_ambient.append(ap)
	_rain = AudioStreamPlayer.new()
	_rain.bus = "Ambient"
	var rain_wav := SoundLab.make_wav(SoundLab.ambient(2), 22050)
	rain_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	rain_wav.loop_end = rain_wav.data.size() / 2
	_rain.stream = rain_wav
	add_child(_rain)

	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = "Record"
	add_child(_mic_player)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Garden"
		p.volume_db = -3.0 # headroom: several voices often overlap
		add_child(p)
		_players.append(p)


func set_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(linear, 0.0001)))


func start_recording() -> void:
	_buffer = PackedFloat32Array()
	# Keep the microphone stream running once started: stopping and restarting
	# AudioStreamMicrophone often yields only silence afterwards (macOS).
	if not _mic_player.playing:
		_mic_player.play()
	_capture.clear_buffer()
	recording = true


## Stops and returns the raw mono samples at mix rate.
func stop_recording() -> PackedFloat32Array:
	_drain()
	recording = false
	level = 0.0
	if _buffer.is_empty():
		# the stream delivered nothing (iOS can drop it after playback): restart it next time
		_mic_player.stop()
	return _buffer


## Fully releases the microphone (parents switched it off).
func release_mic() -> void:
	recording = false
	_mic_player.stop()


func mix_rate() -> int:
	return int(AudioServer.get_mix_rate())


func _process(_delta: float) -> void:
	if recording:
		_drain()
	elif _mic_player.playing:
		_capture.clear_buffer() # discard everything outside a recording


func _drain() -> void:
	var frames := _capture.get_frames_available()
	if frames <= 0:
		level = lerpf(level, 0.0, 0.2)
		return
	var buf := _capture.get_buffer(frames)
	var peak := 0.0
	for f in buf:
		var m := (f.x + f.y) * 0.5
		_buffer.append(m)
		peak = maxf(peak, absf(m))
	level = lerpf(level, clampf(peak * 3.0, 0.0, 1.0), 0.5)


func play(stream: AudioStream, freq: float, shift: float) -> void:
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = SoundLab.pitch_scale_for(freq, shift)
	p.play()


## Accompaniment / UI sounds: already in tune, only transposed by `shift`.
func play_music(stream: AudioStream, shift: float, volume_db := 0.0) -> void:
	var p := _music[_next_music]
	_next_music = (_next_music + 1) % _music.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pow(2.0, shift / 12.0)
	p.play()


func play_ambient(stream: AudioStream, pitch := 1.0, volume_db := 0.0) -> void:
	var p := _ambient[_next_amb]
	_next_amb = (_next_amb + 1) % _ambient.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func set_rain(on: bool) -> void:
	if on and not _rain.playing:
		_rain.play()
	elif not on:
		_rain.stop()
