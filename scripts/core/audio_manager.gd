extends Node
## Autoload: central audio integration point.
## Looks for res://assets/audio/<id>.ogg|.wav. When a file is missing a tiny generated
## placeholder tone is used so the game never fails on a missing optional asset.

const SOUND_IDS: PackedStringArray = [
	"engine", "laser", "laser_impact", "missile_launch", "missile_warning", "explosion",
	"collision", "powerup", "countdown", "countdown_go", "win", "loss", "ui_click", "respawn",
]

# Placeholder tone definitions: [frequency_hz, duration_s, waveform]  waveform: 0=sine 1=square 2=noise
const PLACEHOLDERS := {
	"engine": [70.0, 0.25, 1], "laser": [880.0, 0.08, 1], "laser_impact": [220.0, 0.06, 2],
	"missile_launch": [160.0, 0.3, 2], "missile_warning": [1200.0, 0.12, 0], "explosion": [60.0, 0.5, 2],
	"collision": [120.0, 0.12, 2], "powerup": [1400.0, 0.18, 0], "countdown": [660.0, 0.1, 0],
	"countdown_go": [990.0, 0.25, 0], "win": [1320.0, 0.5, 0], "loss": [110.0, 0.6, 1],
	"ui_click": [1000.0, 0.03, 1], "respawn": [500.0, 0.15, 0],
}

const POOL_SIZE := 12
const MIX_RATE := 22050

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
	var def: Array = PLACEHOLDERS.get(id, [440.0, 0.1, 0])
	var freq: float = def[0]
	var duration: float = def[1]
	var wave: int = def[2]
	var frames := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for i in frames:
		var t := float(i) / MIX_RATE
		var env := 1.0 - float(i) / frames
		var v := 0.0
		match wave:
			0: v = sin(TAU * freq * t)
			1: v = 1.0 if fmod(freq * t, 1.0) < 0.5 else -1.0
			_: v = rng.randf_range(-1.0, 1.0) * (0.4 + 0.6 * sin(TAU * freq * t))
		var sample := int(clampf(v * env * 0.45, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if id == "engine" else AudioStreamWAV.LOOP_DISABLED
	wav.loop_end = frames
	return wav
