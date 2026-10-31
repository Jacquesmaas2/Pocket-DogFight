extends Node2D
## The enormous unidentified ship. Reusable large hazard: drifts in, fires slow heavy shots, launches drones.
## Dies when all its turret nodes are destroyed (turrets are regular AI ships with team 5 and zero thrust).

const SHOOTER_ID := -999

var alive: bool = true
var _runner: Node
var _turrets: Array[Ship] = []
var _fire_timer: float = 0.0
var _drone_timer: float = 8.0
var _active: bool = false
var _body: AnimatableBody2D
var _target_pos: Vector2
var _t: float = 0.0


func _ready() -> void:
	z_index = -2
	_body = AnimatableBody2D.new()
	_body.collision_layer = 4
	_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(520, 220)
	cs.shape = rect
	_body.add_child(cs)
	add_child(_body)
	_target_pos = global_position


func enter(target: Vector2) -> void:
	_target_pos = target


func activate(runner: Node) -> void:
	_runner = runner
	_active = true
	var mm: MatchManager = MatchManager.instance
	for off in [Vector2(-200, -130), Vector2(0, -130), Vector2(200, -130), Vector2(-200, 130), Vector2(0, 130), Vector2(200, 130)]:
		var t := mm.ships.server_spawn_ai("corp", "Turret", global_position + off, PI, 5, "fighter")
		t.stats = t.stats.duplicate()
		t.stats.acceleration = 0.0
		t.stats.max_velocity = 0.0
		t.stats.max_health = 3
		t.health = 3
		(t.input_source as InputSource).set("aggression", 0.5)
		t.color = Color("ff3b6b")
		t.visual.setup("corp", t.color)
		_turrets.append(t)


func _physics_process(delta: float) -> void:
	_t += delta
	global_position = global_position.move_toward(_target_pos, 90.0 * delta)
	var mm: MatchManager = MatchManager.instance
	if not _active or not Net.is_server():
		queue_redraw()
		return
	var remaining := 0
	for t in _turrets:
		if is_instance_valid(t) and t.alive:
			remaining += 1
			t.global_position = t.global_position.move_toward(global_position + (t.global_position - global_position), 0.0)
	if remaining == 0 and alive:
		alive = false
		VFX.explosion(global_position, Color("ff3b6b"), 4.0)
		VFX.shake(1.2)
		Audio.play("explosion")
		_target_pos = global_position + Vector2(2000, 0)
		for s in mm.ships.all_ships():
			if s.team == 5:
				mm.ships.server_remove(s.unique_id())
		return
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = 1.6
		var target := _nearest_enemy()
		if target != null:
			var dir := (target.global_position - global_position).angle()
			for spread in [-0.15, 0.0, 0.15]:
				mm.projectiles.server_spawn("laser", SHOOTER_ID, global_position + Vector2.RIGHT.rotated(dir + spread) * 280.0, dir + spread, 0, 1)
	_drone_timer -= delta
	if _drone_timer <= 0.0:
		_drone_timer = 14.0
		if mm.ships.all_ships().size() < 18:
			_runner.spawn_enemies("scrap", 2, 5, global_position + Vector2(-400, 0), 150.0, "Drone", 0.7)
	queue_redraw()


func _nearest_enemy() -> Ship:
	var best: Ship = null
	var bd := INF
	for s in MatchManager.instance.ships.all_ships():
		if s.team == 5 or not s.alive:
			continue
		var d := s.global_position.distance_to(global_position)
		if d < bd and d < 1400.0:
			bd = d
			best = s
	return best


func _draw() -> void:
	var hull := Color("2b2f3f")
	var edge := Color("ff3b6b")
	draw_colored_polygon(PackedVector2Array([Vector2(-320, -60), Vector2(-260, -140), Vector2(260, -140), Vector2(340, -40), Vector2(340, 40), Vector2(260, 140), Vector2(-260, 140), Vector2(-320, 60)]), hull)
	draw_polyline(PackedVector2Array([Vector2(-320, -60), Vector2(-260, -140), Vector2(260, -140), Vector2(340, -40), Vector2(340, 40), Vector2(260, 140), Vector2(-260, 140), Vector2(-320, 60), Vector2(-320, -60)]), edge, 4.0)
	for i in 7:
		var x := -240 + i * 80
		draw_rect(Rect2(x, -20, 40, 40), Color(0.9, 0.2, 0.4, 0.5 + 0.5 * sin(_t * 3.0 + i)))
	draw_circle(Vector2(-330, 0), 30.0 + 6.0 * sin(_t * 6.0), Color("7dffff"))
