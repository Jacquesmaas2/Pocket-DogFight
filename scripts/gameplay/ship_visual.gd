class_name ShipVisual
extends Node2D
## Procedural cartoon ship drawing. Variants: syntiq, bad_idea, generic, scrap, security, corp.

var variant: String = "generic"
var color: Color = Color.CYAN
var _thrust: float = 0.0
var _boost: bool = false
var _shield: bool = false
var _protected: bool = false
var _alive: bool = true
var _time: float = 0.0
var death_anim_playing: bool = false
var _hit_flash: float = 0.0


func setup(v: String, c: Color) -> void:
	variant = v
	color = c
	queue_redraw()


func update_state(thrust: float, boost: bool, shield: bool, protected: bool, alive: bool) -> void:
	_thrust = thrust
	_boost = boost
	_shield = shield
	_protected = protected
	_alive = alive
	queue_redraw()


func flash() -> void:
	_hit_flash = 0.12


func play_death() -> void:
	death_anim_playing = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.8, 1.8), 0.12)
	tw.tween_property(self, "scale", Vector2.ZERO, 0.18)
	tw.tween_callback(func() -> void: death_anim_playing = false; get_parent().visible = false)


func reset() -> void:
	death_anim_playing = false
	scale = Vector2.ONE
	visible = true


func _process(delta: float) -> void:
	_time += delta
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if _thrust > 0.0 or _shield or _protected or _hit_flash > 0.0:
		queue_redraw()


func _draw() -> void:
	if not _alive and not death_anim_playing:
		return
	var body := color
	if _hit_flash > 0.0:
		body = Color.WHITE
	if _protected and fmod(_time, 0.2) < 0.1:
		body = body.lightened(0.5)
	var dark := color.darkened(0.45)
	var light := color.lightened(0.35)
	# engine flame
	if _thrust > 0.05:
		var flicker := 1.0 + 0.3 * sin(_time * 60.0)
		var len := (26.0 if _boost else 16.0) * _thrust * flicker
		var flame_color := Color("ffd166") if not _boost else Color("7dffff")
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -6), Vector2(-12 - len, 0), Vector2(-12, 6)]), flame_color)
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -3), Vector2(-12 - len * 0.6, 0), Vector2(-12, 3)]), Color.WHITE)
	match variant:
		"syntiq":
			# clean, technical: slim dart with sensor fins and glowing panel lines
			draw_colored_polygon(PackedVector2Array([Vector2(22, 0), Vector2(-10, -11), Vector2(-14, -4), Vector2(-14, 4), Vector2(-10, 11)]), body)
			draw_colored_polygon(PackedVector2Array([Vector2(-4, -11), Vector2(-16, -17), Vector2(-14, -8)]), dark)
			draw_colored_polygon(PackedVector2Array([Vector2(-4, 11), Vector2(-16, 17), Vector2(-14, 8)]), dark)
			draw_line(Vector2(16, 0), Vector2(-8, 0), light, 1.5)
			draw_line(Vector2(4, -5), Vector2(-8, -5), light, 1.0)
			draw_line(Vector2(4, 5), Vector2(-8, 5), light, 1.0)
			draw_circle(Vector2(4, 0), 3.5, Color("e8fbff"))
			draw_rect(Rect2(-6, -2, 4, 4), Color("7dffff"))
		"bad_idea":
			# improvised and chunky: boxy hull, mismatched plating, two big engines, duct tape
			draw_colored_polygon(PackedVector2Array([Vector2(18, -3), Vector2(20, 3), Vector2(2, 12), Vector2(-14, 13), Vector2(-16, 4), Vector2(-16, -4), Vector2(-14, -13), Vector2(2, -12)]), body)
			draw_rect(Rect2(-18, -14, 7, 8), dark)
			draw_rect(Rect2(-18, 6, 7, 8), dark)
			draw_rect(Rect2(-4, -9, 9, 6), light.darkened(0.1))
			draw_rect(Rect2(-9, 3, 8, 7), Color("8a8a8a"))
			draw_line(Vector2(-6, -2), Vector2(6, 6), Color("d8c35a"), 2.0)
			draw_line(Vector2(-2, -8), Vector2(2, 10), Color("d8c35a"), 1.5)
			draw_circle(Vector2(8, 0), 4.0, Color("ffe9a8"))
			draw_circle(Vector2(12, -6), 2.0, Color("ff5a5a")) # the big button
		"scrap":
			draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(-6, -12), Vector2(-12, -3), Vector2(-12, 3), Vector2(-6, 12)]), body)
			draw_rect(Rect2(-9, -8, 5, 5), Color("6b5a3a"))
			draw_rect(Rect2(-4, 3, 6, 5), Color("8f7a4f"))
			draw_circle(Vector2(4, 0), 3.0, Color("ff9f1c"))
		"security":
			draw_colored_polygon(PackedVector2Array([Vector2(20, 0), Vector2(-8, -9), Vector2(-14, -14), Vector2(-14, 14), Vector2(-8, 9)]), body)
			draw_line(Vector2(14, 0), Vector2(-10, 0), Color.WHITE, 2.0)
			draw_circle(Vector2(2, 0), 3.5, Color("3a6fff"))
			draw_circle(Vector2(-6, -11), 2.0, Color("ff3b3b") if fmod(_time, 0.6) < 0.3 else Color("3a6fff"))
		"corp":
			draw_colored_polygon(PackedVector2Array([Vector2(22, 0), Vector2(0, -8), Vector2(-16, -16), Vector2(-10, 0), Vector2(-16, 16), Vector2(0, 8)]), body)
			draw_line(Vector2(18, 0), Vector2(-6, 0), light, 1.5)
			draw_circle(Vector2(2, 0), 3.0, Color("f8f8ff"))
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(20, 0), Vector2(-10, -12), Vector2(-6, 0), Vector2(-10, 12)]), body)
			draw_circle(Vector2(2, 0), 3.5, Color.WHITE)
	# weapon direction hint
	draw_line(Vector2(14, 0), Vector2(22, 0), Color.WHITE, 2.0)
	if _shield:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 32, Color(0.5, 0.9, 1.0, 0.75), 2.5)
		draw_circle(Vector2.ZERO, 28.0, Color(0.5, 0.9, 1.0, 0.12))
