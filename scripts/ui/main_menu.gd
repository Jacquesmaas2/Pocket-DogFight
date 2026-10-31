extends Control
## Main menu: Story, Host, Join, Settings, Quit.

var _settings: Control
var _status: Label
var _address: LineEdit
var _transport: OptionButton
var _join_panel: PanelContainer


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_preset(PRESET_FULL_RECT)
	UIKit.fullscreen_bg(self)
	var bg: Node2D = load("res://scenes/arenas/asteroid_belt.tscn").instantiate()
	bg.build_asteroids = true
	bg.position = get_viewport_rect().size / 2
	bg.scale = Vector2(0.35, 0.35)
	add_child(bg)
	move_child(bg, 1)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	var t := UIKit.title("POCKET DOGFIGHT")
	t.add_theme_font_size_override("font_size", 58)
	box.add_child(t)
	box.add_child(UIKit.label("Two pilots. Tiny ships. Big explosions.", 20, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.spacer(10))
	box.add_child(UIKit.button("Story: Loek & Jacques", func() -> void: Game.goto("story_select")))
	box.add_child(UIKit.button("Quick Match (offline)", _quick_match))
	if not OS.has_feature("web"):
		box.add_child(UIKit.button("Host Game", _host))
	box.add_child(UIKit.button("Join Game", _show_join))
	box.add_child(UIKit.button("Settings", func() -> void: _settings.open()))
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		box.add_child(UIKit.button("Quit", func() -> void: get_tree().quit()))
	_status = UIKit.label("", 18, Color("ffe04a"), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_status)
	box.set_anchors_preset(PRESET_CENTER)
	box.offset_left = -220
	box.offset_right = 220
	box.offset_top = -300
	box.offset_bottom = 300
	add_child(box)

	var jb := VBoxContainer.new()
	jb.add_theme_constant_override("separation", 10)
	jb.add_child(UIKit.label("Join a game", 26, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	jb.add_child(UIKit.label("IP[:port], or ws:// / wss:// tunnel URL", 16, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER))
	_address = LineEdit.new()
	_address.text = _url_server_param() if _url_server_param() != "" else Settings.last_address
	_address.placeholder_text = "127.0.0.1"
	_address.custom_minimum_size = Vector2(360, 48)
	jb.add_child(_address)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(UIKit.button("Connect", _join, 170))
	row.add_child(UIKit.button("Back", func() -> void: _join_panel.visible = false, 170))
	jb.add_child(row)
	_join_panel = UIKit.panel(jb)
	_join_panel.set_anchors_preset(PRESET_CENTER)
	_join_panel.offset_left = -220
	_join_panel.offset_right = 220
	_join_panel.offset_top = -140
	_join_panel.offset_bottom = 140
	_join_panel.visible = false
	add_child(_join_panel)

	_settings = load("res://scripts/ui/settings_menu.gd").new()
	add_child(_settings)

	var version := UIKit.label("Pilot: %s   |   LAN IP: %s" % [Settings.player_name, Net.local_ip_hint()], 16, Color(1, 1, 1, 0.5))
	version.set_anchors_preset(PRESET_BOTTOM_LEFT)
	version.offset_left = 16
	version.offset_top = -34
	version.offset_right = 700
	add_child(version)
	Settings.changed.connect(func() -> void: version.text = "Pilot: %s   |   LAN IP: %s" % [Settings.player_name, Net.local_ip_hint()])

	Net.connection_failed.connect(_on_failed)
	Net.connected_to_host.connect(func() -> void: Game.goto("lobby"))
	var hb: Control = load("res://scripts/ui/host_dialog.gd").new()
	hb.name = "HostDialog"
	add_child(hb)
	if _url_server_param() != "":
		_show_join()


func _quick_match() -> void:
	Net.host_offline(false)
	_add_bots_and_start()


func _add_bots_and_start() -> void:
	Game.current_mission_id = -2 # marker: offline quick match with bots
	Game.goto("match")


func _host() -> void:
	get_node("HostDialog").open()


func _show_join() -> void:
	_join_panel.visible = true
	_status.text = ""


func _join() -> void:
	var addr := _address.text.strip_edges()
	Settings.last_address = addr
	Settings.save_settings()
	_status.text = "Connecting to %s..." % addr
	if Net.join(addr) != OK:
		return


func _on_failed(reason: String) -> void:
	_status.text = reason


## Browser builds: https://host/?server=wss://... pre-fills (and auto-opens) the join dialog.
func _url_server_param() -> String:
	if not OS.has_feature("web"):
		return ""
	var v = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('server') || ''", true)
	return str(v).strip_edges() if v != null else ""
