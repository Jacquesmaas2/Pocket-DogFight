class_name WeaponStats
extends Resource
## Tunable values for a weapon. Used for both lasers and missiles.

@export var weapon_id: String = "laser"
@export var damage: int = 1
@export var cooldown: float = 0.22
@export var projectile_speed: float = 1100.0
@export var lifetime: float = 1.2
@export var turn_rate: float = 3.0 # rad/s, missiles only
@export var explosion_radius: float = 90.0 # missiles only
@export var lock_range: float = 900.0 # missiles only
@export var lock_cone_degrees: float = 45.0 # missiles only
