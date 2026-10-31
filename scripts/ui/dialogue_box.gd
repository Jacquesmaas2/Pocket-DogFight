extends Control
## Radio-style dialogue strip with procedural pilot portraits. Never blocks gameplay.

var _name_label: Label
var _text_label: Label
var _portrait: Control
var _queue: Array = []
var _timer: float = 0.0
var _speaker: String = ""


func _ready() -> void:
	set_anchors_preset(PRESET_BOTTOM_WIDE)
	offset_top = -150
	offset_bottom = -16
	offset_left = 200
	offset_right = -200
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false
	var row := HBoxContainer.new()
	row.set_anchors_preset(PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 14)
	_portrait = Control.new()
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.draw.connect(_draw_portrait)
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = SIZE_EXPAND_FILL
	_name_label = UIKit.label("", 18, UIKit.ACCENT)
	_text_label = UIKit.label("", 22)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = SIZE_EXPAND_FILL
	col.add_child(_name_label)
	col.add_child(_text_label)
	row.add_child(col)
	var panel := UIKit.panel(row)
	panel.set_anchors_preset(PRESET_FULL_RECT)
	add_child(panel)


func say(speaker: String, text: String, seconds: float = 3.2) -> void:
	_queue.append([speaker, text, seconds])
	if not visible:
		_next()


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer <= 0.0:
		_next()


func _next() -> void:
	if _queue.is_empty():
		visible = false
		return
	var item: Array = _queue.pop_front()
	_speaker = item[0]
	_name_label.text = _display_name(_speaker)
	_name_label.add_theme_color_override("font_color", _speaker_color(_speaker))
	_text_label.text = item[1]
	_timer = item[2]
	visible = true
	_portrait.queue_redraw()
	Audio.play("ui_click", -12.0)


func is_busy() -> bool:
	return visible or not _queue.is_empty()


func _display_name(s: String) -> String:
	match s:
		"jax": return "JACQUES  ·  JAX  ·  The Syntiq"
		"loco": return "LOEK  ·  LOCO  ·  The Bad Idea"
		"sec": return "GALACTIC SECURITY"
		"rats": return "SCRAP RATS"
		"corp": return "CORPORATION"
		"sys": return "SHIP COMPUTER"
	return s.to_upper()


func _speaker_color(s: String) -> Color:
	match s:
		"jax": return Color("4fd1ff")
		"loco": return Color("ff8a3d")
		"sec": return Color("5b7cff")
		"rats": return Color("c9a24a")
		"corp": return Color("e0e6ff")
	return Color("ffe04a")


func _draw_portrait() -> void:
	var c := _portrait
	var r := Rect2(Vector2.ZERO, c.size)
	c.draw_rect(r, Color(0.02, 0.03, 0.08, 1.0))
	c.draw_rect(r, _speaker_color(_speaker), false, 3.0)
	var center := c.size / 2
	match _speaker:
		"jax":
			# Jacques: silver swept-back hair, navy sweater, big grin, clean shaven
			c.draw_rect(Rect2(center.x - 30, center.y + 22, 60, 30), Color("1f2a5a"))
			c.draw_circle(center + Vector2(0, 2), 24, Color("e8b894"))
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-26, -8), center + Vector2(-20, -30), center + Vector2(10, -34), center + Vector2(28, -16), center + Vector2(26, -4), center + Vector2(14, -14), center + Vector2(-8, -18)]), Color("d9dde3"))
			c.draw_circle(center + Vector2(-9, -2), 2.5, Color.BLACK)
			c.draw_circle(center + Vector2(9, -2), 2.5, Color.BLACK)
			c.draw_arc(center + Vector2(0, 6), 11, 0.2, PI - 0.2, 12, Color("7a2b2b"), 3.0)
			c.draw_rect(Rect2(center.x - 8, center.y + 8, 16, 4), Color.WHITE)
		"loco":
			# Loek: short grey-blond hair, grey stubble, light-blue tee under black jacket, thumbs up
			c.draw_rect(Rect2(center.x - 32, center.y + 20, 64, 32), Color("151515"))
			c.draw_rect(Rect2(center.x - 12, center.y + 20, 24, 32), Color("7fa6c9"))
			c.draw_circle(center + Vector2(0, 2), 24, Color("e3b391"))
			c.draw_circle(center + Vector2(0, 12), 18, Color(0.55, 0.55, 0.55, 0.35))
			c.draw_arc(center + Vector2(0, -6), 24, PI + 0.3, TAU - 0.3, 16, Color("bdb79f"), 7.0)
			c.draw_circle(center + Vector2(-9, -2), 2.5, Color.BLACK)
			c.draw_circle(center + Vector2(9, -2), 2.5, Color.BLACK)
			c.draw_arc(center + Vector2(0, 5), 12, 0.3, PI - 0.3, 12, Color("6b2a2a"), 3.0)
			c.draw_rect(Rect2(center.x + 24, center.y + 14, 12, 18), Color("e3b391"))
			c.draw_rect(Rect2(center.x + 27, center.y + 4, 6, 12), Color("e3b391"))
		"sec":
			c.draw_rect(Rect2(center.x - 22, center.y - 26, 44, 52), Color("2b3a80"))
			c.draw_rect(Rect2(center.x - 16, center.y - 14, 32, 14), Color("8fb6ff"))
		"rats":
			c.draw_circle(center, 24, Color("6b5a3a"))
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(-22, -10), center + Vector2(-12, -34), center + Vector2(-4, -12)]), Color("6b5a3a"))
			c.draw_colored_polygon(PackedVector2Array([center + Vector2(22, -10), center + Vector2(12, -34), center + Vector2(4, -12)]), Color("6b5a3a"))
			c.draw_circle(center + Vector2(-8, -2), 3, Color("ffd23f"))
			c.draw_circle(center + Vector2(8, -2), 3, Color("ffd23f"))
		"corp":
			c.draw_rect(Rect2(center.x - 20, center.y - 24, 40, 48), Color("dfe5ff"))
			c.draw_rect(Rect2(center.x - 20, center.y - 24, 40, 10), Color("8a94c0"))
		_:
			c.draw_circle(center, 20, Color("ffe04a"))
			c.draw_arc(center, 28, 0, TAU, 24, Color("ffe04a"), 2.0)
