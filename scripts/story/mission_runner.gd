class_name MissionRunner
extends Node
## Runs story missions on top of the normal match systems. Story is hosted offline, so this node is the server.

const MISSION_SCRIPT_PATHS := [
	"res://scripts/story/mission_1_tuesday.gd",
	"res://scripts/story/mission_2_core.gd",
	"res://scripts/story/mission_3_everybody.gd",
	"res://scripts/story/mission_4_wakes_up.gd",
	"res://scripts/story/mission_5_oh.gd",
	"res://scripts/story/mission_6_finale.gd",
]
const MISSION_COUNT := 6
const AIInput := preload("res://scripts/gameplay/ai_input_source.gd")
const MARKER := preload("res://scripts/story/objective_marker.gd")

signal powerup_collected(type: String, ship: Ship)
signal ship_destroyed(ship: Ship, attacker_id: int)

var mission_id: int = -1
var mission: StoryMission
var player: Ship
var loek: Ship
var core_collected: bool = false
var _markers: Array[Node2D] = []
var _rng := RandomNumberGenerator.new()
var _finished: bool = false

@onready var mm: MatchManager = get_parent()


func start_mission(id: int) -> void:
	mission_id = id
	_rng.seed = 100 + id
	var me := Net.local_id()
	Net.players[me]["ship"] = "syntiq"
	Net.players[me]["name"] = "JAX"
	Net.players[me]["color"] = 0
	Net.broadcast_players()
	mm.powerups.enabled = false
	mm.state = MatchManager.State.ACTIVE
	mm._set_state(MatchManager.State.ACTIVE)
	mission = (load(MISSION_SCRIPT_PATHS[id]) as GDScript).new()
	mission.r = self
	mm.hud.call("show_banner", "MISSION %d" % (id + 1), mission.title, 3.0)
	await get_tree().create_timer(0.5).timeout
	await mission.run()


# ---------------------------------------------------------------- helpers for missions
func say(speaker: String, text: String, seconds: float = 3.2) -> void:
	mm.dialogue.say(speaker, text, seconds)


func wait_dialogue() -> void:
	while mm.dialogue.is_busy():
		await get_tree().process_frame


func objective(text: String) -> void:
	mm.hud.call("set_objective", text)
	if text != "":
		mm.hud.call("show_banner", "", "OBJECTIVE UPDATED: " + text.to_upper(), 2.2)


func banner(title: String, sub: String = "", seconds: float = 2.5) -> void:
	mm.hud.call("show_banner", title, sub, seconds)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func spawn_player(pos: Vector2, rot: float = 0.0) -> Ship:
	player = mm.ships.server_spawn_player(Net.local_id(), pos, rot)
	player.team = 1
	player.controllable = true
	return player


func spawn_loek(pos: Vector2, behaviour: String = "escort") -> Ship:
	loek = mm.ships.server_spawn_ai("bad_idea", "LOCO", pos, 0.0, 1, behaviour)
	var ai := loek.input_source as AIInput
	ai.escort_target = player
	ai.aggression = 0.9
	return loek


func spawn_enemies(ship_id: String, count: int, team: int, around: Vector2, spread: float = 300.0, names: String = "Hostile", aggression: float = 0.8) -> Array[Ship]:
	var out: Array[Ship] = []
	for i in count:
		var pos := around + Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(60.0, spread)
		pos = pos.clamp(-mm.arena.half_size + Vector2(120, 120), mm.arena.half_size - Vector2(120, 120))
		var s := mm.ships.server_spawn_ai(ship_id, "%s %d" % [names, i + 1], pos, (Vector2.ZERO - pos).angle(), team)
		(s.input_source as AIInput).aggression = aggression
		s.spawn_protection = 1.0
		VFX.explosion(pos, Color(0.6, 0.8, 1.0), 0.6)
		out.append(s)
	return out


func alive_of_team(team: int) -> int:
	var n := 0
	for s in mm.ships.all_ships():
		if s.team == team and s.alive and s.peer_id == 0:
			n += 1
	return n


func wait_team_dead(team: int) -> void:
	while alive_of_team(team) > 0:
		await get_tree().create_timer(0.3).timeout


func marker(pos: Vector2, label: String = "", color: Color = Color("ffe04a")) -> Node2D:
	var m: Node2D = MARKER.new()
	m.label = label
	m.color = color
	m.global_position = pos
	mm.get_node("FXLayer").add_child(m)
	_markers.append(m)
	return m


func clear_markers() -> void:
	for m in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()


## Waits until the player (alive) is within radius of pos.
func reach(pos: Vector2, radius: float = 120.0) -> void:
	while player == null or not is_instance_valid(player) or not player.alive or player.global_position.distance_to(pos) > radius:
		await get_tree().process_frame


## Race the checkpoints in order; returns true if the player finished before Loek.
func race(checkpoints: Array[Vector2], loek_handicap: float = 0.0) -> bool:
	var ai := loek.input_source as AIInput
	ai.behaviour = "racer"
	ai.waypoints = checkpoints.duplicate()
	ai.waypoint_index = 0
	ai.aggression = 1.0 - loek_handicap
	var player_won := true
	for i in checkpoints.size():
		clear_markers()
		marker(checkpoints[i], "%d / %d" % [i + 1, checkpoints.size()])
		if i + 1 < checkpoints.size():
			marker(checkpoints[i + 1], "", Color(1, 1, 1, 0.3))
		while true:
			if player != null and is_instance_valid(player) and player.alive and player.global_position.distance_to(checkpoints[i]) < 130.0:
				break
			if ai.waypoint_index >= checkpoints.size():
				player_won = false
			await get_tree().process_frame
	clear_markers()
	ai.behaviour = "escort"
	ai.waypoints.clear()
	return player_won and ai.waypoint_index < checkpoints.size()


func anomaly(type: String, pos: Vector2, radius: float = 220.0, strength: float = 900.0) -> AnomalyZone:
	var z := AnomalyZone.new()
	z.type = type
	z.radius = radius
	z.strength = strength
	z.global_position = pos
	mm.add_child(z)
	return z


func wormhole_pair(a: Vector2, b: Vector2) -> void:
	var za := anomaly("wormhole", a, 70.0)
	var zb := anomaly("wormhole", b, 70.0)
	za.partner = zb
	zb.partner = za


func powerup(type: String, pos: Vector2) -> void:
	mm.powerups.server_spawn(100 + _rng.randi_range(0, 100000), type, pos)


func core_pickup(pos: Vector2) -> void:
	core_collected = false
	mm.powerups.server_spawn(999, "core", pos)
	while not core_collected:
		await get_tree().process_frame


func controls_hint(action: String) -> String:
	var touch: bool = Settings.touch_controls_enabled()
	match action:
		"steer": return "Drag the left stick" if touch else "A / D to steer"
		"thrust": return "Push the stick up" if touch else "W to thrust"
		"fire": return "Tap FIRE" if touch else "SPACE to fire"
		"boost": return "Hold BOOST" if touch else "Hold CTRL to boost"
		"missile": return "Tap MSL" if touch else "SHIFT to launch a missile"
	return ""


func finish(success: bool, title: String, sub: String) -> void:
	if _finished:
		return
	_finished = true
	clear_markers()
	if success:
		Game.mission_completed(mission_id)
		Audio.play("win")
	else:
		Audio.play("loss")
	mm.set_story_state(false)
	await wait(0.4)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(UIKit.title(title))
	var l := UIKit.label(sub, 20, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 520
	box.add_child(l)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	if success and mission_id + 1 < MISSION_COUNT:
		row.add_child(UIKit.button("Next Mission", func() -> void: Game.start_story_mission(mission_id + 1), 200))
	row.add_child(UIKit.button("Retry", func() -> void: Game.start_story_mission(mission_id), 160))
	row.add_child(UIKit.button("Menu", func() -> void: Game.return_to_menu(), 160))
	box.add_child(row)
	var panel := UIKit.panel(box)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -160
	panel.offset_bottom = 160
	mm.get_node("UI/Root").add_child(panel)


# ---------------------------------------------------------------- callbacks from match systems
func on_powerup_collected(type: String, ship: Ship) -> void:
	if type == "core" and ship.team == 1:
		core_collected = true
	powerup_collected.emit(type, ship)


func on_ship_destroyed(ship: Ship, attacker_id: int) -> void:
	ship_destroyed.emit(ship, attacker_id)


func ai_respawn_allowed(ship: Ship) -> bool:
	return ship.pilot_name == "LOCO"
