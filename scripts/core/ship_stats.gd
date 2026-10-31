class_name ShipStats
extends Resource
## Tunable flight and durability values for one ship type.

@export var display_name: String = "Ship"
@export var visual_variant: String = "generic" # generic | syntiq | bad_idea | scrap | security | corp
@export var acceleration: float = 900.0
@export var rotation_speed: float = 4.2 # rad/s
@export var max_velocity: float = 520.0
@export var damping: float = 0.6 # per-second linear damp factor
@export var max_health: int = 3
@export var boost_multiplier: float = 1.8
@export var collision_damage_speed: float = 420.0 # relative impact speed that deals 1 damage
@export var missile_ammo: int = 2
