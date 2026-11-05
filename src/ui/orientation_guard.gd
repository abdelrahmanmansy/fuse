extends CanvasLayer
## Full-screen "rotate your phone" guard for portrait touch sessions.
##
## The arena, HUD and touch pads are designed for a 16:9 landscape view, so a
## portrait phone would show a letterboxed slice. This overlay blocks the view
## until the phone is turned; it never touches simulation state.

const L10n = preload("res://src/app/l10n.gd")
const UiKit = preload("res://src/ui/ui_kit.gd")

var _root: Control
var _title: Label
var _hint: Label


func setup() -> void:
	layer = 4
	_build()
	retranslate()
	set_active(false)


func _build() -> void:
	_root = Control.new()
	_root.name = "OrientationRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var bg := ColorRect.new()
	bg.name = "OrientationBackground"
	bg.color = Color(0.012, 0.018, 0.030, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)

	var glyph := Label.new()
	glyph.text = "⟲"
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", 96)
	glyph.add_theme_color_override("font_color", UiKit.ACCENT)
	column.add_child(glyph)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	_title.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	column.add_child(_title)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 26)
	_hint.add_theme_color_override("font_color", Color(0.62, 0.72, 0.84))
	column.add_child(_hint)


func retranslate() -> void:
	if _title != null:
		_title.text = L10n.t("touch.rotate_title")
	if _hint != null:
		_hint.text = L10n.t("touch.rotate_hint")
	if _root != null:
		_root.layout_direction = Control.LAYOUT_DIRECTION_RTL if L10n.is_rtl() \
			else Control.LAYOUT_DIRECTION_LTR


func set_rtl(_rtl: bool) -> void:
	retranslate()


func set_active(on: bool) -> void:
	visible = on
	if _root != null:
		_root.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func is_active() -> bool:
	return visible


## True when the window is taller than it is wide.
func is_portrait() -> bool:
	var size := get_window().size
	return size.y > size.x
