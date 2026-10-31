extends Control
## Pre-match lobby: player list, connection info, start (host only).

var _list: VBoxContainer
var _info: Label
var _start_btn: Button


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_preset(PRESET_FULL_RECT)
	UIKit.fullscreen_bg(self)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(UIKit.title("LOBBY"))
	_info = UIKit.label("", 18, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)
	_list = VBoxContainer.new()
	box.add_child(UIKit.panel(_list))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_start_btn = UIKit.button("Start Match", func() -> void: Game.start_match(), 220)
	row.add_child(_start_btn)
	row.add_child(UIKit.button("Leave", func() -> void: Game.return_to_menu(), 160))
	box.add_child(row)
	box.set_anchors_preset(PRESET_CENTER)
	box.offset_left = -360
	box.offset_right = 360
	box.offset_top = -280
	box.offset_bottom = 280
	add_child(box)
	Net.players_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for id in Net.players:
		var p: Dictionary = Net.players[id]
		var txt := "%s  —  %s%s" % [p["name"], Config.ship_stats(p["ship"]).display_name, "  (host)" if id == 1 else ""]
		_list.add_child(UIKit.label(txt, 22, Net.player_color(id)))
	if _list.get_child_count() == 0:
		_list.add_child(UIKit.label("Waiting for players...", 20, Color(1, 1, 1, 0.5)))
	_start_btn.visible = Net.is_server()
	if Net.is_server():
		var scheme := "ws://" if Net.transport == Net.TRANSPORT_WEBSOCKET else ""
		var lines := ["Hosting via %s on port %d" % [Net.transport.to_upper(), Net.port], "LAN: %s%s:%d" % [scheme, Net.local_ip_hint(), Net.port]]
		if Net.public_url != "":
			lines.append("Public: %s" % Net.public_url)
		else:
			lines.append("Public: run tools/start_tunnel.ps1 and share the wss:// URL")
		_info.text = "\n".join(lines)
	else:
		_info.text = "Connected. Waiting for the host to start."
