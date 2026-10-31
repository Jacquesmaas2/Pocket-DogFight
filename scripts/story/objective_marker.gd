extends Node2D
## Pulsing objective ring with optional label.

var label: String = ""
var color: Color = Color("ffe04a")
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := 110.0 + 10.0 * sin(_t * 3.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, color, 4.0)
	draw_arc(Vector2.ZERO, r * 0.6, _t * 2.0, _t * 2.0 + PI, 24, Color(color, 0.6), 3.0)
	draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.07))
	if label != "":
		var font := ThemeDB.fallback_font
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 26).x
		draw_string(font, Vector2(-w / 2, -r - 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
