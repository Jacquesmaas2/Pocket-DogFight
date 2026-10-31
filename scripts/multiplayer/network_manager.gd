extends Node
## Autoload: transport-agnostic host/join + player registry.
## Transports: "enet" (UDP, LAN) and "websocket" (TCP, tunnel-friendly: cloudflared/ngrok).
## Join address with ws:// or wss:// prefix selects websocket automatically.

signal players_changed
signal connection_failed(reason: String)
signal connected_to_host
signal disconnected_from_host
signal hosting_started

const TRANSPORT_ENET := "enet"
const TRANSPORT_WEBSOCKET := "websocket"
const TRANSPORT_WEBRTC := "webrtc" # reserved: needs a signaling service + STUN/TURN; not implemented yet

var players: Dictionary = {} # peer_id -> {name, ship, color, score, kills, deaths}
var is_dedicated: bool = false
var transport: String = TRANSPORT_WEBSOCKET
var port: int = 24565
var public_url: String = ""
var story_mode: bool = false
# External multiplayer service configuration (never committed values; see WEB-DEPLOYMENT.md).
var signaling_url: String = ""
var ice_servers: Array = [] # e.g. [{"urls": ["stun:stun.example.org:3478"]}]

var _pending_timeout: SceneTreeTimer


func _ready() -> void:
	port = Config.match_config.default_port
	_read_environment()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func _read_environment() -> void:
	var env_port := OS.get_environment("PD_PORT")
	if env_port.is_valid_int():
		port = int(env_port)
	var env_transport := OS.get_environment("PD_TRANSPORT")
	if env_transport in [TRANSPORT_ENET, TRANSPORT_WEBSOCKET]:
		transport = env_transport
	public_url = OS.get_environment("PD_PUBLIC_URL")
	signaling_url = OS.get_environment("PD_SIGNALING_URL")
	var ice := OS.get_environment("PD_ICE_SERVERS")
	if ice != "":
		var parsed = JSON.parse_string(ice)
		if parsed is Array:
			ice_servers = parsed
	for arg in OS.get_cmdline_user_args():
		if arg == "--server":
			is_dedicated = true
		elif arg.begins_with("--port="):
			port = int(arg.get_slice("=", 1))
		elif arg.begins_with("--transport="):
			transport = arg.get_slice("=", 1)


func is_server() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


func local_id() -> int:
	return multiplayer.get_unique_id() if multiplayer.multiplayer_peer != null else 1


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


## Browsers cannot open listening sockets and have no ENet; only WebSocket clients work there.
func can_host() -> bool:
	return not OS.has_feature("web")


# ---------------------------------------------------------------- hosting
func host(use_transport: String = "", dedicated: bool = false) -> Error:
	leave()
	if not can_host():
		connection_failed.emit("Hosting is not available in the browser build")
		return ERR_UNAVAILABLE
	if use_transport != "":
		transport = use_transport
	if transport == TRANSPORT_WEBRTC:
		connection_failed.emit("WebRTC transport is not implemented yet")
		return ERR_UNAVAILABLE
	var peer: MultiplayerPeer
	var err: Error
	if transport == TRANSPORT_ENET:
		var enet := ENetMultiplayerPeer.new()
		err = enet.create_server(port, Config.match_config.max_players)
		peer = enet
	else:
		var ws := WebSocketMultiplayerPeer.new()
		err = ws.create_server(port)
		peer = ws
	if err != OK:
		connection_failed.emit("Could not open port %d (%s)" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = peer
	is_dedicated = dedicated
	story_mode = false
	players.clear()
	if not dedicated:
		_register_local_player()
	hosting_started.emit()
	players_changed.emit()
	return OK


func host_offline(story: bool = false) -> void:
	leave()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	story_mode = story
	players.clear()
	_register_local_player()
	hosting_started.emit()
	players_changed.emit()


func join(address: String) -> Error:
	leave()
	address = address.strip_edges()
	if address.is_empty():
		connection_failed.emit("Enter an address")
		return ERR_INVALID_PARAMETER
	var peer: MultiplayerPeer
	var err: Error
	if address.begins_with("webrtc://"):
		connection_failed.emit("WebRTC transport is not implemented yet")
		return ERR_UNAVAILABLE
	if address.begins_with("ws://") or address.begins_with("wss://"):
		var ws := WebSocketMultiplayerPeer.new()
		err = ws.create_client(address)
		peer = ws
	else:
		var force_enet := address.begins_with("enet://")
		address = address.trim_prefix("enet://")
		var host_name := address
		var join_port := port
		if address.contains(":"):
			host_name = address.get_slice(":", 0)
			var p := address.get_slice(":", 1)
			if p.is_valid_int():
				join_port = int(p)
		if transport == TRANSPORT_WEBSOCKET and not force_enet or OS.has_feature("web"):
			var ws := WebSocketMultiplayerPeer.new()
			err = ws.create_client("ws://%s:%d" % [host_name, join_port])
			peer = ws
		else:
			var enet := ENetMultiplayerPeer.new()
			err = enet.create_client(host_name, join_port)
			peer = enet
	if err != OK:
		connection_failed.emit("Connection error: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	story_mode = false
	players.clear()
	_pending_timeout = get_tree().create_timer(8.0)
	_pending_timeout.timeout.connect(_on_connect_timeout)
	return OK


func leave() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players.clear()
	players_changed.emit()


func _on_connect_timeout() -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		leave()
		connection_failed.emit("Connection timed out")


# ---------------------------------------------------------------- registry
func _register_local_player() -> void:
	var id := local_id()
	players[id] = _make_player(Settings.player_name, Settings.preferred_ship, players.size())


func _make_player(pname: String, ship: String, color_index: int) -> Dictionary:
	return {"name": pname, "ship": ship, "color": color_index, "score": 0, "kills": 0, "deaths": 0}


func _on_peer_connected(id: int) -> void:
	if is_server():
		# Server waits for the client's hello before it is visible to others.
		pass
	else:
		pass


func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players.erase(id)
		if is_server():
			_sync_players.rpc(players)
		players_changed.emit()


func _on_connected() -> void:
	_hello.rpc_id(1, Settings.player_name, Settings.preferred_ship)
	connected_to_host.emit()


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit("Could not reach host")


func _on_server_disconnected() -> void:
	leave()
	disconnected_from_host.emit()


@rpc("any_peer", "reliable")
func _hello(pname: String, ship: String) -> void:
	if not is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= Config.match_config.max_players:
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	pname = pname.strip_edges().substr(0, 16)
	if pname.is_empty():
		pname = "Pilot %d" % id
	if not Config.SHIP_PATHS.has(ship):
		ship = "generic"
	var used: Array = []
	for p in players.values():
		used.append(p["color"])
	var color := 0
	while used.has(color) and color < Config.PLAYER_COLORS.size():
		color += 1
	players[id] = _make_player(pname, ship, color)
	_sync_players.rpc(players)
	players_changed.emit()


@rpc("authority", "reliable", "call_remote")
func _sync_players(data: Dictionary) -> void:
	players = data
	players_changed.emit()


func broadcast_players() -> void:
	if is_server() and is_online():
		_sync_players.rpc(players)
	players_changed.emit()


func player_name(id: int) -> String:
	return str(players.get(id, {}).get("name", "???"))


func player_color(id: int) -> Color:
	return Config.player_color(int(players.get(id, {}).get("color", 0)))


func local_ip_hint() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"
