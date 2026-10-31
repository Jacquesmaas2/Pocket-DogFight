extends StoryMission
## Mission 1 - Just Another Tuesday: asteroid race tutorial + the signal.


func _init() -> void:
	title = "Just Another Tuesday"


func run() -> void:
	var A := r.mm.arena
	await r.spawn_player(Vector2(-A.half_size.x + 250, 0), 0.0)
	r.spawn_loek(Vector2(-A.half_size.x + 250, 120), "escort")
	r.say("loco", "My ship is faster.", 2.5)
	r.say("jax", "Your ship is held together with tape.", 2.5)
	r.say("loco", "Fast tape.", 2.0)
	r.objective("Learn the controls: " + r.controls_hint("steer") + ", " + r.controls_hint("thrust"))
	var m := r.marker(Vector2(-A.half_size.x + 650, 0), "FLY HERE")
	await r.reach(m.global_position, 140.0)
	r.clear_markers()
	r.say("jax", "Good. Now hold the trigger. " + r.controls_hint("fire") + ".", 3.0)
	r.objective("Shoot the practice drones")
	r.spawn_enemies("scrap", 2, 2, Vector2(-A.half_size.x + 1000, 0), 220.0, "Drone", 0.0)
	await r.wait_team_dead(2)
	r.say("loco", "Those were my drones.", 2.2)
	r.say("jax", "They flew at us.", 2.0)
	r.say("loco", "That's what drones do.", 2.0)
	r.objective("Race Loek through the belt. " + r.controls_hint("boost"))
	var cps: Array[Vector2] = [
		Vector2(-500, -500), Vector2(300, -650), Vector2(900, -200), Vector2(1100, 450),
		Vector2(400, 700), Vector2(-400, 500), Vector2(-900, 100), Vector2(-200, -150), Vector2(600, 150),
	]
	await r.wait(0.5)
	r.banner("RACE!", "First to the last ring wins", 1.5)
	var won := await r.race(cps, 0.15)
	if won:
		r.say("jax", "I win. Again.", 2.0)
		r.say("loco", "My ship lagged.", 2.0)
	else:
		r.say("loco", "Fast tape!", 2.0)
		r.say("jax", "You cut three corners.", 2.0)
	await r.wait(2.0)
	r.banner("", "UNKNOWN SIGNAL DETECTED", 3.0)
	Audio.play("missile_warning", -4.0)
	r.say("sys", "Unknown signal detected. Origin: derelict, sector 7.", 3.0)
	r.say("loco", "Do we need to look at that?", 2.5)
	r.say("jax", "Absolutely not.", 2.0)
	await r.wait(5.0)
	r.objective("Investigate the signal")
	var sig := Vector2(A.half_size.x - 300, -A.half_size.y + 300)
	r.marker(sig, "SIGNAL")
	await r.reach(sig, 160.0)
	r.say("jax", "...Fine. We look at it.", 2.0)
	await r.finish(true, "MISSION COMPLETE", "Just Another Tuesday. Until it wasn't.")
