extends Control
## Pre-match lobby: who is here, how to invite others, when the match starts.

var _list: VBoxContainer
var _status: Label
var _link_edit: LineEdit
var _copy_btn: Button
var _start_btn: Button
var _count_label: Label
var _hint: Label


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_preset(PRESET_FULL_RECT)
	UIKit.fullscreen_bg(self)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(UIKit.title("LOBBY"))
	_count_label = UIKit.label("", 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_count_label)
	_list = VBoxContainer.new()
	_list.custom_minimum_size.y = 150
	box.add_child(UIKit.panel(_list))

	var invite := VBoxContainer.new()
	invite.add_theme_constant_override("separation", 6)
	invite.add_child(UIKit.label("INVITE FRIENDS — send them this link", 15, UIKit.ACCENT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_link_edit = LineEdit.new()
	_link_edit.editable = false
	_link_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	_link_edit.custom_minimum_size.y = 44
	row.add_child(_link_edit)
	_copy_btn = UIKit.button("Copy", _copy_link, 110)
	row.add_child(_copy_btn)
	invite.add_child(row)
	_hint = UIKit.label("", 14, Color(1, 1, 1, 0.6))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	invite.add_child(_hint)
	box.add_child(UIKit.panel(invite))

	_status = UIKit.label("", 18, Color("ffe04a"), HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	_start_btn = UIKit.button("START MATCH", func() -> void: Game.start_match(), 240)
	_start_btn.custom_minimum_size.y = 60
	btns.add_child(_start_btn)
	btns.add_child(UIKit.button("Leave", func() -> void: Game.return_to_menu(), 160))
	box.add_child(btns)
	box.set_anchors_preset(PRESET_CENTER)
	box.offset_left = -380
	box.offset_right = 380
	box.offset_top = -330
	box.offset_bottom = 330
	add_child(box)
	Net.players_changed.connect(_refresh)
	Net.lobby_status_changed.connect(func(_t: String, _s: int) -> void: _refresh())
	_refresh()


func _server_address() -> String:
	if Net.is_server():
		if Net.public_url != "":
			return Net.public_url
		return "%s%s:%d" % ["ws://" if Net.transport == Net.TRANSPORT_WEBSOCKET else "enet://", Net.local_ip_hint(), Net.port]
	return Settings.last_address if Settings.last_address != "" else Net.default_server


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var n := Net.players.size()
	_count_label.text = "%d / %d pilots" % [n, Config.match_config.max_players]
	for id in Net.players:
		var p: Dictionary = Net.players[id]
		var you := "  (you)" if id == Net.local_id() else ""
		var host := "  · host" if id == 1 and not Net.is_dedicated else ""
		_list.add_child(UIKit.label("●  %s  —  %s%s%s" % [p["name"], Config.ship_stats(p["ship"]).display_name, host, you], 22, Net.player_color(id)))
	if n == 0:
		_list.add_child(UIKit.label("Nobody here yet.", 20, Color(1, 1, 1, 0.5)))
	_link_edit.text = Net.share_link(_server_address())
	_start_btn.visible = Net.is_server()
	_start_btn.disabled = n < 1
	if Net.is_server():
		_hint.text = "LAN players can also type %s. For the internet keep a tunnel running (tools/start_tunnel.ps1) or use a hosted server." % _server_address()
		_status.text = "You are the host. Press START MATCH when everyone is in (players can still join later)."
	else:
		_hint.text = "Anyone who opens this link lands in the same lobby."
		if Net.lobby_status != "":
			_status.text = Net.lobby_status if Net.lobby_seconds < 0 else "%s  (%ds)" % [Net.lobby_status, Net.lobby_seconds]
		else:
			_status.text = "Connected. Waiting for the host to start." if n >= 2 else "Connected. Waiting for more pilots…"


func _copy_link() -> void:
	var link := _link_edit.text
	if OS.has_feature("web"):
		JavaScriptBridge.eval("navigator.clipboard && navigator.clipboard.writeText(%s)" % JSON.stringify(link), true)
	else:
		DisplayServer.clipboard_set(link)
	_copy_btn.text = "Copied!"
	Audio.play("powerup", -8.0)
	get_tree().create_timer(1.5).timeout.connect(func() -> void: _copy_btn.text = "Copy")
