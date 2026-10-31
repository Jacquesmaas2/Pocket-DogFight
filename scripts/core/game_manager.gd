extends Node
## Autoload: high-level scene flow. Menu -> Lobby -> Match -> Results -> Rematch/Menu.

signal scene_changed(scene_name: String)

const SCENES := {
	"menu": "res://scenes/ui/main_menu.tscn",
	"lobby": "res://scenes/ui/lobby.tscn",
	"match": "res://scenes/game/match.tscn",
	"story_select": "res://scenes/story/story_select.tscn",
}

var current_mission_id: int = -1
var last_results: Array = []
var story_progress: int = 0 # highest unlocked mission index


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_progress()
	Net.disconnected_from_host.connect(_on_host_lost)
	Net.connection_failed.connect(func(_r: String) -> void: pass)


func goto(scene_key: String) -> void:
	var path: String = SCENES[scene_key]
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", path)
	scene_changed.emit(scene_key)


func start_match() -> void:
	# Server-driven: everyone loads the match scene.
	if Net.is_server():
		_rpc_load_match.rpc()
		_rpc_load_match()


@rpc("authority", "reliable", "call_remote")
func _rpc_load_match() -> void:
	current_mission_id = -1
	goto("match")


func start_story_mission(mission_id: int) -> void:
	Net.host_offline(true)
	current_mission_id = mission_id
	goto("match")


func return_to_menu() -> void:
	Net.leave()
	goto("menu")


func mission_completed(mission_id: int) -> void:
	if mission_id + 1 > story_progress:
		story_progress = mission_id + 1
		_save_progress()


func _on_host_lost() -> void:
	goto("menu")


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://progress.cfg") == OK:
		story_progress = int(cfg.get_value("story", "progress", 0))


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("story", "progress", story_progress)
	cfg.save("user://progress.cfg")
