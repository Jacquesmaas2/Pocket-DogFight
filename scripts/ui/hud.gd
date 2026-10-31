extends Control
## In-match HUD: timer, health, missiles, score, scoreboard, warnings, respawn countdown, kill feed.

var _ship: Ship
var _timer_label: Label
var _health_box: HBoxContainer
var _missile_label: Label
var _score_label: Label
var _center_label: Label
var _sub_label: Label
var _warning_label: Label
var _feed: VBoxContainer
var _scoreboard: PanelContainer
var _scoreboard_list: VBoxContainer
var _effects_label: Label
var _objective_label: Label
var _warn_blink := 0.0
var _center_timer := 0.0

@onready var mm: MatchManager = MatchManager.instance


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	_build()
	mm.time_changed.connect(_on_time)
	mm.state_changed.connect(_on_state)
	mm.scores_changed.connect(_refresh_scores)
	mm.kill_feed.connect(_on_kill_feed)
	mm.local_ship_changed.connect(_bind_ship)
	mm.missile_lock_warning.connect(func(_a: bool) -> void: pass)
	_refresh_scores()


func _build() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_preset(PRESET_TOP_WIDE)
	top.offset_top = 10
	top.offset_left = 24
	top.offset_right = -24
	top.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(top)
	_score_label = UIKit.label("0", 26, UIKit.ACCENT)
	_score_label.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(_score_label)
	_timer_label = UIKit.label("3:00", 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_timer_label.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(_timer_label)
	_missile_label = UIKit.label("", 26, UIKit.ACCENT2, HORIZONTAL_ALIGNMENT_RIGHT)
	_missile_label.size_flags_horizontal = SIZE_EXPAND_FILL
	top.add_child(_missile_label)

	_health_box = HBoxContainer.new()
	_health_box.set_anchors_preset(PRESET_CENTER_TOP)
	_health_box.offset_top = 54
	_health_box.offset_left = -60
	_health_box.offset_right = 60
	_health_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_health_box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_health_box)

	_effects_label = UIKit.label("", 18, Color("7dffb3"), HORIZONTAL_ALIGNMENT_CENTER)
	_effects_label.set_anchors_preset(PRESET_CENTER_TOP)
	_effects_label.offset_top = 86
	_effects_label.offset_left = -300
	_effects_label.offset_right = 300
	add_child(_effects_label)

	_objective_label = UIKit.label("", 20, Color("ffe04a"))
	_objective_label.set_anchors_preset(PRESET_TOP_LEFT)
	_objective_label.offset_top = 48
	_objective_label.offset_left = 24
	_objective_label.offset_right = 600
	add_child(_objective_label)

	_center_label = UIKit.label("", 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_center_label.set_anchors_preset(PRESET_CENTER)
	_center_label.offset_left = -400
	_center_label.offset_right = 400
	_center_label.offset_top = -120
	_center_label.offset_bottom = -20
	add_child(_center_label)
	_sub_label = UIKit.label("", 26, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	_sub_label.set_anchors_preset(PRESET_CENTER)
	_sub_label.offset_left = -400
	_sub_label.offset_right = 400
	_sub_label.offset_top = -20
	_sub_label.offset_bottom = 30
	add_child(_sub_label)

	_warning_label = UIKit.label("", 30, Color("ff5a5a"), HORIZONTAL_ALIGNMENT_CENTER)
	_warning_label.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_warning_label.offset_left = -300
	_warning_label.offset_right = 300
	_warning_label.offset_top = -170
	_warning_label.offset_bottom = -130
	add_child(_warning_label)

	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(PRESET_TOP_RIGHT)
	_feed.offset_top = 90
	_feed.offset_left = -520
	_feed.offset_right = -24
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_feed)

	_scoreboard_list = VBoxContainer.new()
	_scoreboard = UIKit.panel(_scoreboard_list)
	_scoreboard.set_anchors_preset(PRESET_CENTER)
	_scoreboard.offset_left = -220
	_scoreboard.offset_right = 220
	_scoreboard.offset_top = -160
	_scoreboard.offset_bottom = 160
	_scoreboard.visible = false
	add_child(_scoreboard)


func _bind_ship(ship: Ship) -> void:
	_ship = ship
	ship.health_changed.connect(_on_health)
	ship.ammo_changed.connect(_on_ammo)
	ship.effects_changed.connect(_refresh_effects)
	_on_health(ship.health, ship.stats.max_health)
	_on_ammo(ship.missile_ammo)


func _process(delta: float) -> void:
	_warn_blink += delta
	if _center_timer > 0.0:
		_center_timer -= delta
		if _center_timer <= 0.0:
			_center_label.text = ""
			_sub_label.text = ""
	if _ship != null and is_instance_valid(_ship):
		if not _ship.alive and mm.respawn_timers.size() >= 0:
			var t: float = mm.respawn_timers.get(_ship.unique_id(), -1.0)
			if mm.state == MatchManager.State.ACTIVE:
				_center_label.text = "DESTROYED"
				_sub_label.text = "Respawning in %d" % ceili(maxf(t, 0.0)) if t >= 0.0 else "Respawning..."
				_center_timer = 0.1
		var locked := mm.projectiles.any_missile_targeting(_ship.unique_id())
		if locked and fmod(_warn_blink, 0.4) < 0.2:
			_warning_label.text = "!! MISSILE LOCK !!"
			if fmod(_warn_blink, 0.4) < 0.03:
				Audio.play("missile_warning", -8.0)
		else:
			_warning_label.text = ""
		_refresh_effects()
	_scoreboard.visible = Input.is_action_pressed("scoreboard") or mm.state == MatchManager.State.COUNTDOWN and not mm.story


func _on_time(t: float) -> void:
	if mm.story:
		_timer_label.text = ""
		return
	_timer_label.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	if mm.state == MatchManager.State.COUNTDOWN:
		var n := ceili(mm.countdown_left)
		_center_label.text = str(n) if n > 0 else "GO!"
		_sub_label.text = "Get ready, %s" % Settings.player_name
		_center_timer = 1.5


func _on_state(s: int) -> void:
	match s:
		MatchManager.State.ACTIVE:
			_center_label.text = "GO!"
			_sub_label.text = ""
			_center_timer = 0.8
		MatchManager.State.ENDED:
			_center_label.text = ""
			_sub_label.text = ""
			_warning_label.text = ""


func _on_health(cur: int, maximum: int) -> void:
	for c in _health_box.get_children():
		c.queue_free()
	for i in maximum:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(34, 14)
		r.color = Color("7dff6a") if i < cur else Color(1, 1, 1, 0.15)
		_health_box.add_child(r)


func _on_ammo(count: int) -> void:
	_missile_label.text = "MISSILES %s" % ("●".repeat(count) if count > 0 else "—")


func _refresh_effects() -> void:
	if _ship == null or not is_instance_valid(_ship):
		return
	var parts: PackedStringArray = []
	if _ship.shield_time > 0.0: parts.append("SHIELD %.0f" % _ship.shield_time)
	if _ship.rapid_fire_time > 0.0: parts.append("RAPID FIRE %.0f" % _ship.rapid_fire_time)
	if _ship.boost_time > 0.0: parts.append("BOOST %.0f" % _ship.boost_time)
	if _ship.overcharge_time > 0.0: parts.append("OVERCHARGE %.0f" % _ship.overcharge_time)
	if _ship.spawn_protection > 0.0: parts.append("PROTECTED")
	_effects_label.text = "  ".join(parts)


func _refresh_scores() -> void:
	var me: Dictionary = Net.players.get(Net.local_id(), {})
	_score_label.text = "SCORE %d" % int(me.get("score", 0)) if not mm.story else ""
	for c in _scoreboard_list.get_children():
		c.queue_free()
	_scoreboard_list.add_child(UIKit.label("SCOREBOARD", 24, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var rows: Array = []
	for id in Net.players:
		rows.append([id, Net.players[id]])
	rows.sort_custom(func(a, b) -> bool: return a[1]["score"] > b[1]["score"])
	for r in rows:
		var p: Dictionary = r[1]
		var l := UIKit.label("%-14s %3d   K%d D%d" % [p["name"], p["score"], p["kills"], p["deaths"]], 20, Net.player_color(r[0]))
		_scoreboard_list.add_child(l)


func _on_kill_feed(text: String) -> void:
	var l := UIKit.label(text, 18, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)
	_feed.add_child(l)
	if _feed.get_child_count() > 4:
		_feed.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func kill_confirm() -> void:
	_center_label.text = "KILL!"
	_sub_label.text = "+%d" % Config.match_config.kill_points
	_center_timer = 0.9
	VFX.shake(0.15)


func show_pickup(type: String) -> void:
	_sub_label.text = type.to_upper().replace("_", " ")
	_center_timer = 0.9


func set_objective(text: String) -> void:
	_objective_label.text = ("OBJECTIVE: " + text) if text != "" else ""


func show_banner(title: String, sub: String, seconds: float = 2.5) -> void:
	_center_label.text = title
	_sub_label.text = sub
	_center_timer = seconds
