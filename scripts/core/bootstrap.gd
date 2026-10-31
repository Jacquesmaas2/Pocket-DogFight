extends Node
## Bootstrap: dedicated-server lifecycle, or open the menu.
## Dedicated server: waits in this scene, counts down once 2+ pilots are present, starts the match,
## and comes back here when the match is empty.

const START_COUNTDOWN := 12
var _countdown: int = -1
var _timer: Timer


func _ready() -> void:
	if not Net.is_dedicated:
		Game.goto("menu")
		return
	if not Net.is_online():
		var err := Net.host("", true)
		if err != OK:
			push_error("Dedicated server failed to start")
			get_tree().quit(1)
			return
		print("Pocket Dogfight dedicated server listening on port %d (%s)" % [Net.port, Net.transport])
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()
	Net.players_changed.connect(_update_status)
	_update_status()


func _update_status() -> void:
	var n := Net.players.size()
	if n >= 2:
		if _countdown < 0:
			_countdown = START_COUNTDOWN
		Net.set_lobby_status("Match starting", _countdown)
	else:
		_countdown = -1
		Net.set_lobby_status("Waiting for players  %d / 2" % n)


func _tick() -> void:
	if _countdown < 0:
		return
	_countdown -= 1
	if _countdown <= 0:
		_timer.stop()
		Net.set_lobby_status("Launching…", 0)
		print("Starting match with %d players" % Net.players.size())
		Game.start_match()
	else:
		Net.set_lobby_status("Match starting", _countdown)
