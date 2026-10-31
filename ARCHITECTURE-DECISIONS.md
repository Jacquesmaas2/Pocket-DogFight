# Architecture Decisions

## ADR-1: Owner-simulated movement, server-authoritative outcomes
Each peer simulates its own ship (responsive on mobile/latency) and streams transform+velocity at 20 Hz. The server never accepts client damage/health/score/pickup claims: hit detection, damage, death, kills, ammo, power-up collection, respawn and match state run only on the server and are replicated via `authority` RPCs. Collision damage is detected server-side from velocity discontinuities near world geometry, not from client reports. Remote ships are interpolated with velocity extrapolation.

## ADR-2: Story reuses the match scene with an offline peer
Story mode hosts with `OfflineMultiplayerPeer`, so the local instance *is* the server and every gameplay system (ships, weapons, AI, power-ups, anomalies) runs unchanged. `MissionRunner` scripts missions as coroutines on top of `MatchManager`. No separate single-player framework exists.

## ADR-3: Dual transport, tunnel-first hosting
`NetworkManager` abstracts ENet (UDP, LAN) and WebSocket (TCP). WebSocket is the default because the production plan is "host on a laptop behind a public HTTP tunnel" (cloudflared/ngrok), which cannot carry UDP. Join addresses starting with `ws://`/`wss://` select WebSocket; `enet://` forces ENet. Transport/port/public URL are configurable via UI, CLI (`--server --port= --transport=`) and env (`PD_PORT`, `PD_TRANSPORT`, `PD_PUBLIC_URL`) so gameplay code is never coupled to a hosting provider.

## ADR-4: Procedural art and generated audio placeholders
Ships, projectiles, asteroids, effects, portraits and UI are drawn in code; sounds fall back to generated WAV tones when `res://assets/audio/<id>.(ogg|wav|mp3)` is missing. The game is fully playable without an art pipeline; dropping real assets in requires no code changes.

## ADR-5: Tuning lives in Resources
`ShipStats`, `WeaponStats` and `MatchConfig` resources under `resources/` hold every tunable value; `Config` autoload is the single access point.
