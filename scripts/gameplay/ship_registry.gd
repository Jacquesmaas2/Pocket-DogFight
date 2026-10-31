class_name ShipRegistry
extends Node2D
## Container for all ships. Spawning is server-driven and replicated via RPC.

const SHIP_SCENE := preload("res://scenes/ships/ship.tscn")
const AI_INPUT := preload("res://scripts/gameplay/ai_input_source.gd")

signal ship_spawned(ship: Ship)

var _next_ai_id: int = -1


func all_ships() -> Array[Ship]:
	var out: Array[Ship] = []
	for c in get_children():
		if c is Ship:
			out.append(c)
	return out


func find_ship(uid: int) -> Ship:
	for s in all_ships():
		if s.unique_id() == uid:
			return s
	return null


func local_ship() -> Ship:
	return find_ship(Net.local_id())


## Server: spawn a player ship for a peer.
func server_spawn_player(peer_id: int, pos: Vector2, rot: float) -> Ship:
	var p: Dictionary = Net.players.get(peer_id, {})
	var ship_id := str(p.get("ship", "generic"))
	var color_idx := int(p.get("color", 0))
	var pname := str(p.get("name", "Pilot"))
	_spawn_player.rpc(peer_id, ship_id, color_idx, pname, pos, rot)
	return _spawn_player(peer_id, ship_id, color_idx, pname, pos, rot)


@rpc("authority", "reliable", "call_remote")
func _spawn_player(peer_id: int, ship_id: String, color_idx: int, pname: String, pos: Vector2, rot: float) -> Ship:
	var existing := find_ship(peer_id)
	if existing != null:
		existing.name = "Old%d" % existing.get_instance_id()
		existing.peer_id = -99999
		existing.queue_free()
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.name = "P%d" % peer_id
	ship.peer_id = peer_id
	ship.ship_id = ship_id
	ship.stats = Config.ship_stats(ship_id)
	ship.color = Config.player_color(color_idx)
	ship.pilot_name = pname
	ship.global_position = pos
	ship.rotation = rot
	if peer_id == Net.local_id():
		var src := LocalInputSource.new()
		src.touch = MatchManager.instance.touch_controls
		ship.add_child(src)
		ship.input_source = src
	add_child(ship)
	ship.spawn_protection = Config.match_config.spawn_protection
	ship_spawned.emit(ship)
	return ship


## Server: spawn an AI ship (story/encounters). Faction colors are fixed per ship type.
func server_spawn_ai(ship_id: String, pname: String, pos: Vector2, rot: float, team: int, behaviour: String = "fighter") -> Ship:
	var aid := _next_ai_id
	_next_ai_id -= 1
	_spawn_ai.rpc(aid, ship_id, pname, pos, rot, team, behaviour)
	return _spawn_ai(aid, ship_id, pname, pos, rot, team, behaviour)


@rpc("authority", "reliable", "call_remote")
func _spawn_ai(aid: int, ship_id: String, pname: String, pos: Vector2, rot: float, team: int, behaviour: String) -> Ship:
	var ship: Ship = SHIP_SCENE.instantiate()
	ship.name = "AI%d" % absi(aid)
	ship.peer_id = 0
	ship.ai_id = aid
	ship.team = team
	ship.ship_id = ship_id
	ship.stats = Config.ship_stats(ship_id)
	ship.color = _faction_color(ship_id, team)
	ship.pilot_name = pname
	ship.global_position = pos
	ship.rotation = rot
	if Net.is_server():
		var ai := AI_INPUT.new()
		ai.behaviour = behaviour
		ship.add_child(ai)
		ship.input_source = ai
	add_child(ship)
	ship_spawned.emit(ship)
	return ship


func _faction_color(ship_id: String, team: int) -> Color:
	match ship_id:
		"bad_idea": return Color("ff8a3d")
		"syntiq": return Color("4fd1ff")
		"scrap": return Color("c9a24a")
		"security": return Color("5b7cff")
		"corp": return Color("e0e6ff")
	return Config.player_color(team + 3)


func server_remove(uid: int) -> void:
	_remove.rpc(uid)
	_remove(uid)


@rpc("authority", "reliable", "call_remote")
func _remove(uid: int) -> void:
	var s := find_ship(uid)
	if s != null:
		s.queue_free()


func clear_all() -> void:
	for s in all_ships():
		s.queue_free()
