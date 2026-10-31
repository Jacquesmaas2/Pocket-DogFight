class_name Arena
extends Node2D
## Asteroid Belt arena: bounded play space, procedural asteroid layout, spawn points, power-up spots.

const ASTEROID := preload("res://scripts/gameplay/asteroid.gd")

@export var half_size: Vector2 = Vector2(1500, 950)
@export var asteroid_count: int = 22
@export var layout_seed: int = 1337
@export var build_asteroids: bool = true

var _stars: PackedVector2Array
var _star_sizes: PackedFloat32Array
var _spawn_points: Array[Marker2D] = []
var _powerup_spots: Array[Marker2D] = []


func _ready() -> void:
	z_index = -10
	_build_walls()
	_build_stars()
	_build_spawn_points()
	if build_asteroids:
		_build_asteroids()
	queue_redraw()


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 4
	walls.collision_mask = 0
	var thickness := 60.0
	var defs := [
		[Vector2(0, -half_size.y - thickness / 2), Vector2(half_size.x * 2 + thickness * 2, thickness)],
		[Vector2(0, half_size.y + thickness / 2), Vector2(half_size.x * 2 + thickness * 2, thickness)],
		[Vector2(-half_size.x - thickness / 2, 0), Vector2(thickness, half_size.y * 2)],
		[Vector2(half_size.x + thickness / 2, 0), Vector2(thickness, half_size.y * 2)],
	]
	for d in defs:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = d[1]
		cs.shape = rect
		cs.position = d[0]
		walls.add_child(cs)
	add_child(walls)


func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed + 7
	_stars = PackedVector2Array()
	_star_sizes = PackedFloat32Array()
	for i in 260:
		_stars.append(Vector2(rng.randf_range(-half_size.x - 400, half_size.x + 400), rng.randf_range(-half_size.y - 400, half_size.y + 400)))
		_star_sizes.append(rng.randf_range(0.8, 2.4))


func _build_spawn_points() -> void:
	var margin := 180.0
	var pts := [
		Vector2(-half_size.x + margin, -half_size.y + margin), Vector2(half_size.x - margin, half_size.y - margin),
		Vector2(half_size.x - margin, -half_size.y + margin), Vector2(-half_size.x + margin, half_size.y - margin),
		Vector2(0, -half_size.y + margin), Vector2(0, half_size.y - margin),
		Vector2(-half_size.x + margin, 0), Vector2(half_size.x - margin, 0),
	]
	for p in pts:
		var m := Marker2D.new()
		m.position = p
		m.rotation = (-p).angle()
		add_child(m)
		_spawn_points.append(m)
	var spots := [Vector2(0, 0), Vector2(-half_size.x * 0.5, -half_size.y * 0.5), Vector2(half_size.x * 0.5, half_size.y * 0.5), Vector2(half_size.x * 0.5, -half_size.y * 0.5), Vector2(-half_size.x * 0.5, half_size.y * 0.5)]
	for p in spots:
		var m := Marker2D.new()
		m.position = p
		add_child(m)
		_powerup_spots.append(m)


func _build_asteroids() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < asteroid_count and tries < 500:
		tries += 1
		var p := Vector2(rng.randf_range(-half_size.x + 200, half_size.x - 200), rng.randf_range(-half_size.y + 200, half_size.y - 200))
		var ok := true
		for sp in _spawn_points:
			if sp.position.distance_to(p) < 260.0:
				ok = false
		for ps in _powerup_spots:
			if ps.position.distance_to(p) < 160.0:
				ok = false
		for q in placed:
			if q.distance_to(p) < 240.0:
				ok = false
		if not ok:
			continue
		placed.append(p)
		add_asteroid(p, rng.randf_range(38.0, 95.0), rng.randi())


func add_asteroid(pos: Vector2, radius: float, seed_value: int = 0) -> Asteroid:
	var a: Asteroid = ASTEROID.new()
	a.radius = radius
	a.seed_value = seed_value
	a.position = pos
	add_child(a)
	return a


func spawn_point(index: int) -> Marker2D:
	return _spawn_points[index % _spawn_points.size()]


func safe_spawn_point(ships: Array[Ship]) -> Marker2D:
	var best: Marker2D = _spawn_points[0]
	var best_dist := -1.0
	for sp in _spawn_points:
		var d := INF
		for s in ships:
			if s.alive:
				d = minf(d, s.global_position.distance_to(sp.global_position))
		if d > best_dist:
			best_dist = d
			best = sp
	return best


func powerup_spots() -> Array[Marker2D]:
	return _powerup_spots


func random_point(rng: RandomNumberGenerator, margin: float = 200.0) -> Vector2:
	return Vector2(rng.randf_range(-half_size.x + margin, half_size.x - margin), rng.randf_range(-half_size.y + margin, half_size.y - margin))


func _draw() -> void:
	for i in _stars.size():
		var s := _star_sizes[i]
		draw_circle(_stars[i], s, Color(0.8, 0.85, 1.0, 0.35 + 0.3 * (s - 0.8)))
	# nebula hint
	draw_circle(Vector2(-half_size.x * 0.4, half_size.y * 0.3), 420.0, Color(0.25, 0.2, 0.5, 0.08))
	draw_circle(Vector2(half_size.x * 0.5, -half_size.y * 0.4), 360.0, Color(0.1, 0.35, 0.5, 0.08))
	# boundary
	var r := Rect2(-half_size, half_size * 2)
	draw_rect(r, Color(0.35, 0.6, 1.0, 0.35), false, 4.0)
	draw_rect(r.grow(-12), Color(0.35, 0.6, 1.0, 0.12), false, 2.0)
