class_name ProjectileManager
extends Node2D
## Spawns projectiles on every peer; only the server detects hits and despawns.

const LASER_SCENE := preload("res://scenes/projectiles/laser.tscn")
const MISSILE_SCENE := preload("res://scenes/projectiles/missile.tscn")

var _next_id: int = 1
var _live: Dictionary = {} # id -> Projectile


func server_spawn(kind: String, shooter_id: int, pos: Vector2, rot: float, target_id: int, damage: int) -> void:
	if not Net.is_server():
		return
	var id := _next_id
	_next_id += 1
	_spawn.rpc(id, kind, shooter_id, pos, rot, target_id, damage)
	_spawn(id, kind, shooter_id, pos, rot, target_id, damage)


@rpc("authority", "reliable", "call_remote")
func _spawn(id: int, kind: String, shooter_id: int, pos: Vector2, rot: float, target_id: int, damage: int) -> void:
	var scene := MISSILE_SCENE if kind == "missile" else LASER_SCENE
	var p: Projectile = scene.instantiate()
	p.setup(id, shooter_id, pos, rot, target_id, damage)
	add_child(p)
	_live[id] = p
	p.tree_exited.connect(func() -> void: _live.erase(id))
	var shooter := MatchManager.instance.ships.find_ship(shooter_id)
	if shooter != null:
		p.tint = shooter.color
	elif shooter_id <= -900:
		p.tint = Color("ff3b6b")
	if kind == "missile":
		Audio.play_at("missile_launch", pos, -2.0)
		var local_ship := MatchManager.instance.ships.local_ship()
		if local_ship != null and target_id == local_ship.unique_id():
			MatchManager.instance.missile_lock_warning.emit(true)
	else:
		Audio.play_at("laser", pos, -8.0)
	VFX.hit(pos, Color.WHITE)


## Server only: resolves a projectile hit and informs everyone.
func server_despawn(p: Projectile, hit_pos: Vector2, exploded: bool) -> void:
	if not Net.is_server() or p.consumed:
		return
	p.consumed = true
	_despawn.rpc(p.id, hit_pos, exploded)
	_despawn(p.id, hit_pos, exploded)


@rpc("authority", "reliable", "call_remote")
func _despawn(id: int, hit_pos: Vector2, exploded: bool) -> void:
	var p: Projectile = _live.get(id)
	if p == null or not is_instance_valid(p):
		return
	if exploded:
		VFX.explosion(hit_pos, p.tint, 0.9 if p.kind == "missile" else 0.3)
		Audio.play_at("explosion" if p.kind == "missile" else "laser_impact", hit_pos, -4.0)
		if p.kind == "missile":
			VFX.shake(0.3)
	p.queue_free()


func find_missile_target(shooter: Ship) -> int:
	var best_id := 0
	var best_score := INF
	var cone := deg_to_rad(Config.missile.lock_cone_degrees)
	for s in MatchManager.instance.ships.all_ships():
		if s == shooter or not s.alive:
			continue
		if shooter.team != 0 and s.team == shooter.team:
			continue
		var to := s.global_position - shooter.global_position
		var dist := to.length()
		if dist > Config.missile.lock_range:
			continue
		var ang := absf(shooter.forward().angle_to(to))
		if ang > cone:
			continue
		var score := dist + ang * 400.0
		if score < best_score:
			best_score = score
			best_id = s.unique_id()
	return best_id


func clear_all() -> void:
	for p in _live.values():
		if is_instance_valid(p):
			p.queue_free()
	_live.clear()


func any_missile_targeting(ship_id: int) -> bool:
	for p in _live.values():
		if is_instance_valid(p) and p.kind == "missile" and p.target_id == ship_id:
			return true
	return false
