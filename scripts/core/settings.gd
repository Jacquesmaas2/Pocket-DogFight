extends Node
## Autoload: persisted local settings (user://settings.cfg).

signal changed

const PATH := "user://settings.cfg"

var player_name: String = "Pilot"
var master_volume: float = 1.0
var music_volume: float = 0.7
var sfx_volume: float = 1.0
var screen_shake: float = 1.0 # 0 = off, 0.5 = reduced, 1 = full
var force_touch_controls: bool = false
var last_address: String = "127.0.0.1"
var preferred_ship: String = "syntiq"


func _ready() -> void:
	load_settings()
	apply_audio()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	player_name = str(cfg.get_value("player", "name", player_name)).strip_edges().substr(0, 16)
	if player_name.is_empty():
		player_name = "Pilot"
	preferred_ship = str(cfg.get_value("player", "ship", preferred_ship))
	master_volume = clampf(float(cfg.get_value("audio", "master", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	screen_shake = clampf(float(cfg.get_value("video", "screen_shake", screen_shake)), 0.0, 1.0)
	force_touch_controls = bool(cfg.get_value("input", "force_touch", force_touch_controls))
	last_address = str(cfg.get_value("network", "last_address", last_address))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("player", "name", player_name)
	cfg.set_value("player", "ship", preferred_ship)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.set_value("input", "force_touch", force_touch_controls)
	cfg.set_value("network", "last_address", last_address)
	cfg.save(PATH)
	apply_audio()
	changed.emit()


func apply_audio() -> void:
	_set_bus("Master", master_volume)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func touch_controls_enabled() -> bool:
	return force_touch_controls or DisplayServer.is_touchscreen_available()
