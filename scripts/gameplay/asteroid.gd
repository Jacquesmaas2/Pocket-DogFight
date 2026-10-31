class_name Asteroid
extends StaticBody2D
## Procedurally shaped asteroid. Static so every peer sees identical geometry.

@export var radius: float = 60.0
@export var seed_value: int = 0

var _points: PackedVector2Array


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else int(global_position.x * 31 + global_position.y * 17)
	var count := 10 + rng.randi_range(0, 4)
	_points = PackedVector2Array()
	for i in count:
		var a := TAU * i / count
		var r := radius * rng.randf_range(0.72, 1.0)
		_points.append(Vector2.RIGHT.rotated(a) * r)
	var shape := CollisionPolygon2D.new()
	shape.polygon = _points
	add_child(shape)
	collision_layer = 4
	collision_mask = 0
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(_points, Color("5a5f6e"))
	var inner := PackedVector2Array()
	for p in _points:
		inner.append(p * 0.75 + Vector2(-radius * 0.08, -radius * 0.08))
	draw_colored_polygon(inner, Color("6f7587"))
	draw_polyline(_points + PackedVector2Array([_points[0]]), Color("2f3340"), 3.0)
	draw_circle(Vector2(radius * 0.2, radius * 0.1), radius * 0.15, Color("4a4f5e"))
	draw_circle(Vector2(-radius * 0.3, radius * 0.3), radius * 0.1, Color("4a4f5e"))
