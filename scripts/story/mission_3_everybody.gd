extends StoryMission
## Mission 3 - Everybody Wants It: Scrap Rats, Galactic Security, missiles and power-ups.


func _init() -> void:
	title = "Everybody Wants It"


func run() -> void:
	var A := r.mm.arena
	r.mm.powerups.enabled = true
	r.mm.powerups.server_reset()
	await r.spawn_player(Vector2(0, 0), 0.0)
	r.spawn_loek(Vector2(-120, 80), "escort")
	r.say("loco", "I installed missiles.", 2.2)
	r.say("jax", "On MY ship?", 2.0)
	r.say("loco", "On everyone's ship. I was bored.", 2.5)
	r.objective("Scrap Rats incoming. " + r.controls_hint("missile") + ". Grab power-ups!")
	r.powerup("missile", Vector2(300, -200))
	r.spawn_enemies("scrap", 4, 2, Vector2(900, -500), 300.0, "Rat")
	await r.wait_team_dead(2)
	r.say("sec", "Unidentified vessels. You are in possession of restricted material. Power down.", 3.5)
	r.say("loco", "Power... UP?", 1.8)
	r.say("jax", "That's not— okay, yes. Power up.", 2.5)
	r.objective("Fight off Galactic Security")
	r.spawn_enemies("security", 3, 3, Vector2(-1000, 500), 300.0, "Officer", 0.9)
	await r.wait(10.0)
	r.spawn_enemies("scrap", 3, 2, Vector2(1000, 600), 300.0, "Rat")
	r.say("rats", "THE SHINY IS OURS, COPS!", 2.5)
	await r.wait_team_dead(3)
	await r.wait_team_dead(2)
	r.say("sec", "Reinforcements inbound. You cannot outrun—", 2.5)
	r.say("loco", "Watch us.", 1.5)
	r.objective("Escape through the gap in the belt")
	var exit := Vector2(A.half_size.x - 200, A.half_size.y - 200)
	r.marker(exit, "ESCAPE")
	r.spawn_enemies("security", 4, 3, Vector2(-A.half_size.x + 300, -A.half_size.y + 300), 300.0, "Officer", 0.6)
	await r.reach(exit, 170.0)
	await r.finish(true, "MISSION COMPLETE", "Scrap Rats: angry. Security: angrier. Core: humming louder.")
