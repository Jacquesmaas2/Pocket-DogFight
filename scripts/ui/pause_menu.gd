extends Control
## Pause/back overlay. Multiplayer never pauses the tree; it only shows the menu.

var _panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.add_child(UIKit.title("PAUSED"))
	box.add_child(UIKit.button("Resume", _toggle))
	box.add_child(UIKit.button("Settings", func() -> void: get_parent().get_node("Settings").open()))
	box.add_child(UIKit.button("Leave to Menu", func() -> void: Game.return_to_menu()))
	_panel = UIKit.panel(box)
	_panel.set_anchors_preset(PRESET_CENTER)
	_panel.offset_left = -200
	_panel.offset_right = 200
	_panel.offset_top = -170
	_panel.offset_bottom = 170
	add_child(_panel)
	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.custom_minimum_size = Vector2(56, 48)
	pause_btn.set_anchors_preset(PRESET_TOP_RIGHT)
	pause_btn.offset_left = -70
	pause_btn.offset_right = -14
	pause_btn.offset_top = 96
	pause_btn.offset_bottom = 144
	pause_btn.pressed.connect(_toggle)
	get_parent().call_deferred("add_child", pause_btn)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	visible = not visible
	if not Net.is_online():
		get_tree().paused = visible
