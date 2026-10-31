class_name LocalInputSource
extends InputSource
## Merges keyboard actions with the on-screen touch controls (if present).

var touch: Node = null # TouchControls, optional


func update(_delta: float) -> void:
	input.thrust = Input.get_action_strength("thrust")
	input.turn = Input.get_action_strength("rotate_right") - Input.get_action_strength("rotate_left")
	input.boost = Input.is_action_pressed("boost")
	input.fire_primary = Input.is_action_pressed("fire_primary")
	input.fire_secondary = Input.is_action_just_pressed("fire_secondary")
	if touch != null and is_instance_valid(touch) and touch.visible:
		input.thrust = maxf(input.thrust, touch.thrust)
		if absf(touch.turn) > absf(input.turn):
			input.turn = touch.turn
		input.boost = input.boost or touch.boost
		input.fire_primary = input.fire_primary or touch.fire_primary
		input.fire_secondary = input.fire_secondary or touch.consume_fire_secondary()
