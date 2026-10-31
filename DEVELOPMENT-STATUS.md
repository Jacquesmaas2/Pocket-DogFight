# Development Status

Validation legend: **executed** = ran successfully in this environment with Godot 4.3 headless; **not executed** = requires a device/hand/eye.

| Phase | Status | Implemented | Key files | Validation | Limitations / external |
|---|---|---|---|---|---|
| 0 Foundation | Done | project.godot (autoloads, input map, layers, landscape), folder structure, bootstrap, tuning resources | `project.godot`, `scenes/bootstrap/`, `scripts/core/config.gd`, `resources/**` | executed: import without parse errors; main scene + all scenes/resources load (test suite) | — |
| 1 Flying | Done | Thrust/rotation/momentum/damping/velocity cap/boost, bounce collisions, camera follow + look-ahead, keyboard input abstraction | `scripts/gameplay/ship.gd`, `scripts/input/*`, `scripts/gameplay/game_camera.gd` | executed: thrust moves, turn rotates (tests). **not executed**: feel tuning by hand | tune `resources/ships/*.tres` after playtest |
| 2 Combat | Done | Laser projectiles, cooldown, hits, damage, health, death/explosion | `projectile.gd`, `projectile_manager.gd`, `weapon_system.gd`, `explosion.gd` | executed: spawn, cooldown reject, single damage, self-hit reject, death disables control | — |
| 3 MP Foundation | Done | Host/join (ENet + WebSocket), player registry, names, colours, spawning, late join sync, disconnect handling | `scripts/multiplayer/network_manager.gd`, `ship_registry.gd` | executed: two headless instances host/join, both see both ships, client removal on disconnect | — |
| 4 MP Combat | Done | Server-authoritative damage/death/respawn/score, RPC authority modes, owner-only transform filter, collision damage server-side | `match_manager.gd`, `ship.gd` | executed: death + score replicated to client; RPC annotations audited by test | — |
| 5 Match | Done | Countdown, 3-min timer (configurable), scoreboard, results, rematch, late-join | `match_manager.gd`, `hud.gd`, `results_screen.gd` | executed: COUNTDOWN→ACTIVE→ENDED→rematch, results ordering | — |
| 6 Mobile | Done | Multitouch stick + fire/missile/boost buttons, safe margins, landscape config, HUD essentials, canvas_items stretch | `touch_controls.gd`, `project.godot` | executed: anchors/positions inside viewport (test). **not executed**: real device test | needs Android device run |
| 7 Juice | Done | Trails, muzzle/hit flashes, impact sparks, debris particles, oversized explosions, shake (settable off/reduced/full), kill confirm, generated placeholder SFX | `vfx_manager.gd`, `audio_manager.gd`, effects scenes | executed: buses exist, effects scenes load. **not executed**: audio/visual review | real audio files optional under `assets/audio/` |
| 8 Missiles | Done | Ammo, cone/range lock, homing turn rate, trail, lock warning, splash radius, server validation | `weapon_system.gd`, `projectile.gd`, `hud.gd` | executed: target pick, ammo consume, lock registered | — |
| 9 Arena | Done | Asteroid Belt: walls, seeded asteroids, 8 safe spawns, 5 power-up spots, stars/nebula, safe respawn selection | `arena.gd`, `asteroid.gd`, `scenes/arenas/asteroid_belt.tscn` | executed: scene loads, spawns used by match | more arenas later |
| 10 Power-ups | Done | Shield, Rapid Fire, Missile Refill, Boost (+Overcharge/Core for story), server collection, timed effects, HUD display | `powerup_manager.gd`, `powerup.gd` | executed: authoritative collect applies shield | — |
| 11 Polish | Done | Main menu, host dialog, join, lobby, settings (name, ship, volumes, shake, touch), pause, persistence | `scripts/ui/*`, `settings.gd` | executed: menu boots headless without errors. **not executed**: visual layout review | — |
| 12 Online | Done (local-first) | Transport abstraction, laptop hosting + public tunnel workflow, headless dedicated server entry point, env/CLI config, Linux server export preset | `network_manager.gd`, `bootstrap.gd`, `tools/start_tunnel.ps1`, `tools/run_server.ps1`, `export_presets.cfg` | executed: ENet two-instance test. **not executed**: WebSocket through a real tunnel (needs cloudflared/ngrok installed) | install cloudflared or ngrok; no credentials committed |
| Story | Done | 6 playable missions (Tuesday, Core, Everybody, Wakes Up, Oh., Finale), dialogue strip with procedural portraits of Jacques/Loek, objectives, race, anomalies, Leviathan, reusable combat AI | `scripts/story/*`, `ai_input_source.gd`, `anomaly_zone.gd`, `leviathan.gd` | executed: mission 1 spawns Jacques + Loek and is playable (test). **not executed**: full playthrough of all missions | balance pass needed |

## Test run (latest)
- `tests/test_runner.tscn` local: **59 passed, 0 failed**
- Two-instance network test: host **6 passed**, client **5 passed**, 0 failed
- Import/parse: no errors
- Known harmless warnings: redundant `await` on non-coroutine spawn helpers in mission scripts.

## Remaining external requirements
- Android: export templates, Android SDK, JDK 17, debug keystore (auto) / release keystore (yours). See RUNBOOK.md.
- Tunnel: `cloudflared` or `ngrok` installed on the hosting laptop.
- Optional: real audio files in `assets/audio/` (`engine, laser, laser_impact, missile_launch, missile_warning, explosion, collision, powerup, countdown, countdown_go, win, loss, ui_click, respawn`).
