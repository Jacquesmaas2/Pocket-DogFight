extends Control
## Main menu: one obvious way to play online, friends/LAN options, story, practice, settings.

var _settings: Control
var _status: Label
var _address: LineEdit
var _join_panel: PanelContainer
var _friends_panel: PanelContainer
var _name_edit: LineEdit
var _ship_opt: OptionButton
var _online_btn: Button
var _connecting: bool = false
var _http: HTTPRequest


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_preset(PRESET_FULL_RECT)
	UIKit.fullscreen_bg(self)
	var bg: Node2D = load("res://scenes/arenas/asteroid_belt.tscn").instantiate()
	bg.position = get_viewport_rect().size / 2
	bg.scale = Vector2(0.35, 0.35)
	add_child(bg)
	move_child(bg, 1)

	_build_main()
	_build_pilot_card()
	_build_friends_panel()
	_build_join_panel()
	_build_help()
	_settings = load("res://scripts/ui/settings_menu.gd").new()
	add_child(_settings)
	var hb: Control = load("res://scripts/ui/host_dialog.gd").new()
	hb.name = "HostDialog"
	add_child(hb)

	Net.connection_failed.connect(_on_failed)
	Net.connected_to_host.connect(func() -> void: Game.goto("lobby"))
	Settings.changed.connect(_refresh_pilot)
	_refresh_online_button()
	if OS.has_feature("web"):
		_fetch_web_default_server()
	var param := _url_server_param()
	if param != "":
		_address.text = param
		_connect_to(param)


# ---------------------------------------------------------------- layout
func _build_main() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	var t := UIKit.title("POCKET DOGFIGHT")
	t.add_theme_font_size_override("font_size", 58)
	box.add_child(t)
	box.add_child(UIKit.label("Two pilots. Tiny ships. Big explosions.", 20, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.spacer(8))
	_online_btn = UIKit.button("PLAY ONLINE", _play_online, 320)
	_online_btn.custom_minimum_size.y = 68
	_online_btn.add_theme_font_size_override("font_size", 28)
	box.add_child(_online_btn)
	box.add_child(UIKit.button("Play with friends", func() -> void: _show(_friends_panel), 320))
	box.add_child(UIKit.button("Story: Loek & Jacques", func() -> void: Game.goto("story_select"), 320))
	box.add_child(UIKit.button("Practice vs bots", _quick_match, 320))
	box.add_child(UIKit.button("Settings", func() -> void: _settings.open(), 320))
	if OS.get_name() not in ["Android", "iOS", "Web"]:
		box.add_child(UIKit.button("Quit", func() -> void: get_tree().quit(), 320))
	_status = UIKit.label("", 18, Color("ffe04a"), HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 420
	box.add_child(_status)
	box.set_anchors_preset(PRESET_CENTER)
	box.offset_left = -220
	box.offset_right = 220
	box.offset_top = -330
	box.offset_bottom = 330
	add_child(box)


func _build_pilot_card() -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(UIKit.label("YOUR PILOT", 16, UIKit.ACCENT))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.placeholder_text = "Callsign"
	_name_edit.text = Settings.player_name
	_name_edit.custom_minimum_size = Vector2(220, 44)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _save_pilot())
	_name_edit.focus_exited.connect(_save_pilot)
	col.add_child(_name_edit)
	_ship_opt = OptionButton.new()
	_ship_opt.add_item("The Syntiq  (Jacques)")
	_ship_opt.set_item_metadata(0, "syntiq")
	_ship_opt.add_item("The Bad Idea  (Loek)")
	_ship_opt.set_item_metadata(1, "bad_idea")
	_ship_opt.add_item("Pocket Fighter")
	_ship_opt.set_item_metadata(2, "generic")
	_ship_opt.item_selected.connect(func(_i: int) -> void: _save_pilot())
	col.add_child(_ship_opt)
	var card := UIKit.panel(col)
	card.set_anchors_preset(PRESET_TOP_LEFT)
	card.offset_left = 20
	card.offset_top = 20
	card.offset_right = 290
	card.offset_bottom = 170
	add_child(card)
	_refresh_pilot()


func _build_friends_panel() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(UIKit.label("Play with friends", 26, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	if Net.can_host():
		box.add_child(UIKit.label("Host a game on this device, then share the link from the lobby.", 16, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(UIKit.button("Host a game", func() -> void: _friends_panel.visible = false; get_node("HostDialog").open(), 300))
	else:
		box.add_child(UIKit.label("Browsers can't host. Ask a friend on PC to host, or use PLAY ONLINE.", 16, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.button("Join with a link or address", func() -> void: _friends_panel.visible = false; _show(_join_panel), 300))
	box.add_child(UIKit.button("Back", func() -> void: _friends_panel.visible = false, 160))
	_friends_panel = UIKit.panel(box)
	_friends_panel.set_anchors_preset(PRESET_CENTER)
	_friends_panel.offset_left = -240
	_friends_panel.offset_right = 240
	_friends_panel.offset_top = -150
	_friends_panel.offset_bottom = 150
	_friends_panel.visible = false
	add_child(_friends_panel)


func _build_join_panel() -> void:
	var jb := VBoxContainer.new()
	jb.add_theme_constant_override("separation", 10)
	jb.add_child(UIKit.label("Join a game", 26, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	jb.add_child(UIKit.label("Paste the link your friend shared, or an address:\nwss://…  ·  ws://192.168.1.20:24565  ·  192.168.1.20", 15, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER))
	_address = LineEdit.new()
	_address.text = Settings.last_address
	_address.placeholder_text = "wss://example.trycloudflare.com"
	_address.custom_minimum_size = Vector2(380, 48)
	_address.text_submitted.connect(func(_t: String) -> void: _join())
	jb.add_child(_address)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(UIKit.button("Connect", _join, 170))
	row.add_child(UIKit.button("Back", func() -> void: _join_panel.visible = false; _cancel_connect(), 170))
	jb.add_child(row)
	_join_panel = UIKit.panel(jb)
	_join_panel.set_anchors_preset(PRESET_CENTER)
	_join_panel.offset_left = -240
	_join_panel.offset_right = 240
	_join_panel.offset_top = -150
	_join_panel.offset_bottom = 150
	_join_panel.visible = false
	add_child(_join_panel)


func _build_help() -> void:
	var touch := Settings.touch_controls_enabled()
	var text := "CONTROLS   left stick: steer + thrust   ·   FIRE / MSL / BOOST buttons" if touch else "CONTROLS   W thrust · A/D turn · SPACE laser · SHIFT missile · CTRL boost · TAB scores · ESC pause"
	var help := UIKit.label(text, 15, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	help.set_anchors_preset(PRESET_BOTTOM_WIDE)
	help.offset_top = -40
	help.offset_bottom = -14
	add_child(help)
	var ip := UIKit.label("LAN IP: %s" % Net.local_ip_hint(), 14, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)
	ip.set_anchors_preset(PRESET_TOP_RIGHT)
	ip.offset_left = -320
	ip.offset_right = -16
	ip.offset_top = 14
	add_child(ip)


# ---------------------------------------------------------------- actions
func _show(panel: Control) -> void:
	_friends_panel.visible = false
	_join_panel.visible = false
	panel.visible = true
	_status.text = ""


func _save_pilot() -> void:
	var n := _name_edit.text.strip_edges()
	Settings.player_name = n if not n.is_empty() else "Pilot"
	Settings.preferred_ship = str(_ship_opt.get_item_metadata(_ship_opt.selected))
	Settings.save_settings()


func _refresh_pilot() -> void:
	if _name_edit.text != Settings.player_name:
		_name_edit.text = Settings.player_name
	for i in _ship_opt.item_count:
		if _ship_opt.get_item_metadata(i) == Settings.preferred_ship:
			_ship_opt.select(i)


func _refresh_online_button() -> void:
	var has := Net.default_server != ""
	_online_btn.text = "PLAY ONLINE" if has else "PLAY ONLINE  (no server set)"
	_online_btn.tooltip_text = Net.default_server if has else "No public server configured. Use 'Play with friends' to join a link."


func _play_online() -> void:
	if Net.default_server == "":
		_show(_join_panel)
		_status.text = "No public server is configured yet. Paste a friend's link, or host one yourself."
		return
	_connect_to(Net.default_server)


func _quick_match() -> void:
	Net.host_offline(false)
	Game.current_mission_id = -2
	Game.goto("match")


func _join() -> void:
	var addr := _address.text.strip_edges()
	# Accept a full share link and extract its server parameter.
	if addr.contains("?server="):
		addr = addr.get_slice("?server=", 1).uri_decode()
	Settings.last_address = addr
	Settings.save_settings()
	_connect_to(addr)


func _connect_to(addr: String) -> void:
	if _connecting:
		return
	_connecting = true
	_status.text = "Connecting to %s …" % addr
	_online_btn.disabled = true
	if Net.join(addr) != OK:
		_connecting = false
		_online_btn.disabled = false


func _cancel_connect() -> void:
	if _connecting:
		Net.leave()
		_connecting = false
		_online_btn.disabled = false
		_status.text = ""


func _on_failed(reason: String) -> void:
	_connecting = false
	_online_btn.disabled = false
	_status.text = reason + "\nCheck the address, or ask the host whether the server is running."


# ---------------------------------------------------------------- web helpers
## Browser builds: https://host/?server=wss://... connects immediately.
func _url_server_param() -> String:
	if not OS.has_feature("web"):
		return ""
	var v = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('server') || ''", true)
	return str(v).strip_edges() if v != null else ""


## Browser builds read server.txt next to index.html (written by the deploy workflow).
func _fetch_web_default_server() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		var txt := body.get_string_from_utf8().strip_edges()
		if code == 200 and (txt.begins_with("wss://") or txt.begins_with("ws://")):
			Net.default_server = txt
			_refresh_online_button())
	_http.request("server.txt?nocache=%d" % Time.get_ticks_msec())
