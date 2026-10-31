class_name InputSource
extends Node
## Base class for anything that drives a ship: keyboard, touch, AI, or nothing (remote).

var input: ShipInput = ShipInput.new()


func update(_delta: float) -> void:
	pass
