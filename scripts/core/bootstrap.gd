extends Node
## Bootstrap: applies theme, handles dedicated-server start, then opens the menu.


func _ready() -> void:
	if Net.is_dedicated:
		var err := Net.host("", true)
		if err != OK:
			push_error("Dedicated server failed to start")
			get_tree().quit(1)
			return
		print("Pocket Dogfight dedicated server listening on port %d (%s)" % [Net.port, Net.transport])
		Net.players_changed.connect(_auto_start)
		return
	Game.goto("menu")


func _auto_start() -> void:
	# Dedicated server: start the match once two players are present and nothing is running.
	if Net.players.size() >= 2 and get_tree().current_scene == self:
		Game.start_match()
