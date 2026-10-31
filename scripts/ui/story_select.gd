extends Control
## Story mission select.

const MISSIONS := [
	["Just Another Tuesday", "Race Loek through the belt. Learn to fly, shoot and boost."],
	["The Core", "Investigate the wreck. Take the glowing thing. Regret it."],
	["Everybody Wants It", "Scrap Rats, Galactic Security, missiles and power-ups."],
	["The Core Wakes Up", "Gravity wells, wormholes, slow fields and weapon overcharge."],
	["Oh.", "Something enormous arrives. Everyone stops shooting each other."],
	["Finale: Race You", "Beat Loek to the Core while the gate battle explodes around you."],
]


func _ready() -> void:
	theme = UIKit.theme()
	set_anchors_preset(PRESET_FULL_RECT)
	UIKit.fullscreen_bg(self)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(UIKit.title("LOEK & JACQUES"))
	box.add_child(UIKit.label("Two pilots. One questionable situation. Absolutely no plan.", 18, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.spacer(6))
	for i in MISSIONS.size():
		var unlocked := i <= Game.story_progress or OS.is_debug_build()
		var b := UIKit.button("%d. %s" % [i + 1, MISSIONS[i][0]] if unlocked else "%d. ???" % (i + 1), func() -> void: Game.start_story_mission(i), 520)
		b.disabled = not unlocked
		b.tooltip_text = MISSIONS[i][1]
		box.add_child(b)
	box.add_child(UIKit.spacer(6))
	box.add_child(UIKit.button("Back", func() -> void: Game.goto("menu"), 200))
	box.set_anchors_preset(PRESET_CENTER)
	box.offset_left = -270
	box.offset_right = 270
	box.offset_top = -320
	box.offset_bottom = 320
	add_child(box)
