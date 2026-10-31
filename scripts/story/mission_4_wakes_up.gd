extends StoryMission
## Mission 4 - The Core Wakes Up: gravity wells, slow fields, overcharge and a wormhole, vs the Corporation.


func _init() -> void:
	title = "The Core Wakes Up"


func run() -> void:
	var A := r.mm.arena
	r.mm.powerups.enabled = true
	r.mm.powerups.server_reset()
	await r.spawn_player(Vector2(-A.half_size.x + 300, 0), 0.0)
	r.spawn_loek(Vector2(-A.half_size.x + 300, 130), "escort")
	r.say("sys", "Core energy output rising. Local spacetime: inconsistent.", 3.0)
	r.say("jax", "I want to understand it.", 2.0)
	r.say("loco", "I want to weaponize it.", 2.0)
	r.say("jax", "Both will happen. Mostly by accident.", 2.5)
	r.anomaly("gravity", Vector2(0, 0), 260.0, 1100.0)
	r.banner("", "GRAVITY DISTORTION DETECTED", 2.5)
	r.objective("Fly around the gravity well to the probe")
	var probe := Vector2(700, -350)
	r.marker(probe, "PROBE")
	await r.reach(probe, 150.0)
	r.clear_markers()
	r.say("corp", "This is the Corporation. That asset is ours by right of... we have more lawyers.", 3.5)
	r.spawn_enemies("corp", 3, 4, Vector2(1100, 300), 260.0, "Interceptor", 0.9)
	r.anomaly("slow", Vector2(500, 500), 240.0)
	r.anomaly("overcharge", Vector2(-700, -500), 200.0)
	r.banner("", "SLOW FIELD + WEAPON OVERCHARGE ZONES ACTIVE", 2.5)
	r.objective("Destroy the interceptors. Use the overcharge zone!")
	await r.wait_team_dead(4)
	r.say("loco", "The purple zone makes my gun angry. I love it.", 2.8)
	r.wormhole_pair(Vector2(-1100, 600), Vector2(1100, -650))
	r.banner("", "WORMHOLE OPENED", 2.5)
	r.say("jax", "It's opening holes in space.", 2.0)
	r.say("loco", "Shortcut!", 1.5)
	r.spawn_enemies("corp", 4, 4, Vector2(-900, -600), 300.0, "Interceptor", 1.0)
	r.spawn_enemies("security", 2, 3, Vector2(900, 700), 200.0, "Officer", 0.8)
	r.objective("Survive the second wave")
	await r.wait_team_dead(4)
	await r.wait_team_dead(3)
	r.say("sys", "Analysis complete. The Core is not a weapon. It is a key.", 3.0)
	r.say("jax", "A key to what?", 2.0)
	r.say("sys", "Gates. Many gates. Dormant. Until now.", 3.0)
	r.say("loco", "...Did we just wake something up?", 2.5)
	await r.finish(true, "MISSION COMPLETE", "The Core is a key. Something heard the lock turn.")
