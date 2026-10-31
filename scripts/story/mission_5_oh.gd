extends StoryMission
## Mission 5 - Oh.: an enormous unidentified ship arrives; every faction fights it (and you).

const LEVIATHAN := preload("res://scripts/story/leviathan.gd")


func _init() -> void:
	title = "Oh."


func run() -> void:
	var A := r.mm.arena
	r.mm.powerups.enabled = true
	r.mm.powerups.server_reset()
	await r.spawn_player(Vector2(-A.half_size.x + 400, 200), 0.0)
	r.spawn_loek(Vector2(-A.half_size.x + 400, 330), "escort")
	r.spawn_enemies("security", 2, 3, Vector2(600, -400), 200.0, "Officer", 0.7)
	r.spawn_enemies("scrap", 2, 2, Vector2(600, 400), 200.0, "Rat", 0.7)
	r.objective("Hold position")
	await r.wait(4.0)
	r.say("sys", "Gate activation detected. Mass: large. Larger. Still counting.", 3.5)
	VFX.shake(1.0)
	var lev := LEVIATHAN.new()
	lev.global_position = Vector2(A.half_size.x + 500, 0)
	r.mm.add_child(lev)
	lev.enter(Vector2(A.half_size.x - 700, 0))
	r.say("jax", "We may have made a small mistake.", 2.5)
	r.say("loco", "How small?", 1.5)
	await r.wait(4.5)
	r.say("jax", "Medium.", 2.0)
	r.say("sec", "All units: cease fire on the civilians. New priority target.", 3.0)
	r.say("rats", "...We're on the cops' side now?!", 2.5)
	for s in r.mm.ships.all_ships():
		if s.peer_id == 0 and s.team in [2, 3]:
			s.team = 1
	r.objective("Destroy the Leviathan's drones and turrets")
	lev.activate(r)
	while lev.alive:
		await r.wait(0.5)
	r.say("loco", "Is it dead?", 1.5)
	r.say("jax", "It's... leaving. Towards the gate.", 2.5)
	r.say("sys", "Gate network coming online. Recommend: closing the gate.", 3.0)
	await r.finish(true, "MISSION COMPLETE", "It wasn't dead. It was just the first one.")
