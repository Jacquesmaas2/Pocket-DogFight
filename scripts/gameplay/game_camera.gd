class_name GameCamera
extends Camera2D
## Follows the local ship with a little look-ahead and settings-aware shake.

var target: Node2D
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	VFX.shake_requested.connect(func(s: float) -> void: _shake = minf(_shake + s, 1.2))
	position_smoothing_enabled = true
	position_smoothing_speed = 8.0
	zoom = Vector2(0.85, 0.85)


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var vel: Vector2 = target.velocity if target is CharacterBody2D else Vector2.ZERO
		global_position = target.global_position + vel * 0.18
	_shake = maxf(_shake - delta * 3.0, 0.0)
	if _shake > 0.0:
		offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake * 18.0
	else:
		offset = Vector2.ZERO


func set_bounds(half: Vector2) -> void:
	limit_left = int(-half.x - 80)
	limit_right = int(half.x + 80)
	limit_top = int(-half.y - 80)
	limit_bottom = int(half.y + 80)
