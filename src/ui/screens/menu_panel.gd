extends CanvasLayer
## Base for full-screen menu overlays: dimmed backdrop + centred column.
## Subclasses implement `_build()` and add labels/buttons to `_column`.

const UiKit = preload("res://src/ui/ui_kit.gd")

var _root: Control
var _column: VBoxContainer


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_root.add_child(UiKit.dim())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 14)
	center.add_child(_column)

	_build()
	visible = false


## Subclass hook: populate `_column`.
func _build() -> void:
	pass


## Add a full-width line under the centred column (e.g. control hints).
func add_footer(text: String, color: Color = UiKit.TEXT_DIM) -> void:
	var footer := UiKit.label(text, 20, color)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 0)
	footer.offset_left = -720
	footer.offset_right = 720
	footer.offset_top = -44
	footer.offset_bottom = -14
	_root.add_child(footer)


func open() -> void:
	visible = true
	_focus_first()


func close() -> void:
	visible = false
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused):
		get_viewport().gui_release_focus()


func _focus_first() -> void:
	# Search nested containers too: settings keeps its controls inside a card.
	var target := _first_focusable(_column)
	if target != null:
		target.grab_focus()


func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control and (child as Control).focus_mode == Control.FOCUS_ALL \
				and (child as Control).visible and not (child as Control).is_queued_for_deletion():
			return child
		if child.get_child_count() > 0:
			var nested := _first_focusable(child)
			if nested != null:
				return nested
	return null
