class_name ShipInput
extends RefCounted
## Frame input for a ship. Gameplay code only reads this, never raw events.

var thrust: float = 0.0 # 0..1
var turn: float = 0.0 # -1..1 (left negative)
var boost: bool = false
var fire_primary: bool = false
var fire_secondary: bool = false


func clear() -> void:
	thrust = 0.0
	turn = 0.0
	boost = false
	fire_primary = false
	fire_secondary = false


func to_packed() -> PackedFloat32Array:
	return PackedFloat32Array([thrust, turn, 1.0 if boost else 0.0])
