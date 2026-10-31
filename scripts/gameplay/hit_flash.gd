extends Node2D
## Small impact spark.

var _color: Color = Color.WHITE
var _t: float = 0.0


func setup(color: Color) -> void:
	_color = color


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.18:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var p := _t / 0.18
	var r := 6.0 + 14.0 * p
	draw_circle(Vector2.ZERO, r, Color(_color.r, _color.g, _color.b, 0.8 * (1.0 - p)))
	for i in 5:
		var a := TAU * i / 5.0 + p
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(a) * r * 1.6, Color(1, 1, 1, 1.0 - p), 2.0)
