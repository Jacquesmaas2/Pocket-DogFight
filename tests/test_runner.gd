extends Node
## Headless validation. Run:
##   godot --headless res://tests/test_runner.tscn                  (single-instance tests)
##   godot --headless res://tests/test_runner.tscn -- --net=host     (two-instance test, host side)
##   godot --headless res://tests/test_runner.tscn -- --net=client   (two-instance test, client side)
## Exit code 0 = all passed.

var _fails: int = 0
var _passes: int = 0
var _net_mode: String = ""
var _net_transport: String = "enet"
var _detached: bool = false
const NET_PORT := 24599


func _ready() -> void:
	if not _detached:
		# Re-home under the root so scene changes (Game.goto) cannot free the runner.
		var copy: Node = duplicate()
		copy.set("_detached", true)
		get_tree().root.add_child.call_deferred(copy)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net="):
			_net_mode = a.get_slice("=", 1)
		elif a.begins_with("--transport="):
			_net_transport = a.get_slice("=", 1)
	if _net_mode != "":
		await _run_network_test()
	else:
		await _run_local_tests()
	print("\nRESULT: %d passed, %d failed" % [_passes, _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("  PASS  " + label)
	else:
		_fails += 1
		print("  FAIL  " + label)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Reads @rpc annotations from a node's script source (works on all 4.x builds).
func _rpc_config(node: Node) -> Dictionary:
	var out := {}
	var src: String = (node.get_script() as GDScript).source_code
	var regex := RegEx.new()
	regex.compile("@rpc\\(([^\\)]*)\\)\\s*\\nfunc\\s+(\\w+)")
	for m in regex.search_all(src):
		var args: String = m.get_string(1)
		var mode := MultiplayerAPI.RPC_MODE_AUTHORITY
		if args.contains("\"any_peer\""):
			mode = MultiplayerAPI.RPC_MODE_ANY_PEER
		out[m.get_string(2)] = {"rpc_mode": mode}
	return out


# ---------------------------------------------------------------- local
func _run_local_tests() -> void:
	print("== Resources & scenes ==")
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/bootstrap/bootstrap.tscn", "main scene configured")
	for p in ["res://scenes/bootstrap/bootstrap.tscn", "res://scenes/ui/main_menu.tscn", "res://scenes/ui/lobby.tscn", "res://scenes/game/match.tscn", "res://scenes/arenas/asteroid_belt.tscn", "res://scenes/ships/ship.tscn", "res://scenes/projectiles/laser.tscn", "res://scenes/projectiles/missile.tscn", "res://scenes/powerups/powerup.tscn", "res://scenes/effects/explosion.tscn", "res://scenes/effects/hit_flash.tscn", "res://scenes/story/story_select.tscn"]:
		check(ResourceLoader.exists(p) and load(p) != null, "scene loads: " + p)
	for id in Config.SHIP_PATHS:
		check(Config.ship_stats(id) != null and Config.ship_stats(id).max_health > 0, "ship stats: " + id)
	check(Config.laser.damage == 1 and Config.missile.damage == 2, "weapon damage from resources")
	check(Config.match_config.match_duration > 0.0, "match config loaded")
	check(AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Music") >= 0, "audio buses exist")

	print("== Match (offline host) ==")
	await frames(1)
	Net.host_offline(false)
	Game.current_mission_id = -1
	var match_scene: Node = load("res://scenes/game/match.tscn").instantiate()
	get_tree().root.add_child(match_scene)
	await frames(5)
	var mm: MatchManager = MatchManager.instance
	check(mm != null and mm.state == MatchManager.State.COUNTDOWN, "match starts in COUNTDOWN")
	var ship := mm.ships.local_ship()
	check(ship != null, "local ship spawned")
	check(ship.weapons != null and ship.weapons.primary_ratio() >= 0.99, "weapons initialized")
	check(ship.health == ship.stats.max_health, "ship health initialized")
	check(not ship.can_act(), "no control during countdown")
	mm.countdown_left = 0.0
	await frames(3)
	check(mm.state == MatchManager.State.ACTIVE, "COUNTDOWN -> ACTIVE")
	check(ship.can_act(), "control enabled when ACTIVE")

	print("== Movement ==")
	var fake := InputSource.new()
	fake.input.thrust = 1.0
	ship.input_source.queue_free()
	ship.input_source = fake
	ship.add_child(fake)
	var start := ship.global_position
	await frames(20)
	check(ship.velocity.length() > 50.0 and ship.global_position != start, "thrust produces movement")
	fake.input.thrust = 0.0
	fake.input.turn = 1.0
	var rot := ship.rotation
	await frames(10)
	check(ship.rotation != rot, "turn rotates the ship")
	fake.input.turn = 0.0

	print("== Combat authority ==")
	var before := mm.projectiles.get_child_count()
	ship.weapons.server_fire("laser", ship.global_position, ship.rotation)
	await frames(1)
	check(mm.projectiles.get_child_count() == before + 1, "server_fire spawns a laser")
	ship.weapons.server_fire("laser", ship.global_position, ship.rotation)
	await frames(1)
	check(mm.projectiles.get_child_count() == before + 1, "server cooldown rejects rapid second shot")
	ship.spawn_protection = 0.0
	var h := ship.health
	mm.apply_damage(ship, 1, 0, "laser")
	check(ship.health == h - 1, "damage applied exactly once")
	mm.apply_damage(ship, 1, ship.unique_id(), "laser")
	check(ship.health == h - 1, "self damage rejected")
	ship.shield_time = 5.0
	mm.apply_damage(ship, 1, 0, "laser")
	check(ship.health == h - 1, "shield blocks damage")
	ship.shield_time = 0.0
	mm.apply_damage(ship, 99, 0, "laser")
	check(not ship.alive and not ship.can_act(), "death disables control")
	check(mm.respawn_timers.has(ship.unique_id()), "respawn scheduled")
	check(Net.players[Net.local_id()]["deaths"] == 1, "death counted")
	mm.respawn_timers[ship.unique_id()] = 0.0
	await frames(3)
	check(ship.alive and ship.health == ship.stats.max_health and ship.spawn_protection > 0.0, "respawn restores state with protection")

	print("== Missiles & power-ups ==")
	var bot := mm.ships.server_spawn_ai("scrap", "Target", ship.global_position + ship.forward() * 400.0, 0.0, 0)
	await frames(1)
	check(mm.projectiles.find_missile_target(ship) == bot.unique_id(), "missile target selection picks ship in cone")
	var ammo := ship.missile_ammo
	ship.weapons.server_fire("missile", ship.global_position, ship.rotation)
	await frames(1)
	check(ship.missile_ammo == ammo - 1, "missile consumes ammo")
	check(mm.projectiles.any_missile_targeting(bot.unique_id()), "missile lock registered")
	mm.powerups.server_spawn(0, "shield", ship.global_position + Vector2(5000, 5000))
	await frames(1)
	var pu: PowerUp = mm.powerups.get_child(mm.powerups.get_child_count() - 1)
	mm.powerups.server_try_collect(pu, ship)
	check(ship.shield_time > 0.0, "shield power-up applied authoritatively")

	print("== Scoring & match end ==")
	bot.spawn_protection = 0.0
	mm.apply_damage(bot, 99, ship.unique_id(), "laser")
	check(Net.players[Net.local_id()]["score"] == 1, "kill awards 1 point")
	mm.time_left = 0.01
	await frames(3)
	check(mm.state == MatchManager.State.ENDED, "timer expiry -> ENDED")
	check(Game.last_results.size() > 0 and Game.last_results[0]["id"] == Net.local_id(), "results computed")
	mm.request_rematch()
	await frames(3)
	check(mm.state == MatchManager.State.COUNTDOWN and Net.players[Net.local_id()]["score"] == 0, "rematch resets to COUNTDOWN with zero score")

	print("== RPC authority configuration ==")
	ship = mm.ships.local_ship()
	var cfg: Dictionary = _rpc_config(ship)
	for m in ["_rpc_state", "_rpc_died", "_rpc_respawn"]:
		check(cfg.has(m) and cfg[m]["rpc_mode"] == MultiplayerAPI.RPC_MODE_AUTHORITY, "ship.%s is authority-only" % m)
	check(cfg["_net_transform"]["rpc_mode"] == MultiplayerAPI.RPC_MODE_ANY_PEER, "ship._net_transform any_peer (owner-filtered in code)")
	var mcfg: Dictionary = _rpc_config(mm)
	check(mcfg["_rpc_state"]["rpc_mode"] == MultiplayerAPI.RPC_MODE_AUTHORITY, "match._rpc_state authority-only")
	var pcfg: Dictionary = _rpc_config(mm.projectiles)
	check(pcfg["_spawn"]["rpc_mode"] == MultiplayerAPI.RPC_MODE_AUTHORITY and pcfg["_despawn"]["rpc_mode"] == MultiplayerAPI.RPC_MODE_AUTHORITY, "projectile spawn/despawn authority-only")

	print("== Mobile UI ==")
	var tc: Control = mm.touch_controls
	check(tc.anchor_right == 1.0 and tc.anchor_bottom == 1.0, "touch controls anchored full-rect")
	tc._layout()
	var vp := tc.get_viewport_rect().size
	var ok := true
	for b in tc._buttons.values():
		var p: Vector2 = b["pos"]
		ok = ok and p.x > 0 and p.y > 0 and p.x < vp.x and p.y < vp.y and p.x > vp.x * 0.5
	check(ok and tc._stick_center.x < vp.x * 0.5, "touch buttons right side, stick left side, inside viewport")

	print("== Story ==")
	match_scene.queue_free()
	await frames(2)
	Net.host_offline(true)
	Game.current_mission_id = 0
	var story_scene: Node = load("res://scenes/game/match.tscn").instantiate()
	get_tree().root.add_child(story_scene)
	await get_tree().create_timer(2.0).timeout
	var smm: MatchManager = MatchManager.instance
	check(smm.story and smm.ships.local_ship() != null and smm.ships.local_ship().ship_id == "syntiq", "story mission 1 spawns Jacques in The Syntiq")
	check(smm.ships.find_ship(-1) != null and smm.ships.find_ship(-1).pilot_name == "LOCO", "Loek AI wingman spawned")
	check(smm.state == MatchManager.State.ACTIVE and smm.ships.local_ship().can_act(), "story mission is immediately playable")
	story_scene.queue_free()
	await frames(2)
	# Smoke-run every mission for a few seconds to surface runtime script errors.
	for mid in range(1, MissionRunner.MISSION_COUNT):
		Net.host_offline(true)
		Game.current_mission_id = mid
		var sc: Node = load("res://scenes/game/match.tscn").instantiate()
		get_tree().root.add_child(sc)
		await get_tree().create_timer(3.0).timeout
		var m: MatchManager = MatchManager.instance
		var ok := m != null and m.story and m.ships.local_ship() != null and m.ships.all_ships().size() >= 2
		check(ok, "story mission %d boots with player + AI (%d ships)" % [mid + 1, m.ships.all_ships().size() if m != null else 0])
		sc.queue_free()
		await frames(2)


# ---------------------------------------------------------------- network (two instances)
func _run_network_test() -> void:
	Net.port = NET_PORT
	Net.transport = _net_transport
	if _net_mode == "host":
		Settings.player_name = "HostPilot"
		check(Net.host(_net_transport) == OK, "host opened %s server" % _net_transport)
		var waited := 0.0
		while Net.players.size() < 2 and waited < 20.0:
			await get_tree().create_timer(0.2).timeout
			waited += 0.2
		check(Net.players.size() == 2, "client registered in player list")
		Game.current_mission_id = -1
		Game.start_match()
		await get_tree().create_timer(1.0).timeout
		var mm: MatchManager = MatchManager.instance
		waited = 0.0
		while (mm == null or mm.ships.all_ships().size() < 2) and waited < 10.0:
			await get_tree().create_timer(0.2).timeout
			waited += 0.2
			mm = MatchManager.instance
		check(mm.ships.all_ships().size() == 2, "host sees both ships")
		mm.countdown_left = 0.0
		await frames(3)
		var client_id := 0
		for id in Net.players:
			if id != 1:
				client_id = id
		var cs := mm.ships.find_ship(client_id)
		cs.spawn_protection = 0.0
		mm.apply_damage(cs, 99, 1, "laser")
		check(Net.players[1]["score"] == 1, "host awarded kill")
		await get_tree().create_timer(2.0).timeout
		# wait for client to leave
		waited = 0.0
		while Net.players.size() > 1 and waited < 10.0:
			await get_tree().create_timer(0.2).timeout
			waited += 0.2
		check(Net.players.size() == 1, "disconnect removed client from player list")
		await frames(3)
		check(mm.ships.find_ship(client_id) == null, "disconnected client's ship removed")
	else:
		Settings.player_name = "ClientPilot"
		await get_tree().create_timer(1.0).timeout
		var addr := "enet://127.0.0.1:%d" % NET_PORT if _net_transport == "enet" else "ws://127.0.0.1:%d" % NET_PORT
		check(Net.join(addr) == OK, "client join initiated (%s)" % addr)
		var waited := 0.0
		while Net.players.size() < 2 and waited < 20.0:
			await get_tree().create_timer(0.2).timeout
			waited += 0.2
		check(Net.players.size() == 2, "client received player list with both players")
		waited = 0.0
		while (MatchManager.instance == null or MatchManager.instance.ships.all_ships().size() < 2) and waited < 15.0:
			await get_tree().create_timer(0.2).timeout
			waited += 0.2
		var mm: MatchManager = MatchManager.instance
		check(mm != null and mm.ships.all_ships().size() == 2, "client sees both ships")
		var me := mm.ships.local_ship()
		waited = 0.0
		while me != null and me.alive and waited < 10.0:
			await get_tree().create_timer(0.2).timeout
			waited += 0.2
		check(me != null and not me.alive, "client ship death replicated from host")
		check(Net.players[1]["score"] == 1, "score replicated: host has 1 point")
		Net.leave()
		await get_tree().create_timer(0.5).timeout
