extends InputSource
## Simple reusable combat AI. Runs only on the server (AI ships are server-controlled).
## Behaviours: fighter (hunt), racer (follow waypoints), escort (stay near ally, fight nearby threats).

var behaviour: String = "fighter"
var waypoints: Array[Vector2] = []
var waypoint_index: int = 0
var escort_target: Ship
var aggression: float = 1.0
var preferred_distance: float = 260.0

var _target: Ship
var _retarget: float = 0.0
var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var ship: Ship = get_parent()


func _ready() -> void:
	_rng.randomize()
	_strafe_dir = 1.0 if _rng.randf() > 0.5 else -1.0


func update(delta: float) -> void:
	input.clear()
	if not ship.can_act():
		return
	_retarget -= delta
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = _rng.randf_range(1.0, 2.5)
		_strafe_dir *= -1.0
	if _retarget <= 0.0:
		_retarget = 0.8
		_target = _pick_target()
	match behaviour:
		"racer": _race(delta)
		"escort": _escort(delta)
		_: _fight(delta)


func _pick_target() -> Ship:
	var best: Ship = null
	var best_d := INF
	for s in MatchManager.instance.ships.all_ships():
		if s == ship or not s.alive:
			continue
		if ship.team != 0 and s.team == ship.team:
			continue
		if ship.team == 0 and s.team == 0 and s.peer_id == 0:
			continue
		var d := ship.global_position.distance_to(s.global_position)
		if behaviour == "escort" and d > 900.0:
			continue
		if d < best_d:
			best_d = d
			best = s
	return best


func _steer_to(point: Vector2, delta: float) -> float:
	var desired := (point - ship.global_position).angle()
	var diff := wrapf(desired - ship.rotation, -PI, PI)
	input.turn = clampf(diff * 3.0, -1.0, 1.0)
	return absf(diff)


func _avoid_obstacles() -> Vector2:
	var space := ship.get_world_2d().direct_space_state
	var push := Vector2.ZERO
	for ang in [-0.6, 0.0, 0.6]:
		var dir := ship.forward().rotated(ang)
		var q := PhysicsRayQueryParameters2D.create(ship.global_position, ship.global_position + dir * 220.0, 4)
		var hit := space.intersect_ray(q)
		if hit:
			push += hit["normal"] * (1.0 - ship.global_position.distance_to(hit["position"]) / 220.0)
	return push


func _fight(delta: float) -> void:
	var avoid := _avoid_obstacles()
	if _target == null:
		if waypoints.is_empty():
			_wander(delta)
		else:
			_race(delta)
		return
	var to := _target.global_position - ship.global_position
	var dist := to.length()
	var aim_point := _target.global_position + _target.velocity * (dist / Config.laser.projectile_speed)
	var goal := aim_point
	if dist < preferred_distance * 0.6:
		goal = ship.global_position + to.rotated(_strafe_dir * 1.4)
	if avoid.length() > 0.05:
		goal = ship.global_position + avoid * 300.0 + ship.forward() * 100.0
	var err := _steer_to(goal, delta)
	input.thrust = 1.0 if err < 1.2 else 0.4
	input.boost = dist > 700.0
	var aim_err := absf(wrapf((aim_point - ship.global_position).angle() - ship.rotation, -PI, PI))
	if aim_err < 0.18 and dist < 850.0 and _rng.randf() < aggression:
		input.fire_primary = true
	if aim_err < 0.5 and dist > 250.0 and dist < 800.0 and ship.missile_ammo > 0 and _rng.randf() < 0.01 * aggression:
		input.fire_secondary = true


func _wander(delta: float) -> void:
	var center := Vector2.ZERO
	var err := _steer_to(center + Vector2.RIGHT.rotated(Time.get_ticks_msec() * 0.0004 + ship.ai_id) * 500.0, delta)
	input.thrust = 0.6 if err < 1.0 else 0.2


func _race(delta: float) -> void:
	if waypoints.is_empty():
		_wander(delta)
		return
	var wp := waypoints[waypoint_index % waypoints.size()]
	if ship.global_position.distance_to(wp) < 120.0:
		waypoint_index += 1
		wp = waypoints[waypoint_index % waypoints.size()]
	var avoid := _avoid_obstacles()
	var goal := wp if avoid.length() < 0.05 else ship.global_position + avoid * 300.0 + ship.forward() * 120.0
	var err := _steer_to(goal, delta)
	input.thrust = 1.0 if err < 1.0 else 0.3
	input.boost = err < 0.3 and aggression > 0.8


func _escort(delta: float) -> void:
	if _target != null:
		_fight(delta)
		return
	if escort_target == null or not is_instance_valid(escort_target):
		_wander(delta)
		return
	var goal := escort_target.global_position + Vector2(-80, 80).rotated(escort_target.rotation)
	var d := ship.global_position.distance_to(goal)
	var err := _steer_to(goal, delta)
	input.thrust = clampf(d / 300.0, 0.0, 1.0) if err < 1.0 else 0.2
	input.boost = d > 700.0
