# Runbook

## Requirements
- Godot 4.3 stable (standard build, no C#). Portable download works: https://godotengine.org/download
- Windows: the scripts in `tools/` default to `%LOCALAPPDATA%\GodotTools\Godot_v4.3-stable_win64*.exe`; override with `-Godot <path>` or `$env:GODOT`.

## Open / run
- Editor: `godot --path "<repo>" -e`
- Play: `godot --path "<repo>"` (main scene = `res://scenes/bootstrap/bootstrap.tscn`)
- Desktop controls: W/Up thrust, A/D or Left/Right rotate, Space laser, Shift missile, Ctrl boost, Tab scoreboard, Esc pause.
- Touch controls appear automatically on touch devices; force them via Settings > "Force touch controls".

## Multiplayer on your own laptop
### Host
1. Main menu > **Host Game**.
2. Transport: **WebSocket** (default; works on LAN and through tunnels) or **ENet/UDP** (LAN only, lowest latency). Port default `24565`.
3. Lobby shows your LAN address. Press **Start Match** when players have joined. Late joiners during a match get a ship automatically.

### Join
- LAN / same machine: **Join Game** > `127.0.0.1` or `192.168.x.x[:port]` (uses the WebSocket transport by default; prefix `enet://` to force ENet).
- Internet (tunnel): enter the `wss://...` URL printed by the tunnel script.

### Public tunnel (no port forwarding, no server rental)
```powershell
winget install Cloudflare.cloudflared      # once (or: winget install ngrok.ngrok)
.\tools\start_tunnel.ps1 -Port 24565        # keep running while hosting
```
Share the printed `https://xxxx.trycloudflare.com` as `wss://xxxx.trycloudflare.com`. Players paste that into **Join Game**.
The host must be using the WebSocket transport. Tunnels are TCP; ENet (UDP) cannot be tunnelled this way.

### Headless dedicated server (same laptop or any machine)
```powershell
.\tools\run_server.ps1 -Port 24565 -Transport websocket
```
Environment overrides: `PD_PORT`, `PD_TRANSPORT` (`websocket|enet`), `PD_PUBLIC_URL` (shown in lobby). The server auto-starts a match when 2+ players are present.

### Two local instances
```powershell
.\tools\run_two_instances.ps1
```
Window 1: Host Game > Start Hosting. Window 2: Join Game > `127.0.0.1` > Connect. Window 1: Start Match.

## Story mode
Main menu > **Story: Loek & Jacques** > pick a mission (missions unlock in order; all unlocked in debug builds). You fly Jacques (The Syntiq); Loek (The Bad Idea) is an AI wingman/rival.

## Tests
```powershell
.\tools\run_tests.ps1          # import/parse check + headless unit/integration suite
.\tools\run_tests.ps1 -Net     # also runs the two-instance host/client test
```
Manual equivalents:
```
godot --headless --path <repo> res://tests/test_runner.tscn
godot --headless --path <repo> res://tests/test_runner.tscn -- --net=host
godot --headless --path <repo> res://tests/test_runner.tscn -- --net=client
```

## Android debug build
1. Godot editor > Editor > Manage Export Templates > download 4.3 templates.
2. Install Android Studio (or command-line SDK): SDK Platform 34, Build-Tools, Platform-Tools, NDK not required for GDScript.
3. Install JDK 17; set Editor Settings > Export > Android: Java SDK path + Android SDK path.
4. Debug keystore: Godot generates/uses `~/.android/debug.keystore` automatically when the field is left empty (or set Editor Settings > Export > Android > Debug Keystore).
5. Project > Export > preset **Android** (already in `export_presets.cfg`, arm64-v8a, landscape, internet permission) > Export Project (debug).
   CLI: `godot --headless --path <repo> --export-debug Android export/pocket_dogfight.apk`
6. Release builds need your own keystore: fill `keystore/release*` locally; never commit it.
