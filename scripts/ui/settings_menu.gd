extends Control
## Settings overlay: name, ship, volumes, screen shake, touch controls.

var _name_edit: LineEdit
var _ship_opt: OptionButton
var _master: HSlider
var _music: HSlider
var _sfx: HSlider
var _shake: OptionButton
var _touch: CheckButton


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size.x = 260
	_add_row(grid, "Pilot name", _name_edit)
	_ship_opt = OptionButton.new()
	_ship_opt.add_item("The Syntiq (Jacques)")
	_ship_opt.set_item_metadata(0, "syntiq")
	_ship_opt.add_item("The Bad Idea (Loek)")
	_ship_opt.set_item_metadata(1, "bad_idea")
	_ship_opt.add_item("Pocket Fighter")
	_ship_opt.set_item_metadata(2, "generic")
	_add_row(grid, "Ship", _ship_opt)
	_master = _slider()
	_add_row(grid, "Master volume", _master)
	_music = _slider()
	_add_row(grid, "Music volume", _music)
	_sfx = _slider()
	_add_row(grid, "SFX volume", _sfx)
	_shake = OptionButton.new()
	_shake.add_item("Off")
	_shake.add_item("Reduced")
	_shake.add_item("Full")
	_add_row(grid, "Screen shake", _shake)
	_touch = CheckButton.new()
	_add_row(grid, "Force touch controls", _touch)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.add_child(UIKit.title("SETTINGS"))
	box.add_child(grid)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(UIKit.button("Save", _save, 180))
	row.add_child(UIKit.button("Cancel", func() -> void: visible = false, 180))
	box.add_child(row)
	var panel := UIKit.panel(box)
	panel.set_anchors_preset(PRESET_CENTER)
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -260
	panel.offset_bottom = 260
	add_child(panel)


func _add_row(grid: GridContainer, text: String, ctrl: Control) -> void:
	grid.add_child(UIKit.label(text, 20))
	ctrl.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.add_child(ctrl)


func _slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(260, 32)
	return s


func open() -> void:
	_name_edit.text = Settings.player_name
	for i in _ship_opt.item_count:
		if _ship_opt.get_item_metadata(i) == Settings.preferred_ship:
			_ship_opt.select(i)
	_master.value = Settings.master_volume
	_music.value = Settings.music_volume
	_sfx.value = Settings.sfx_volume
	_shake.select(0 if Settings.screen_shake <= 0.0 else (1 if Settings.screen_shake < 1.0 else 2))
	_touch.button_pressed = Settings.force_touch_controls
	visible = true


func _save() -> void:
	var n := _name_edit.text.strip_edges()
	Settings.player_name = n if not n.is_empty() else "Pilot"
	Settings.preferred_ship = str(_ship_opt.get_item_metadata(_ship_opt.selected))
	Settings.master_volume = _master.value
	Settings.music_volume = _music.value
	Settings.sfx_volume = _sfx.value
	Settings.screen_shake = [0.0, 0.5, 1.0][_shake.selected]
	Settings.force_touch_controls = _touch.button_pressed
	Settings.save_settings()
	visible = false
