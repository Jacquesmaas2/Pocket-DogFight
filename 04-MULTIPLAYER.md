# Multiplayer Design

## Target
2-8 players.

## Architecture
Authoritative host/server. Authority determines damage, deaths, scoring, projectile validity, pickups and match state.

## First playable networking
- Host game
- Join game
- Localhost/LAN testing

Internet matchmaking is not required for the first playable build.

## Synchronization
Synchronize position, rotation, velocity, health, weapon events and death state. Use interpolation for remote ships where useful.

## Security
Never trust client-provided damage, kills, score, health or pickup ownership.

## Rule
Build multiplayer early. Do not build a complete single-player game and bolt networking on later.
