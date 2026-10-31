extends Control
## Landscape touch controls: left virtual stick (steer + thrust), right fire/missile/boost buttons.
## Multitouch aware; every control tracks its own pointer index.

var thrust: float = 0.0
var turn: float = 0.0
var boost: bool = false
var fire_primary: bool = false
var _fire_secondary_queued: bool = false

const STICK_RADIUS := 90.0
const BUTTON_RADIUS := 52.0
const MARGIN := 40.0

var _stick_center: Vector2
var _stick_pointer: int = -1
var _stick_vec: Vector2 = Vector2.ZERO
var _buttons: Dictionary = {} # name -> {pos, pointer}


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	visible = Settings.touch_controls_enabled()
	Settings.changed.connect(func() -> void: visible = Settings.touch_controls_enabled())
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := get_viewport_rect().size
	_stick_center = Vector2(MARGIN + STICK_RADIUS + 30, s.y - MARGIN - STICK_RADIUS - 30)
	_buttons = {
		"fire": {"pos": Vector2(s.x - MARGIN - BUTTON_RADIUS - 20, s.y - MARGIN - BUTTON_RADIUS - 20), "pointer": -1},
		"missile": {"pos": Vector2(s.x - MARGIN - BUTTON_RADIUS * 3 - 50, s.y - MARGIN - BUTTON_RADIUS - 10), "pointer": -1},
		"boost": {"pos": Vector2(s.x - MARGIN - BUTTON_RADIUS - 20, s.y - MARGIN - BUTTON_RADIUS * 3 - 60), "pointer": -1},
	}
	queue_redraw()


func consume_fire_secondary() -> bool:
	var v := _fire_secondary_queued
	_fire_secondary_queued = false
	return v


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_press(e.index, e.position)
		else:
			_release(e.index)
		accept_event()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_pointer:
			_update_stick(d.position)
		accept_event()


func _press(index: int, pos: Vector2) -> void:
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		if b["pointer"] == -1 and pos.distance_to(b["pos"]) <= BUTTON_RADIUS * 1.3:
			b["pointer"] = index
			if name == "missile":
				_fire_secondary_queued = true
			_update_buttons()
			queue_redraw()
			return
	if _stick_pointer == -1 and pos.x < get_viewport_rect().size.x * 0.5:
		_stick_pointer = index
		_stick_center = pos if pos.distance_to(_stick_center) > STICK_RADIUS * 1.5 else _stick_center
		_update_stick(pos)


func _release(index: int) -> void:
	if index == _stick_pointer:
		_stick_pointer = -1
		_stick_vec = Vector2.ZERO
		thrust = 0.0
		turn = 0.0
		_layout()
	for name in _buttons:
		if _buttons[name]["pointer"] == index:
			_buttons[name]["pointer"] = -1
	_update_buttons()
	queue_redraw()


func _update_stick(pos: Vector2) -> void:
	_stick_vec = (pos - _stick_center).limit_length(STICK_RADIUS) / STICK_RADIUS
	# Ship-relative mapping: horizontal = turn, vertical/up or magnitude = thrust.
	turn = clampf(_stick_vec.x * 1.4, -1.0, 1.0)
	thrust = clampf(maxf(-_stick_vec.y, _stick_vec.length() * 0.6), 0.0, 1.0)
	queue_redraw()


func _update_buttons() -> void:
	fire_primary = _buttons["fire"]["pointer"] != -1
	boost = _buttons["boost"]["pointer"] != -1


func _draw() -> void:
	draw_circle(_stick_center, STICK_RADIUS, Color(1, 1, 1, 0.08))
	draw_arc(_stick_center, STICK_RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
	draw_circle(_stick_center + _stick_vec * STICK_RADIUS, 34.0, Color(0.5, 0.85, 1.0, 0.55 if _stick_pointer != -1 else 0.3))
	var labels := {"fire": ["FIRE", Color("4fd1ff")], "missile": ["MSL", Color("ff8a3d")], "boost": ["BOOST", Color("7dffb3")]}
	for name in _buttons:
		var b: Dictionary = _buttons[name]
		var c: Color = labels[name][1]
		var active: bool = b["pointer"] != -1
		draw_circle(b["pos"], BUTTON_RADIUS, Color(c.r, c.g, c.b, 0.55 if active else 0.22))
		draw_arc(b["pos"], BUTTON_RADIUS, 0, TAU, 32, c, 3.0)
		var font := ThemeDB.fallback_font
		var text: String = labels[name][0]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20).x
		draw_string(font, b["pos"] + Vector2(-w / 2, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
