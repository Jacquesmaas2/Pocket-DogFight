class_name MatchManager
extends Node2D
## Authoritative match flow: countdown -> active -> ended -> rematch.
## Server owns the timer, scores, respawns and power-up pickups.

enum State { WAITING, COUNTDOWN, ACTIVE, ENDED }

signal state_changed(state: int)
signal time_changed(time_left: float)
signal scores_changed
signal kill_feed(text: String)
signal missile_lock_warning(active: bool)
signal local_ship_changed(ship: Ship)
signal match_ended(results: Array)

static var instance: MatchManager

var state: int = State.WAITING
var time_left: float = 0.0
var countdown_left: float = 0.0
var respawn_timers: Dictionary = {} # uid -> seconds
var story: bool = false

@onready var ships: ShipRegistry = $Ships
@onready var projectiles: ProjectileManager = $Projectiles
@onready var powerups: PowerUpManager = $PowerUps
@onready var arena: Arena = $Arena
@onready var camera: GameCamera = $Camera2D
@onready var hud: Node = $UI/Root/HUD
@onready var touch_controls: Node = $UI/Root/TouchControls
@onready var dialogue: Node = $UI/Root/Dialogue
@onready var mission_runner: Node = $Story

var _sync_accum: float = 0.0


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	story = Game.current_mission_id >= 0
	camera.set_bounds(arena.half_size)
	ships.ship_spawned.connect(_on_ship_spawned)
	Net.players_changed.connect(_on_players_changed)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	time_left = Config.match_config.match_duration
	if Net.is_server():
		if story:
			mission_runner.call_deferred("start_mission", Game.current_mission_id)
		else:
			# Give remote peers time to load the match scene before spawn RPCs arrive.
			if Net.is_online():
				await get_tree().create_timer(0.8).timeout
			server_begin_match()
	else:
		_request_full_sync.rpc_id(1)


# ---------------------------------------------------------------- flow
func server_begin_match() -> void:
	if not Net.is_server():
		return
	projectiles.clear_all()
	ships.clear_all()
	respawn_timers.clear()
	for id in Net.players:
		Net.players[id]["score"] = 0
		Net.players[id]["kills"] = 0
		Net.players[id]["deaths"] = 0
	Net.broadcast_players()
	var i := 0
	for id in Net.players:
		var sp := arena.spawn_point(i)
		ships.server_spawn_player(id, sp.global_position, sp.rotation)
		i += 1
	if Game.current_mission_id == -2:
		for b in 3:
			var sp := arena.spawn_point(i + b)
			var bot := ships.server_spawn_ai(["generic", "scrap", "corp"][b], ["Bot Benny", "Rusty", "Unit 7"][b], sp.global_position, sp.rotation, 0)
			bot.spawn_protection = Config.match_config.spawn_protection
	powerups.server_reset()
	time_left = Config.match_config.match_duration
	countdown_left = Config.match_config.countdown_seconds
	_set_state(State.COUNTDOWN)


func _set_state(s: int) -> void:
	_rpc_state.rpc(s, time_left, countdown_left)
	_rpc_state(s, time_left, countdown_left)


@rpc("authority", "reliable", "call_remote")
func _rpc_state(s: int, t: float, cd: float) -> void:
	var prev := state
	state = s
	time_left = t
	countdown_left = cd
	for ship in ships.all_ships():
		ship.controllable = state == State.ACTIVE
	if prev != s:
		state_changed.emit(s)
		match s:
			State.ACTIVE:
				Audio.play("countdown_go")
			State.ENDED:
				_show_results()
	time_changed.emit(time_left)


@rpc("any_peer", "reliable")
func _request_full_sync() -> void:
	if not Net.is_server():
		return
	var who := multiplayer.get_remote_sender_id()
	_rpc_state.rpc_id(who, state, time_left, countdown_left)
	for s in ships.all_ships():
		if s.peer_id != 0:
			var p: Dictionary = Net.players.get(s.peer_id, {})
			ships._spawn_player.rpc_id(who, s.peer_id, s.ship_id, int(p.get("color", 0)), s.pilot_name, s.global_position, s.rotation)
		else:
			ships._spawn_ai.rpc_id(who, s.ai_id, s.ship_id, s.pilot_name, s.global_position, s.rotation, s.team, "fighter")
		s._rpc_state.rpc_id(who, s.health, s.missile_ammo, s.alive, s.spawn_protection, s.shield_time, s.rapid_fire_time, s.boost_time, s.overcharge_time)
	powerups.server_sync_to(who)
	# Late joiner during an active match gets a ship.
	if state in [State.COUNTDOWN, State.ACTIVE] and ships.find_ship(who) == null and Net.players.has(who):
		var sp := arena.safe_spawn_point(ships.all_ships())
		ships.server_spawn_player(who, sp.global_position, sp.rotation)


func _physics_process(delta: float) -> void:
	if not Net.is_server():
		return
	match state:
		State.COUNTDOWN:
			var prev := ceili(countdown_left)
			countdown_left -= delta
			if ceili(countdown_left) != prev and countdown_left > 0.0:
				_rpc_tick.rpc(time_left, countdown_left)
				_rpc_tick(time_left, countdown_left)
			if countdown_left <= 0.0:
				_set_state(State.ACTIVE)
		State.ACTIVE:
			if not story:
				time_left -= delta
				if time_left <= 0.0:
					time_left = 0.0
					_set_state(State.ENDED)
					return
			_sync_accum += delta
			if _sync_accum >= 0.5:
				_sync_accum = 0.0
				_rpc_tick.rpc(time_left, countdown_left)
				_rpc_tick(time_left, countdown_left)
			_tick_respawns(delta)
		State.ENDED:
			pass


@rpc("authority", "unreliable_ordered", "call_remote")
func _rpc_tick(t: float, cd: float) -> void:
	time_left = t
	countdown_left = cd
	time_changed.emit(time_left)
	if state == State.COUNTDOWN and cd > 0.0:
		Audio.play("countdown")


func _tick_respawns(delta: float) -> void:
	for uid in respawn_timers.keys():
		respawn_timers[uid] -= delta
		if respawn_timers[uid] <= 0.0:
			respawn_timers.erase(uid)
			var ship := ships.find_ship(uid)
			if ship != null and ship.peer_id != 0:
				var sp := arena.safe_spawn_point(ships.all_ships())
				ship.server_respawn(sp.global_position, sp.rotation)
			elif ship != null and ship.peer_id == 0 and (Game.current_mission_id == -2 or mission_runner.has_method("ai_respawn_allowed") and mission_runner.ai_respawn_allowed(ship)):
				var sp2 := arena.safe_spawn_point(ships.all_ships())
				ship.server_respawn(sp2.global_position, sp2.rotation)


# ---------------------------------------------------------------- combat authority
## Server only. attacker_id 0 = environment.
func apply_damage(target: Ship, amount: int, attacker_id: int, source: String) -> void:
	if not Net.is_server() or state != State.ACTIVE and not story:
		return
	if target.unique_id() == attacker_id:
		return
	var died := target.server_apply_damage(amount, attacker_id)
	_rpc_damage_fx.rpc(target.unique_id())
	_rpc_damage_fx(target.unique_id())
	if died:
		_on_kill(target, attacker_id, source)


@rpc("authority", "reliable", "call_remote")
func _rpc_damage_fx(uid: int) -> void:
	var s := ships.find_ship(uid)
	if s == null:
		return
	s.visual.flash()
	VFX.hit(s.global_position, s.color)
	Audio.play_at("laser_impact", s.global_position, -6.0)
	if s.peer_id == Net.local_id():
		VFX.shake(0.25)


func _on_kill(victim: Ship, attacker_id: int, source: String) -> void:
	if victim.peer_id != 0 and Net.players.has(victim.peer_id):
		Net.players[victim.peer_id]["deaths"] += 1
	if attacker_id > 0 and Net.players.has(attacker_id):
		Net.players[attacker_id]["kills"] += 1
		Net.players[attacker_id]["score"] += Config.match_config.kill_points
	Net.broadcast_players()
	var killer_name := Net.player_name(attacker_id) if attacker_id > 0 else ""
	var killer_ship := ships.find_ship(attacker_id)
	if killer_ship != null:
		killer_name = killer_ship.pilot_name
	var text := ""
	match source:
		"collision": text = "%s flew into something" % victim.pilot_name
		_: text = "%s destroyed %s" % [killer_name, victim.pilot_name] if killer_name != "" else "%s exploded" % victim.pilot_name
	_rpc_kill_feed.rpc(text, attacker_id, victim.unique_id())
	_rpc_kill_feed(text, attacker_id, victim.unique_id())
	if victim.peer_id != 0 or Game.current_mission_id == -2 or (mission_runner.has_method("ai_respawn_allowed") and mission_runner.ai_respawn_allowed(victim)):
		respawn_timers[victim.unique_id()] = Config.match_config.respawn_delay
	if story:
		mission_runner.call("on_ship_destroyed", victim, attacker_id)


@rpc("authority", "reliable", "call_remote")
func _rpc_kill_feed(text: String, attacker_id: int, victim_id: int) -> void:
	kill_feed.emit(text)
	scores_changed.emit()
	if attacker_id == Net.local_id() and victim_id != attacker_id:
		hud.call("kill_confirm")


func _on_players_changed() -> void:
	scores_changed.emit()


func _on_peer_left(id: int) -> void:
	if Net.is_server():
		respawn_timers.erase(id)
		if ships.find_ship(id) != null:
			ships.server_remove(id)
		if Net.is_dedicated and Net.players.is_empty():
			# Empty dedicated server: go back to the waiting lobby for the next group.
			get_tree().call_deferred("change_scene_to_file", "res://scenes/bootstrap/bootstrap.tscn")


func _on_ship_spawned(ship: Ship) -> void:
	ship.controllable = state == State.ACTIVE or story and state != State.ENDED
	if ship.peer_id == Net.local_id():
		camera.target = ship
		local_ship_changed.emit(ship)


# ---------------------------------------------------------------- results / rematch
func _show_results() -> void:
	var results: Array = []
	for id in Net.players:
		var p: Dictionary = Net.players[id]
		results.append({"id": id, "name": p["name"], "score": p["score"], "kills": p["kills"], "deaths": p["deaths"]})
	results.sort_custom(func(a, b) -> bool: return a["score"] > b["score"] or (a["score"] == b["score"] and a["deaths"] < b["deaths"]))
	Game.last_results = results
	if results.size() > 0 and results[0]["id"] == Net.local_id():
		Audio.play("win")
	else:
		Audio.play("loss")
	match_ended.emit(results)


func request_rematch() -> void:
	if Net.is_server():
		server_begin_match()
	else:
		_rpc_request_rematch.rpc_id(1)


@rpc("any_peer", "reliable")
func _rpc_request_rematch() -> void:
	if Net.is_server() and state == State.ENDED:
		server_begin_match()


func local_ship() -> Ship:
	return ships.local_ship()


func set_story_state(active: bool) -> void:
	_set_state(State.ACTIVE if active else State.ENDED)
