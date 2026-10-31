class_name Ship
extends CharacterBody2D
## Player/AI ship. Movement is simulated by the owning peer (or server for AI);
## health, death, ammo and pickups are only ever changed by the server.

signal died(ship: Ship, killer_id: int)
signal health_changed(current: int, maximum: int)
signal respawned(ship: Ship)
signal ammo_changed(count: int)
signal effects_changed

const NET_SEND_HZ := 20.0

@export var stats: ShipStats
@export var ship_id: String = "generic"

var peer_id: int = 1 # owning peer; 0 = server-controlled AI
var ai_id: int = 0 # unique id for AI ships (negative peer-like id when peer_id == 0)
var team: int = 0 # 0 = free-for-all / players, >0 = faction
var pilot_name: String = "Pilot"
var color: Color = Color.CYAN
var input_source: InputSource

var health: int = 3
var alive: bool = true
var controllable: bool = true # false during countdown/results
var missile_ammo: int = 2
var spawn_protection: float = 0.0
var shield_time: float = 0.0
var rapid_fire_time: float = 0.0
var boost_time: float = 0.0
var overcharge_time: float = 0.0
var slow_factor: float = 1.0 # set by slow-motion fields (local sim)
var external_force: Vector2 = Vector2.ZERO # gravity wells etc. (local sim)

var thrusting: float = 0.0
var boosting: bool = false

# networking
var _net_target_pos: Vector2
var _net_target_rot: float
var _net_velocity: Vector2
var _send_accum: float = 0.0
var _last_server_velocity: Vector2 = Vector2.ZERO
var _collision_damage_cooldown: float = 0.0

@onready var visual: ShipVisual = $Visual
@onready var weapons: WeaponSystem = $Weapons
@onready var trail: Line2D = $Trail
@onready var collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if stats == null:
		stats = Config.ship_stats(ship_id)
	health = stats.max_health
	missile_ammo = stats.missile_ammo
	_net_target_pos = global_position
	_net_target_rot = rotation
	visual.setup(stats.visual_variant, color)
	trail.default_color = Color(color, 0.7)
	trail.top_level = true
	trail.clear_points()
	health_changed.emit(health, stats.max_health)


func is_local_controlled() -> bool:
	if peer_id == 0:
		return Net.is_server()
	return peer_id == Net.local_id()


func unique_id() -> int:
	return peer_id if peer_id != 0 else ai_id


func can_act() -> bool:
	return alive and controllable


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if is_local_controlled():
		_simulate(delta)
		_send_transform(delta)
	else:
		_interpolate(delta)
	_update_trail()
	visual.update_state(thrusting, boosting, shield_time > 0.0, spawn_protection > 0.0, alive)
	Audio.set_engine(self, alive and thrusting > 0.05, thrusting * (1.4 if boosting else 1.0))


func _tick_timers(delta: float) -> void:
	spawn_protection = maxf(spawn_protection - delta, 0.0)
	_collision_damage_cooldown = maxf(_collision_damage_cooldown - delta, 0.0)
	var had_fx := shield_time > 0.0 or rapid_fire_time > 0.0 or boost_time > 0.0 or overcharge_time > 0.0
	shield_time = maxf(shield_time - delta, 0.0)
	rapid_fire_time = maxf(rapid_fire_time - delta, 0.0)
	boost_time = maxf(boost_time - delta, 0.0)
	overcharge_time = maxf(overcharge_time - delta, 0.0)
	var has_fx := shield_time > 0.0 or rapid_fire_time > 0.0 or boost_time > 0.0 or overcharge_time > 0.0
	if had_fx != has_fx:
		effects_changed.emit()


func _simulate(delta: float) -> void:
	var inp: ShipInput = input_source.input if input_source != null else ShipInput.new()
	if input_source != null:
		input_source.update(delta)
	if not can_act():
		inp = ShipInput.new()
	var dt := delta * slow_factor
	rotation += inp.turn * stats.rotation_speed * dt
	boosting = inp.boost and inp.thrust > 0.0 and alive or boost_time > 0.0 and inp.thrust > 0.0
	var accel := stats.acceleration * (stats.boost_multiplier if boosting else 1.0)
	var max_v := stats.max_velocity * (stats.boost_multiplier if boosting else 1.0)
	thrusting = inp.thrust
	velocity += Vector2.RIGHT.rotated(rotation) * accel * inp.thrust * dt
	velocity += external_force * dt
	external_force = Vector2.ZERO
	velocity = velocity.lerp(Vector2.ZERO, clampf(stats.damping * dt, 0.0, 1.0))
	if velocity.length() > max_v:
		velocity = velocity.lerp(velocity.normalized() * max_v, 0.15)
	var motion := velocity * dt
	var hit := move_and_collide(motion)
	if hit != null:
		var n := hit.get_normal()
		var impact := absf(velocity.dot(n))
		velocity = velocity.bounce(n) * 0.55
		global_position += n * 2.0
		if impact > 120.0:
			VFX.hit(hit.get_position(), Color.WHITE)
			Audio.play_at("collision", hit.get_position(), -6.0)
			if peer_id == Net.local_id():
				VFX.shake(clampf(impact / 800.0, 0.05, 0.5))
	if alive and can_act():
		weapons.handle_input(inp)
	slow_factor = 1.0


func _send_transform(delta: float) -> void:
	if not Net.is_online():
		return
	_send_accum += delta
	if _send_accum < 1.0 / NET_SEND_HZ:
		return
	_send_accum = 0.0
	_net_transform.rpc(global_position, rotation, velocity, thrusting, boosting)


@rpc("any_peer", "unreliable_ordered", "call_remote")
func _net_transform(pos: Vector2, rot: float, vel: Vector2, thrust: float, boost: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if peer_id != 0 and sender != peer_id and sender != 1:
		return # only the owner (or server relaying AI) may move this ship
	if peer_id == 0 and sender != 1:
		return
	_net_target_pos = pos
	_net_target_rot = rot
	_net_velocity = vel
	thrusting = thrust
	boosting = boost
	if Net.is_server():
		_server_detect_collision(vel)


func _server_detect_collision(vel: Vector2) -> void:
	var dv := (vel - _last_server_velocity).length()
	_last_server_velocity = vel
	if dv < stats.collision_damage_speed or _collision_damage_cooldown > 0.0 or not alive:
		return
	var space := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 34.0
	query.shape = circle
	query.transform = Transform2D(0.0, _net_target_pos)
	query.collision_mask = 0b101 # ships + world
	query.exclude = [get_rid()]
	if space.intersect_shape(query, 1).size() > 0:
		_collision_damage_cooldown = 0.6
		MatchManager.instance.apply_damage(self, 1, 0, "collision")


func _interpolate(delta: float) -> void:
	_net_target_pos += _net_velocity * delta
	global_position = global_position.lerp(_net_target_pos, clampf(delta * 12.0, 0.0, 1.0))
	rotation = lerp_angle(rotation, _net_target_rot, clampf(delta * 12.0, 0.0, 1.0))
	velocity = _net_velocity


func _update_trail() -> void:
	if not alive:
		trail.clear_points()
		return
	var back := global_position - Vector2.RIGHT.rotated(rotation) * 16.0
	trail.add_point(back)
	var max_points := 14 if boosting else 8
	while trail.get_point_count() > max_points:
		trail.remove_point(0)
	trail.width = 6.0 if boosting else 3.0
	trail.visible = thrusting > 0.05 or trail.get_point_count() > 2
	if thrusting <= 0.05 and trail.get_point_count() > 0:
		trail.remove_point(0)


# ---------------------------------------------------------------- server-authoritative state
## Server only. Returns true if the ship died.
func server_apply_damage(amount: int, attacker_id: int) -> bool:
	if not Net.is_server() or not alive:
		return false
	if spawn_protection > 0.0 or shield_time > 0.0:
		_rpc_state.rpc(health, missile_ammo, alive, spawn_protection, shield_time, rapid_fire_time, boost_time, overcharge_time)
		return false
	health = maxi(health - amount, 0)
	if health <= 0:
		alive = false
	_rpc_state.rpc(health, missile_ammo, alive, spawn_protection, shield_time, rapid_fire_time, boost_time, overcharge_time)
	_apply_local_state()
	if not alive:
		_rpc_died.rpc(attacker_id)
		_rpc_died(attacker_id)
		return true
	return false


func server_set_ammo(count: int) -> void:
	missile_ammo = maxi(count, 0)
	server_push_state()


func server_push_state() -> void:
	if Net.is_server():
		_rpc_state.rpc(health, missile_ammo, alive, spawn_protection, shield_time, rapid_fire_time, boost_time, overcharge_time)
		_apply_local_state()


func server_respawn(pos: Vector2, rot: float) -> void:
	if not Net.is_server():
		return
	health = stats.max_health
	alive = true
	missile_ammo = stats.missile_ammo
	spawn_protection = Config.match_config.spawn_protection
	shield_time = 0.0
	rapid_fire_time = 0.0
	boost_time = 0.0
	overcharge_time = 0.0
	_rpc_respawn.rpc(pos, rot)
	_rpc_respawn(pos, rot)
	server_push_state()


@rpc("authority", "reliable", "call_remote")
func _rpc_state(h: int, ammo: int, a: bool, prot: float, shield: float, rapid: float, boost: float, over: float) -> void:
	health = h
	missile_ammo = ammo
	alive = a
	spawn_protection = prot
	shield_time = shield
	rapid_fire_time = rapid
	boost_time = boost
	overcharge_time = over
	_apply_local_state()


func _apply_local_state() -> void:
	health_changed.emit(health, stats.max_health)
	ammo_changed.emit(missile_ammo)
	effects_changed.emit()
	collision.set_deferred("disabled", not alive)
	visible = alive or visual.death_anim_playing


@rpc("authority", "reliable", "call_remote")
func _rpc_died(killer_id: int) -> void:
	alive = false
	velocity = Vector2.ZERO
	_net_velocity = Vector2.ZERO
	thrusting = 0.0
	collision.set_deferred("disabled", true)
	VFX.explosion(global_position, color, 1.6)
	VFX.shake(0.9 if peer_id == Net.local_id() else 0.35)
	Audio.play_at("explosion", global_position)
	visual.play_death()
	died.emit(self, killer_id)


@rpc("authority", "reliable", "call_remote")
func _rpc_respawn(pos: Vector2, rot: float) -> void:
	global_position = pos
	rotation = rot
	velocity = Vector2.ZERO
	_net_target_pos = pos
	_net_target_rot = rot
	_net_velocity = Vector2.ZERO
	alive = true
	visible = true
	collision.set_deferred("disabled", false)
	trail.clear_points()
	visual.reset()
	weapons.reset()
	Audio.play_at("respawn", pos, -4.0)
	respawned.emit(self)


func forward() -> Vector2:
	return Vector2.RIGHT.rotated(rotation)
