extends StoryMission
## Finale - Race You: beat Loek to the Core through a gate battle.


func _init() -> void:
	title = "Finale: Race You"


func run() -> void:
	var A := r.mm.arena
	r.mm.powerups.enabled = true
	r.mm.powerups.server_reset()
	await r.spawn_player(Vector2(-A.half_size.x + 300, 0), 0.0)
	r.spawn_loek(Vector2(-A.half_size.x + 300, 120), "escort")
	r.anomaly("gravity", Vector2(200, 300), 220.0, 900.0)
	r.wormhole_pair(Vector2(-300, -600), Vector2(700, 500))
	r.spawn_enemies("security", 3, 3, Vector2(300, -500), 300.0, "Officer", 0.6)
	r.spawn_enemies("corp", 3, 4, Vector2(600, 400), 300.0, "Interceptor", 0.6)
	r.spawn_enemies("scrap", 3, 2, Vector2(-200, 600), 300.0, "Rat", 0.6)
	r.say("jax", "The Core can close the gate. Someone has to physically reach it.", 3.2)
	r.say("loco", "Race you.", 1.5)
	r.say("jax", "Loek...", 1.5)
	await r.wait(3.5)
	r.banner("FINAL OBJECTIVE", "BEAT LOEK TO THE CORE", 3.0)
	r.objective("Beat Loek to the Core")
	var cps: Array[Vector2] = [
		Vector2(-700, -300), Vector2(-100, -650), Vector2(500, -300), Vector2(900, 200),
		Vector2(300, 650), Vector2(-500, 450), Vector2(A.half_size.x - 300, -A.half_size.y + 300),
	]
	r.marker(cps[cps.size() - 1], "THE CORE", Color("c2f0ff"))
	var won := await r.race(cps, 0.05)
	r.clear_markers()
	VFX.explosion(cps[cps.size() - 1], Color("c2f0ff"), 3.0)
	VFX.shake(1.2)
	Audio.play("explosion")
	for s in r.mm.ships.all_ships():
		if s.peer_id == 0 and s.team != 1:
			r.mm.ships.server_remove(s.unique_id())
	r.banner("GATE CLOSED", "", 2.5)
	await r.wait(1.5)
	r.say("loco", "Technically I won.", 2.0)
	r.say("jax", "Your ship is on fire.", 2.0)
	r.say("loco", "Still counts.", 2.0)
	await r.wait(6.5)
	r.banner("", "UNKNOWN SIGNAL DETECTED.", 3.0)
	Audio.play("missile_warning", -4.0)
	await r.wait(3.0)
	var ending := "You reached the Core first. Loek insists it was a tie." if won else "Loek reached the Core first. He will never let this go."
	await r.finish(true, "CUT TO BLACK", ending + "\n\nThey survive. Barely. The Core disappears. Their ships are wrecked.")
