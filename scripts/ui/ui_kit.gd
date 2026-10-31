class_name UIKit
extends RefCounted
## Small helpers to build consistent, phone-readable UI in code.

const BG := Color(0.03, 0.05, 0.12, 0.92)
const PANEL := Color(0.08, 0.11, 0.22, 0.9)
const ACCENT := Color("4fd1ff")
const ACCENT2 := Color("ff8a3d")


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.12, 0.18, 0.36, 1.0)
	btn.set_corner_radius_all(10)
	btn.content_margin_left = 22
	btn.content_margin_right = 22
	btn.content_margin_top = 12
	btn.content_margin_bottom = 12
	btn.border_width_bottom = 3
	btn.border_color = Color(0.06, 0.09, 0.2)
	var hover := btn.duplicate()
	hover.bg_color = Color(0.18, 0.3, 0.55, 1.0)
	var pressed := btn.duplicate()
	pressed.bg_color = ACCENT.darkened(0.3)
	var disabled := btn.duplicate()
	disabled.bg_color = Color(0.1, 0.1, 0.14, 0.7)
	t.set_stylebox("normal", "Button", btn)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", hover)
	t.set_font_size("font_size", "Button", 24)
	var edit := StyleBoxFlat.new()
	edit.bg_color = Color(0.02, 0.03, 0.08, 1.0)
	edit.set_corner_radius_all(8)
	edit.content_margin_left = 12
	edit.content_margin_right = 12
	edit.content_margin_top = 8
	edit.content_margin_bottom = 8
	edit.border_width_bottom = 2
	edit.border_color = ACCENT
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit)
	t.set_font_size("font_size", "LineEdit", 22)
	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL
	panel.set_corner_radius_all(14)
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 18
	panel.content_margin_bottom = 18
	t.set_stylebox("panel", "PanelContainer", panel)
	return t


static func label(text: String, size: int = 22, color: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = align
	return l


static func title(text: String) -> Label:
	var l := label(text, 44, ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 8)
	return l


static func button(text: String, callback: Callable, min_width: float = 260.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 56)
	b.pressed.connect(func() -> void: Audio.play("ui_click", -6.0); callback.call())
	return b


static func spacer(h: float = 12.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(child)
	return p


static func fullscreen_bg(parent: Control) -> void:
	var cr := ColorRect.new()
	cr.color = BG
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cr)
	parent.move_child(cr, 0)
