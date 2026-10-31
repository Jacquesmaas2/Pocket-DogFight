extends Node
## Autoload: central audio integration point.
## Looks for res://assets/audio/<id>.ogg|.wav. When a file is missing a procedurally
## synthesized effect is used so the game never fails on a missing optional asset.

const SOUND_IDS: PackedStringArray = [
	"engine", "laser", "laser_impact", "missile_launch", "missile_warning", "explosion",
	"collision", "powerup", "countdown", "countdown_go", "win", "loss", "ui_click", "respawn",
]

const POOL_SIZE := 12
const MIX_RATE := 32000

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _engine_players: Dictionary = {} # Node -> AudioStreamPlayer2D


func _ready() -> void:
	for id in SOUND_IDS:
		_streams[id] = _load_or_generate(id)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)


func play(id: String, volume_db: float = 0.0, pitch_variation: float = 0.08) -> void:
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
			p.play()
			return


func play_at(id: String, position: Vector2, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.bus = "SFX"
	p.stream = stream
	p.volume_db = volume_db
	p.global_position = position
	p.max_distance = 2500.0
	p.pitch_scale = randf_range(0.92, 1.08)
	p.finished.connect(p.queue_free)
	get_tree().current_scene.add_child(p)
	p.play()


func set_engine(owner_node: Node2D, active: bool, intensity: float = 1.0) -> void:
	var p: AudioStreamPlayer2D = _engine_players.get(owner_node)
	if p == null or not is_instance_valid(p):
		if not active:
			return
		p = AudioStreamPlayer2D.new()
		p.bus = "SFX"
		p.stream = _streams.get("engine")
		p.max_distance = 1800.0
		p.volume_db = -14.0
		owner_node.add_child(p)
		owner_node.tree_exiting.connect(func() -> void: _engine_players.erase(owner_node))
		_engine_players[owner_node] = p
	if active:
		p.pitch_scale = lerpf(0.8, 1.4, clampf(intensity, 0.0, 1.0))
		if not p.playing:
			p.play()
	elif p.playing:
		p.stop()


func _load_or_generate(id: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://assets/audio/%s.%s" % [id, ext]
		if ResourceLoader.exists(path):
			var s := load(path) as AudioStream
			if s != null:
				return s
	return _generate(id)


func _generate(id: String) -> AudioStreamWAV:
	var synth := _Synth.new(MIX_RATE, hash(id))
	match id:
		"engine": _gen_engine(synth)
		"laser": _gen_laser(synth)
		"laser_impact": _gen_impact(synth)
		"missile_launch": _gen_missile_launch(synth)
		"missile_warning": _gen_warning(synth)
		"explosion": _gen_explosion(synth)
		"collision": _gen_collision(synth)
		"powerup": _gen_arpeggio(synth, [523.25, 659.25, 783.99, 1046.5], 0.09, 0.25)
		"countdown": _gen_blip(synth, 660.0, 0.12)
		"countdown_go": _gen_chord(synth, [659.25, 987.77, 1318.5], 0.45)
		"win": _gen_fanfare(synth)
		"loss": _gen_loss(synth)
		"ui_click": _gen_blip(synth, 1800.0, 0.035)
		"respawn": _gen_respawn(synth)
		_: _gen_blip(synth, 440.0, 0.1)
	return synth.to_wav(id == "engine")


# ---------------------------------------------------------------- sound designs
func _gen_engine(s: _Synth) -> void:
	s.begin(0.5)
	for i in s.frames:
		var t := s.t(i)
		var rumble := s.lowpass(s.noise(), 180.0) * 0.9
		var sub := sin(TAU * 56.0 * t) * 0.5 + sin(TAU * 112.0 * t + 0.4 * sin(TAU * 6.0 * t)) * 0.2
		s.put(i, (rumble + sub) * 0.5)


func _gen_laser(s: _Synth) -> void:
	s.begin(0.16)
	var phase := 0.0
	for i in s.frames:
		var p := s.p(i)
		var f := lerpf(2200.0, 380.0, pow(p, 0.6))
		phase += f / s.rate
		var v := s.square(phase) * 0.35 + sin(TAU * phase) * 0.65
		s.put(i, v * s.env(p, 0.005, 2.2))


func _gen_impact(s: _Synth) -> void:
	s.begin(0.14)
	for i in s.frames:
		var p := s.p(i)
		var n := s.lowpass(s.noise(), lerpf(5000.0, 400.0, p))
		var tone := sin(TAU * lerpf(900.0, 200.0, p) * s.t(i)) * (1.0 - p)
		s.put(i, (n * 0.8 + tone * 0.5) * s.env(p, 0.002, 3.0))


func _gen_missile_launch(s: _Synth) -> void:
	s.begin(0.6)
	var phase := 0.0
	for i in s.frames:
		var p := s.p(i)
		var whoosh := s.lowpass(s.noise(), lerpf(300.0, 2600.0, pow(p, 0.5))) * (0.6 + 0.4 * p)
		phase += lerpf(70.0, 210.0, p) / s.rate
		var roar := s.square(phase) * 0.25
		s.put(i, (whoosh + roar) * s.env(p, 0.08, 1.6))


func _gen_warning(s: _Synth) -> void:
	s.begin(0.32)
	for i in s.frames:
		var t := s.t(i)
		var hi := fmod(t, 0.16) < 0.08
		var f := 1320.0 if hi else 990.0
		var gate := 1.0 if fmod(t, 0.08) < 0.065 else 0.0
		s.put(i, (sin(TAU * f * t) * 0.7 + sin(TAU * f * 2.0 * t) * 0.15) * gate * 0.8)


func _gen_explosion(s: _Synth) -> void:
	s.begin(1.1)
	for i in s.frames:
		var p := s.p(i)
		var t := s.t(i)
		var boom := s.lowpass(s.noise(), lerpf(3500.0, 120.0, pow(p, 0.35))) * 1.4
		var sub := sin(TAU * lerpf(90.0, 38.0, p) * t) * (1.0 - p) * 0.9
		var crackle := s.noise() * 0.15 * maxf(0.0, 1.0 - p * 3.0)
		s.put(i, s.drive(boom + sub + crackle, 1.8) * s.env(p, 0.004, 2.6))


func _gen_collision(s: _Synth) -> void:
	s.begin(0.28)
	for i in s.frames:
		var p := s.p(i)
		var t := s.t(i)
		var clank := sin(TAU * 311.0 * t) * 0.5 + sin(TAU * 467.0 * t) * 0.35 + sin(TAU * 1247.0 * t) * 0.2
		var thud := s.lowpass(s.noise(), 600.0) * maxf(0.0, 1.0 - p * 6.0) * 1.5
		s.put(i, (clank * s.env(p, 0.001, 4.0) + thud) * 0.8)


func _gen_arpeggio(s: _Synth, notes: Array, step: float, tail: float) -> void:
	s.begin(step * notes.size() + tail)
	for i in s.frames:
		var t := s.t(i)
		var v := 0.0
		for n in notes.size():
			var start := n * step
			if t < start:
				continue
			var lt := t - start
			var f: float = notes[n]
			v += (sin(TAU * f * lt) * 0.6 + s.tri(f * lt) * 0.4) * exp(-lt * 7.0)
		s.put(i, v * 0.55)


func _gen_blip(s: _Synth, freq: float, dur: float) -> void:
	s.begin(dur)
	for i in s.frames:
		var p := s.p(i)
		s.put(i, (sin(TAU * freq * s.t(i)) + 0.3 * sin(TAU * freq * 2.0 * s.t(i))) * s.env(p, 0.003, 3.0) * 0.7)


func _gen_chord(s: _Synth, freqs: Array, dur: float) -> void:
	s.begin(dur)
	for i in s.frames:
		var p := s.p(i)
		var v := 0.0
		for f in freqs:
			v += sin(TAU * f * s.t(i)) + 0.25 * s.tri(f * s.t(i))
		s.put(i, v / freqs.size() * s.env(p, 0.01, 1.8) * 0.8)


func _gen_fanfare(s: _Synth) -> void:
	var notes := [523.25, 659.25, 783.99, 1046.5, 1318.5]
	var step := 0.14
	s.begin(step * notes.size() + 0.7)
	for i in s.frames:
		var t := s.t(i)
		var v := 0.0
		for n in notes.size():
			var start := n * step
			if t < start:
				continue
			var lt := t - start
			var f: float = notes[n]
			var sustain := 1.0 if n == notes.size() - 1 else 0.35
			v += (s.square(f * lt) * 0.25 + sin(TAU * f * lt) * 0.6) * exp(-lt * (2.0 if n == notes.size() - 1 else 9.0)) * sustain
		s.put(i, v * 0.6)


func _gen_loss(s: _Synth) -> void:
	s.begin(0.9)
	var phase := 0.0
	for i in s.frames:
		var p := s.p(i)
		phase += lerpf(330.0, 140.0, p) / s.rate
		var wob := 1.0 + 0.02 * sin(TAU * 7.0 * s.t(i))
		var v := s.square(phase * wob) * 0.35 + s.tri(phase) * 0.5
		s.put(i, s.lowpass(v, 1200.0) * s.env(p, 0.02, 1.2) * 0.9)


func _gen_respawn(s: _Synth) -> void:
	s.begin(0.35)
	var phase := 0.0
	for i in s.frames:
		var p := s.p(i)
		phase += lerpf(300.0, 1100.0, p) / s.rate
		var shimmer := sin(TAU * phase * 2.0) * 0.25 * p
		s.put(i, (sin(TAU * phase) * 0.7 + shimmer) * s.env(p, 0.02, 1.4) * 0.7)


## Tiny offline synth: mono float buffer, one-pole lowpass, basic waveforms, soft clip.
class _Synth:
	var rate: float
	var frames: int = 0
	var buf: PackedFloat32Array
	var _rng := RandomNumberGenerator.new()
	var _lp := 0.0

	func _init(mix_rate: int, seed_value: int) -> void:
		rate = float(mix_rate)
		_rng.seed = seed_value

	func begin(duration: float) -> void:
		frames = int(rate * duration)
		buf = PackedFloat32Array()
		buf.resize(frames)

	func t(i: int) -> float:
		return float(i) / rate

	func p(i: int) -> float:
		return float(i) / maxf(frames - 1, 1.0)

	func put(i: int, v: float) -> void:
		buf[i] = v

	func noise() -> float:
		return _rng.randf_range(-1.0, 1.0)

	func square(phase: float) -> float:
		return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0

	func tri(phase: float) -> float:
		return 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0

	func lowpass(x: float, cutoff: float) -> float:
		var a := 1.0 - exp(-TAU * cutoff / rate)
		_lp += a * (x - _lp)
		return _lp

	## Attack then exponential decay; `p` is normalized progress.
	func env(p: float, attack: float, decay: float) -> float:
		var a := clampf(p / maxf(attack, 0.0001), 0.0, 1.0)
		return a * exp(-p * decay) * (1.0 - pow(p, 8.0))

	func drive(x: float, amount: float) -> float:
		return tanh(x * amount) / tanh(amount)

	func to_wav(looping: bool) -> AudioStreamWAV:
		var data := PackedByteArray()
		data.resize(frames * 2)
		var peak := 0.001
		for v in buf:
			peak = maxf(peak, absf(v))
		var gain := 0.9 / peak
		for i in frames:
			data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(rate)
		wav.stereo = false
		wav.data = data
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
		wav.loop_end = frames
		return wav
