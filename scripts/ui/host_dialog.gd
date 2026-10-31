extends Control
## Host options: transport (WebSocket for tunnels / ENet for LAN) and port.

var _transport: OptionButton
var _port: LineEdit
var _status: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(UIKit.label("Host a game", 26, UIKit.ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	_transport = OptionButton.new()
	_transport.add_item("WebSocket (LAN + public tunnel)")
	_transport.add_item("ENet/UDP (LAN only, lowest latency)")
	_transport.select(0 if Net.transport == Net.TRANSPORT_WEBSOCKET else 1)
	box.add_child(_transport)
	var row := HBoxContainer.new()
	row.add_child(UIKit.label("Port", 20))
	_port = LineEdit.new()
	_port.text = str(Net.port)
	_port.custom_minimum_size.x = 140
	row.add_child(_port)
	box.add_child(row)
	_status = UIKit.label("Friends on your Wi-Fi join with your LAN IP.\nFor the internet run tools/start_tunnel.ps1 and share the wss:// URL.", 15, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_status)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	btns.add_child(UIKit.button("Start Hosting", _start, 190))
	btns.add_child(UIKit.button("Back", func() -> void: visible = false, 150))
	box.add_child(btns)
	var panel := UIKit.panel(box)
	panel.set_anchors_preset(PRESET_CENTER)
	panel.offset_left = -260
	panel.offset_right = 260
	panel.offset_top = -170
	panel.offset_bottom = 170
	add_child(panel)


func open() -> void:
	visible = true


func _start() -> void:
	if _port.text.is_valid_int() and int(_port.text) > 1024 and int(_port.text) < 65536:
		Net.port = int(_port.text)
	else:
		_status.text = "Port must be between 1025 and 65535"
		return
	var tr := Net.TRANSPORT_WEBSOCKET if _transport.selected == 0 else Net.TRANSPORT_ENET
	if Net.host(tr) == OK:
		Game.goto("lobby")
	else:
		_status.text = "Could not start hosting on port %d" % Net.port
