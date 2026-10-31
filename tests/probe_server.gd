extends SceneTree
## Connects to a running dedicated server as a WebSocket client, verifies lobby status replication, then leaves.
## Run: godot --headless -s tests/probe_server.gd -- --addr=ws://127.0.0.1:24565

func _init() -> void:
	var addr := "ws://127.0.0.1:24565"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--addr="):
			addr = a.get_slice("=", 1)
	await process_frame
	var net := root.get_node("Net")
	net.join(addr)
	var ok := false
	for i in 80:
		await create_timer(0.1).timeout
		if net.players.size() >= 1 and net.lobby_status != "":
			ok = true
			break
	print("PROBE players=%d status='%s' seconds=%d -> %s" % [net.players.size(), net.lobby_status, net.lobby_seconds, "PASS" if ok else "FAIL"])
	net.leave()
	await create_timer(0.3).timeout
	quit(0 if ok else 1)
