class_name AnomalyZone
extends Area2D
## Reusable Core anomaly. Types: gravity (pull), slow (slow-motion), overcharge (weapon buff), wormhole (teleport to partner).
## Effects on ships are applied by the simulating peer; overcharge is granted by the server.

@export var type: String = "gravity"
@export var radius: float = 220.0
@export var strength: float = 900.0
var partner: AnomalyZone
var _t: float = 0.0
var _cooldown: Dictionary = {}


func _ready() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	add_child(cs)
	collision_layer = 16
	collision_mask = 1
	monitoring = true
	z_index = -5


func _physics_process(delta: float) -> void:
	_t += delta
	for k in _cooldown.keys():
		_cooldown[k] -= delta
		if _cooldown[k] <= 0.0:
			_cooldown.erase(k)
	for body in get_overlapping_bodies():
		if body is Ship:
			_affect(body, delta)
	queue_redraw()


func _affect(ship: Ship, _delta: float) -> void:
	var to := global_position - ship.global_position
	var d := maxf(to.length(), 40.0)
	match type:
		"gravity":
			if ship.is_local_controlled():
				ship.external_force += to.normalized() * strength * (1.0 - d / (radius * 1.2))
		"slow":
			if ship.is_local_controlled():
				ship.slow_factor = 0.45
		"overcharge":
			if Net.is_server() and ship.overcharge_time <= 0.5:
				ship.overcharge_time = 4.0
				ship.server_push_state()
		"wormhole":
			if partner != null and ship.is_local_controlled() and d < 60.0 and not _cooldown.has(ship.unique_id()):
				partner._cooldown[ship.unique_id()] = 1.5
				_cooldown[ship.unique_id()] = 1.5
				ship.global_position = partner.global_position + ship.forward() * 80.0
				VFX.explosion(global_position, Color("b48cff"), 0.5)
				VFX.explosion(partner.global_position, Color("b48cff"), 0.5)
				Audio.play_at("powerup", partner.global_position, -4.0)


func _draw() -> void:
	match type:
		"gravity":
			for i in 4:
				var r := radius * (1.0 - fmod(_t * 0.25 + i * 0.25, 1.0))
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.6, 0.3, 1.0, 0.25 + 0.3 * (r / radius)), 2.0)
			draw_circle(Vector2.ZERO, 26.0, Color(0.1, 0.0, 0.2, 1.0))
		"slow":
			draw_circle(Vector2.ZERO, radius, Color(0.3, 0.9, 1.0, 0.08))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(0.5, 0.95, 1.0, 0.5), 2.0)
			draw_arc(Vector2.ZERO, radius * 0.5, _t, _t + PI, 24, Color(0.5, 0.95, 1.0, 0.4), 2.0)
		"overcharge":
			draw_circle(Vector2.ZERO, radius, Color(0.9, 0.5, 1.0, 0.08))
			for i in 6:
				var a := _t * 2.0 + TAU * i / 6.0
				draw_line(Vector2.RIGHT.rotated(a) * radius * 0.3, Vector2.RIGHT.rotated(a) * radius, Color(1, 0.8, 1, 0.4), 2.0)
		"wormhole":
			for i in 3:
				var a := _t * (1.5 + i * 0.5)
				draw_arc(Vector2.ZERO, 30.0 + i * 16.0, a, a + PI * 1.4, 24, Color(0.7, 0.55, 1.0, 0.8 - i * 0.2), 3.0)
			draw_circle(Vector2.ZERO, 18.0, Color(0.95, 0.9, 1.0, 0.9))
