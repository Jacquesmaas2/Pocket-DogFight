class_name Projectile
extends Area2D
## Laser bolt or homing missile. Simulated locally on every peer; hits resolved on server only.

@export var kind: String = "laser"

var id: int = 0
var shooter_id: int = 0
var target_id: int = 0
var damage: int = 1
var tint: Color = Color.WHITE
var consumed: bool = false
var velocity: Vector2 = Vector2.ZERO
var _life: float = 0.0
var _stats: WeaponStats

@onready var trail: Line2D = get_node_or_null("Trail")


func setup(pid: int, sid: int, pos: Vector2, rot: float, tid: int, dmg: int) -> void:
	id = pid
	shooter_id = sid
	target_id = tid
	damage = dmg
	global_position = pos
	rotation = rot


func _ready() -> void:
	_stats = Config.missile if kind == "missile" else Config.laser
	velocity = Vector2.RIGHT.rotated(rotation) * _stats.projectile_speed
	_life = _stats.lifetime
	monitoring = Net.is_server()
	if monitoring:
		body_entered.connect(_on_body_entered)
	if trail != null:
		trail.top_level = true
		trail.clear_points()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_life -= delta
	if kind == "missile":
		_home(delta)
	global_position += velocity * delta
	if trail != null:
		trail.add_point(global_position)
		while trail.get_point_count() > 12:
			trail.remove_point(0)
	if _life <= 0.0 and Net.is_server():
		MatchManager.instance.projectiles.server_despawn(self, global_position, kind == "missile")


func _home(delta: float) -> void:
	if target_id == 0:
		return
	var target := MatchManager.instance.ships.find_ship(target_id)
	if target == null or not target.alive:
		target_id = 0
		return
	var desired := (target.global_position - global_position).angle()
	rotation = rotate_toward(rotation, desired, _stats.turn_rate * delta)
	velocity = Vector2.RIGHT.rotated(rotation) * _stats.projectile_speed


func _on_body_entered(body: Node) -> void:
	if consumed or not Net.is_server():
		return
	var mm := MatchManager.instance
	if body is Ship:
		var s := body as Ship
		if s.unique_id() == shooter_id or not s.alive:
			return
		if kind == "missile":
			_explode(mm)
		else:
			mm.apply_damage(s, damage, shooter_id, "laser")
			mm.projectiles.server_despawn(self, global_position, true)
	else:
		if kind == "missile":
			_explode(mm)
		else:
			mm.projectiles.server_despawn(self, global_position, true)


func _explode(mm: MatchManager) -> void:
	for s in mm.ships.all_ships():
		if not s.alive or s.unique_id() == shooter_id:
			continue
		if s.global_position.distance_to(global_position) <= _stats.explosion_radius:
			mm.apply_damage(s, damage, shooter_id, "missile")
	mm.projectiles.server_despawn(self, global_position, true)


func _draw() -> void:
	if kind == "missile":
		draw_colored_polygon(PackedVector2Array([Vector2(10, 0), Vector2(-6, -4), Vector2(-6, 4)]), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, -4), Vector2(-10, -6), Vector2(-8, 0), Vector2(-10, 6), Vector2(-6, 4)]), tint)
	else:
		draw_line(Vector2(-10, 0), Vector2(10, 0), tint, 5.0)
		draw_line(Vector2(-8, 0), Vector2(10, 0), Color.WHITE, 2.0)
