class_name PowerUp
extends Area2D
## Visual + overlap detection. Collection is decided by PowerUpManager on the server.

var slot: int = 0
var type: String = "shield"
var _t: float = 0.0


func _ready() -> void:
	monitoring = Net.is_server()
	if monitoring:
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func type_color() -> Color:
	match type:
		"shield": return Color("5ad2ff")
		"rapid_fire": return Color("ffd23f")
		"missile": return Color("ff6b6b")
		"boost": return Color("7dffb3")
		"overcharge": return Color("d58cff")
		"core": return Color("ffffff")
	return Color.WHITE


func _on_body_entered(body: Node) -> void:
	if body is Ship:
		MatchManager.instance.powerups.server_try_collect(self, body)


func _draw() -> void:
	var c := type_color()
	var pulse := 1.0 + 0.1 * sin(_t * 4.0)
	draw_circle(Vector2.ZERO, 22.0 * pulse, Color(c.r, c.g, c.b, 0.25))
	draw_arc(Vector2.ZERO, 18.0 * pulse, 0.0, TAU, 24, c, 2.5)
	match type:
		"shield":
			draw_arc(Vector2.ZERO, 9.0, PI * 0.9, PI * 2.1, 12, Color.WHITE, 3.0)
			draw_line(Vector2(-8, 0), Vector2(8, 0), Color.WHITE, 3.0)
		"rapid_fire":
			for i in 3:
				draw_line(Vector2(-8, -6 + i * 6), Vector2(8, -6 + i * 6), Color.WHITE, 2.5)
		"missile":
			draw_colored_polygon(PackedVector2Array([Vector2(10, 0), Vector2(-6, -6), Vector2(-3, 0), Vector2(-6, 6)]), Color.WHITE)
		"boost":
			draw_colored_polygon(PackedVector2Array([Vector2(-2, -10), Vector2(6, 0), Vector2(-2, 10), Vector2(2, 0)]), Color.WHITE)
			draw_colored_polygon(PackedVector2Array([Vector2(-9, -8), Vector2(-2, 0), Vector2(-9, 8), Vector2(-5, 0)]), Color.WHITE)
		"overcharge":
			draw_colored_polygon(PackedVector2Array([Vector2(2, -11), Vector2(-6, 1), Vector2(0, 1), Vector2(-3, 11), Vector2(7, -2), Vector2(1, -2)]), Color.WHITE)
		"core":
			draw_circle(Vector2.ZERO, 8.0 + 2.0 * sin(_t * 7.0), Color("c2f0ff"))
			draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
