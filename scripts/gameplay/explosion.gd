extends Node2D
## Comically oversized procedural explosion: flash ring + debris particles.

var _color: Color = Color.ORANGE
var _scale: float = 1.0
var _t: float = 0.0
const DURATION := 0.6

@onready var particles: CPUParticles2D = $Particles


func setup(color: Color, scale_factor: float) -> void:
	_color = color
	_scale = scale_factor
	particles.color = color.lightened(0.2)
	particles.amount = int(24 * scale_factor) + 6
	particles.initial_velocity_max = 320.0 * scale_factor
	particles.emitting = true
	particles.one_shot = true
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION + 0.4:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var p := clampf(_t / DURATION, 0.0, 1.0)
	if p >= 1.0:
		return
	var r := (20.0 + 90.0 * p) * _scale
	var a := 1.0 - p
	draw_circle(Vector2.ZERO, r, Color(_color.r, _color.g, _color.b, a * 0.35))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1, 1, 1, a), 4.0 * _scale)
	if p < 0.3:
		draw_circle(Vector2.ZERO, r * 0.6, Color(1, 1, 0.8, (0.3 - p) / 0.3))
