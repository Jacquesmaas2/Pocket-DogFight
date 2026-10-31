extends StoryMission
## Mission 2 - The Core: investigate the wreck, grab the Core, first real dogfight.


func _init() -> void:
	title = "The Core"


func run() -> void:
	var A := r.mm.arena
	var wreck := Vector2(A.half_size.x - 500, -A.half_size.y + 420)
	for i in 6:
		A.add_asteroid(wreck + Vector2.RIGHT.rotated(TAU * i / 6.0) * 260.0, 55.0 + i * 5, 900 + i)
	await r.spawn_player(Vector2(-A.half_size.x + 300, A.half_size.y - 300), -0.6)
	r.spawn_loek(Vector2(-A.half_size.x + 300, A.half_size.y - 180), "escort")
	r.say("jax", "Derelict ahead. Abandoned. Totally safe.", 2.8)
	r.say("loco", "You said that about the lava moon.", 2.5)
	r.objective("Reach the wreck")
	r.marker(wreck, "WRECK")
	await r.reach(wreck, 180.0)
	r.clear_markers()
	r.say("sys", "Object detected. Origin unknown. Energy source unknown. Purpose unknown.", 3.5)
	r.say("loco", "So we're taking it?", 2.0)
	r.say("jax", "Obviously.", 2.0)
	r.objective("Fly into the Core to retrieve it")
	await r.core_pickup(wreck)
	r.banner("CORE RETRIEVED", "It hums. That's probably fine.", 2.5)
	await r.wait(1.5)
	r.say("sys", "Warning: multiple contacts.", 2.0)
	r.spawn_enemies("scrap", 3, 2, wreck + Vector2(-700, 300), 260.0, "Rat")
	r.say("loco", "Good news.", 1.8)
	r.say("jax", "What?", 1.5)
	r.say("loco", "We found out who owns it.", 2.5)
	r.objective("Destroy the hostiles")
	await r.wait_team_dead(2)
	r.say("rats", "GIVE. US. THE SHINY.", 2.5)
	r.spawn_enemies("scrap", 4, 2, Vector2(0, 0), 500.0, "Rat")
	await r.wait_team_dead(2)
	r.say("jax", "Okay. Everyone wants it.", 2.2)
	r.say("loco", "Everyone can't have it.", 2.2)
	await r.finish(true, "MISSION COMPLETE", "The Core is yours. Half the galaxy disagrees.")
