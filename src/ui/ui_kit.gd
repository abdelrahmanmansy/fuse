extends RefCounted
## Shared menu styling. One place for the palette, button focus ring and panels so
## every screen looks like the same product instead of default Godot chrome.

const Style = preload("res://src/render/arena_style.gd")

const TEXT := Color(0.930, 0.955, 1.000)
const TEXT_DIM := Color(0.620, 0.700, 0.820)
const ACCENT := Color(0.290, 0.780, 1.000)
const DANGER := Color(1.000, 0.408, 0.373)
const GOLD := Color(1.000, 0.796, 0.310)


static func label(text: String, size: int, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.92))
	node.add_theme_constant_override("outline_size", maxi(4, int(float(size) * 0.16)))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Dark scrim behind menus. Light enough that the live attract match still reads
## through, dark enough to keep white text high contrast.
static func dim(alpha: float = 0.58) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0.012, 0.018, 0.030, alpha)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect


static func box(fill: Color, border: Color, width: int, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(12)
	return style


static func button(text: String, size: int = 30) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(440, 64)
	node.focus_mode = Control.FOCUS_ALL
	node.add_theme_font_size_override("font_size", size)

	node.add_theme_stylebox_override("normal",
		box(Color(0.050, 0.068, 0.096, 0.94), Color(0.230, 0.300, 0.400, 0.90), 2))
	node.add_theme_stylebox_override("hover",
		box(Color(0.070, 0.108, 0.155, 0.97), ACCENT, 2))
	node.add_theme_stylebox_override("pressed",
		box(Color(0.090, 0.140, 0.200, 0.99), ACCENT, 3))
	node.add_theme_stylebox_override("focus",
		box(Color(0.0, 0.0, 0.0, 0.0), GOLD, 3))
	node.add_theme_stylebox_override("disabled",
		box(Color(0.040, 0.050, 0.065, 0.70), Color(0.20, 0.24, 0.30, 0.60), 2))

	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_focus_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", Color.WHITE)
	node.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.95))
	node.add_theme_constant_override("outline_size", 6)
	return node


static func panel(accent: Color = ACCENT, padding: int = 30) -> PanelContainer:
	var node := PanelContainer.new()
	var style := box(Color(0.028, 0.038, 0.055, 0.96), Color(accent.r, accent.g, accent.b, 0.55), 2, 18)
	style.set_content_margin_all(padding)
	node.add_theme_stylebox_override("panel", style)
	return node
