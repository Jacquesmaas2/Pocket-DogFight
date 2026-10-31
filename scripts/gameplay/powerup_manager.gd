class_name PowerUpManager
extends Node2D
## Server decides when a power-up spawns and who collects it; clients only render.

const POWERUP_SCENE := preload("res://scenes/powerups/powerup.tscn")
const TYPES: PackedStringArray = ["shield", "rapid_fire", "missile", "boost"]

var _respawn: Dictionary = {} # slot -> seconds
var _live: Dictionary = {} # slot -> PowerUp
var enabled: bool = true


func server_reset() -> void:
	if not Net.is_server():
		return
	_clear.rpc()
	_clear()
	_respawn.clear()
	if not enabled:
		return
	var spots := MatchManager.instance.arena.powerup_spots()
	for i in spots.size():
		server_spawn(i, TYPES[i % TYPES.size()])


func server_spawn(slot: int, type: String, at: Vector2 = Vector2.INF) -> void:
	var pos := at
	if pos == Vector2.INF:
		var spots := MatchManager.instance.arena.powerup_spots()
		if slot >= spots.size():
			return
		pos = spots[slot].global_position
	_spawn.rpc(slot, type, pos)
	_spawn(slot, type, pos)


@rpc("authority", "reliable", "call_remote")
func _spawn(slot: int, type: String, pos: Vector2) -> void:
	if _live.has(slot) and is_instance_valid(_live[slot]):
		_live[slot].queue_free()
	var pu: PowerUp = POWERUP_SCENE.instantiate()
	pu.slot = slot
	pu.type = type
	pu.global_position = pos
	add_child(pu)
	_live[slot] = pu


@rpc("authority", "reliable", "call_remote")
func _collected(slot: int, uid: int) -> void:
	var pu: PowerUp = _live.get(slot)
	if pu != null and is_instance_valid(pu):
		VFX.explosion(pu.global_position, pu.type_color(), 0.5)
		pu.queue_free()
	_live.erase(slot)
	var ship := MatchManager.instance.ships.find_ship(uid)
	if ship != null:
		Audio.play_at("powerup", ship.global_position)
		if ship.peer_id == Net.local_id():
			MatchManager.instance.hud.call("show_pickup", pu.type if pu != null else "")


@rpc("authority", "reliable", "call_remote")
func _clear() -> void:
	for pu in _live.values():
		if is_instance_valid(pu):
			pu.queue_free()
	_live.clear()


## Server only, called by PowerUp when a ship overlaps.
func server_try_collect(pu: PowerUp, ship: Ship) -> void:
	if not Net.is_server() or not ship.alive or not _live.has(pu.slot):
		return
	var dur := Config.match_config.powerup_duration
	match pu.type:
		"shield": ship.shield_time = dur
		"rapid_fire": ship.rapid_fire_time = dur
		"boost": ship.boost_time = dur
		"missile": ship.missile_ammo = mini(ship.missile_ammo + 2, ship.stats.missile_ammo + 2)
		"overcharge": ship.overcharge_time = dur
	ship.server_push_state()
	_collected.rpc(pu.slot, ship.unique_id())
	_collected(pu.slot, ship.unique_id())
	if pu.type != "core" and pu.slot < 100:
		_respawn[pu.slot] = Config.match_config.powerup_respawn_delay
	if MatchManager.instance.story:
		MatchManager.instance.mission_runner.call("on_powerup_collected", pu.type, ship)


func _physics_process(delta: float) -> void:
	if not Net.is_server():
		return
	for slot in _respawn.keys():
		_respawn[slot] -= delta
		if _respawn[slot] <= 0.0:
			_respawn.erase(slot)
			server_spawn(slot, TYPES[randi() % TYPES.size()])


func server_sync_to(peer: int) -> void:
	for slot in _live:
		var pu: PowerUp = _live[slot]
		if is_instance_valid(pu):
			_spawn.rpc_id(peer, slot, pu.type, pu.global_position)
