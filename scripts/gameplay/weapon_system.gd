class_name WeaponSystem
extends Node
## Per-ship weapon handling. Owner predicts cooldown for responsiveness;
## the server validates every fire request before spawning a projectile.

signal cooldown_changed(primary_ratio: float)

var _primary_cd: float = 0.0
var _secondary_cd: float = 0.0
var _server_primary_cd: float = 0.0
var _server_secondary_cd: float = 0.0

@onready var ship: Ship = get_parent()


func _process(delta: float) -> void:
	_primary_cd = maxf(_primary_cd - delta, 0.0)
	_secondary_cd = maxf(_secondary_cd - delta, 0.0)
	_server_primary_cd = maxf(_server_primary_cd - delta, 0.0)
	_server_secondary_cd = maxf(_server_secondary_cd - delta, 0.0)


func reset() -> void:
	_primary_cd = 0.0
	_secondary_cd = 0.0
	_server_primary_cd = 0.0
	_server_secondary_cd = 0.0


func primary_cooldown() -> float:
	var base := Config.laser.cooldown
	if ship.rapid_fire_time > 0.0:
		base *= 0.45
	if ship.overcharge_time > 0.0:
		base *= 0.6
	return base


func handle_input(inp: ShipInput) -> void:
	if inp.fire_primary and _primary_cd <= 0.0:
		_primary_cd = primary_cooldown()
		_request_fire("laser")
	if inp.fire_secondary and _secondary_cd <= 0.0 and ship.missile_ammo > 0:
		_secondary_cd = Config.missile.cooldown
		_request_fire("missile")


func _request_fire(weapon: String) -> void:
	var muzzle := ship.global_position + ship.forward() * 24.0
	if Net.is_server():
		server_fire(weapon, muzzle, ship.rotation)
	else:
		_rpc_request_fire.rpc_id(1, weapon, muzzle, ship.rotation)


@rpc("any_peer", "reliable")
func _rpc_request_fire(weapon: String, muzzle: Vector2, rot: float) -> void:
	if not Net.is_server():
		return
	if multiplayer.get_remote_sender_id() != ship.peer_id:
		return
	# Tolerate owner-side latency but reject teleported muzzles.
	if muzzle.distance_to(ship.global_position) > 220.0:
		muzzle = ship.global_position + Vector2.RIGHT.rotated(rot) * 24.0
	server_fire(weapon, muzzle, rot)


## Server only: validates and spawns.
func server_fire(weapon: String, muzzle: Vector2, rot: float) -> void:
	if not Net.is_server() or not ship.can_act():
		return
	var pm := MatchManager.instance.projectiles
	match weapon:
		"laser":
			if _server_primary_cd > 0.0:
				return
			_server_primary_cd = primary_cooldown() * 0.85
			var dmg := Config.laser.damage + (1 if ship.overcharge_time > 0.0 else 0)
			pm.server_spawn("laser", ship.unique_id(), muzzle, rot, 0, dmg)
		"missile":
			if _server_secondary_cd > 0.0 or ship.missile_ammo <= 0:
				return
			_server_secondary_cd = Config.missile.cooldown * 0.85
			ship.server_set_ammo(ship.missile_ammo - 1)
			var target := pm.find_missile_target(ship)
			pm.server_spawn("missile", ship.unique_id(), muzzle, rot, target, Config.missile.damage)


func primary_ratio() -> float:
	var cd := primary_cooldown()
	return 1.0 - (_primary_cd / cd if cd > 0.0 else 0.0)
