extends Node
## Autoload: cosmetic effects. Purely local; never authoritative.

signal shake_requested(strength: float)

const EXPLOSION_SCENE := preload("res://scenes/effects/explosion.tscn")
const HIT_FLASH_SCENE := preload("res://scenes/effects/hit_flash.tscn")


func shake(strength: float) -> void:
	shake_requested.emit(strength * Settings.screen_shake)


func explosion(position: Vector2, color: Color = Color.ORANGE, scale_factor: float = 1.0) -> void:
	var root := _fx_root()
	if root == null:
		return
	var fx := EXPLOSION_SCENE.instantiate()
	fx.global_position = position
	root.add_child(fx)
	fx.setup(color, scale_factor)


func hit(position: Vector2, color: Color = Color.WHITE) -> void:
	var root := _fx_root()
	if root == null:
		return
	var fx := HIT_FLASH_SCENE.instantiate()
	fx.global_position = position
	root.add_child(fx)
	fx.setup(color)


func _fx_root() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var fx := scene.find_child("FXLayer", true, false)
	return fx if fx != null else scene
