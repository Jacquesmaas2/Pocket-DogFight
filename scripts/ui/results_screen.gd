extends Control
## Match results + rematch / menu.

var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(UIKit.title("MATCH OVER"))
	_list = VBoxContainer.new()
	box.add_child(_list)
	_status = UIKit.label("", 18, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(UIKit.button("Rematch", _rematch, 200))
	row.add_child(UIKit.button("Main Menu", func() -> void: Game.return_to_menu(), 200))
	box.add_child(row)
	var panel := UIKit.panel(box)
	panel.set_anchors_preset(PRESET_CENTER)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -220
	panel.offset_bottom = 220
	add_child(panel)
	MatchManager.instance.match_ended.connect(_show)
	MatchManager.instance.state_changed.connect(func(s: int) -> void: if s != MatchManager.State.ENDED: visible = false)


func _show(results: Array) -> void:
	for c in _list.get_children():
		c.queue_free()
	var rank := 1
	for r in results:
		var color := Net.player_color(r["id"])
		var txt := "%d.  %-14s  %3d pts   K%d D%d" % [rank, r["name"], r["score"], r["kills"], r["deaths"]]
		if rank == 1:
			txt += "   WINNER"
		_list.add_child(UIKit.label(txt, 22, color))
		rank += 1
	_status.text = "Host can start a rematch" if not Net.is_server() else ""
	visible = true


func _rematch() -> void:
	_status.text = "Rematch requested..."
	MatchManager.instance.request_rematch()
