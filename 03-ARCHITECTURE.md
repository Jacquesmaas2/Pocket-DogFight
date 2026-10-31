# Technical Architecture

## Engine
Godot 4 with GDScript.

## Goals
Modular, understandable, multiplayer-aware and mobile-friendly.

## Major systems
- GameManager
- MatchManager
- NetworkManager
- PlayerManager
- ShipController
- WeaponSystem
- ProjectileSystem
- PowerUpSystem
- SpawnManager
- ScoreManager
- UIManager
- AudioManager
- VFXManager

## Suggested structure
res://
- scenes/game/
- scenes/arenas/
- scenes/ships/
- scenes/projectiles/
- scenes/ui/
- scripts/core/
- scripts/gameplay/
- scripts/multiplayer/
- scripts/ui/
- assets/sprites/
- assets/audio/
- assets/effects/
- resources/
- tests/

## Composition
Prefer reusable scenes/components over monolithic scripts.

## Multiplayer
Important gameplay systems must distinguish local input, optional local prediction, authoritative state and remote representation.

## Performance
Do not prematurely optimize. Pool frequently spawned objects only when useful.
