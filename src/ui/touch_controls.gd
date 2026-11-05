extends CanvasLayer
## On-screen controls for phones and touch laptops.
##
## The d-pad and bomb button write into InputRouter's virtual input slots, so
## touch uses the exact same command path (and bomb buffering) as keyboard/pad.
## Hidden automatically on desktop unless a touchscreen is present.

signal pause_pressed

const L10n = preload("res://src/app/l10n.gd")
const UiKit = preload("res://src/ui/ui_kit.gd")
const Dirs = preload("res://src/core/sim/dirs.gd")

const BUTTON_SIZE := 168
const GAP := 10
const PAD_MARGIN := 40

var _router
var _root: Control
var _bomb_button: Button
var _pause_button: Button
var _pad: Control
var _held: Dictionary = {}
var _last_dir := Vector2i.ZERO
var _active := false


func setup(router) -> void:
	_router = router
	layer = 1
	_build()
	retranslate()
	set_active(false)


func _build() -> void:
	_root = Control.new()
	_root.name = "TouchRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# D-pad: a 3x3 grid with the four arrows in a cross.
	_pad = Control.new()
	_pad.name = "DPad"
	_pad.anchor_left = 0.0
	_pad.anchor_top = 1.0
	_pad.anchor_right = 0.0
	_pad.anchor_bottom = 1.0
	var pad_size := BUTTON_SIZE * 3 + GAP * 2
	_pad.offset_left = PAD_MARGIN
	_pad.offset_right = PAD_MARGIN + pad_size
	_pad.offset_top = -PAD_MARGIN - pad_size
	_pad.offset_bottom = -PAD_MARGIN
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pad)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.add_child(grid)

	_add_dir_cell(grid, Dirs.UP, "▲")
	_add_dir_cell(grid, Vector2i.ZERO, "")
	_add_dir_cell(grid, Dirs.DOWN, "▼")
	_add_dir_cell(grid, Dirs.LEFT, "◀")
	_add_dir_cell(grid, Vector2i.ZERO, "")
	_add_dir_cell(grid, Dirs.RIGHT, "▶")
	_add_dir_cell(grid, Vector2i.ZERO, "")
	_add_dir_cell(grid, Vector2i.ZERO, "")
	_add_dir_cell(grid, Vector2i.ZERO, "")

	_bomb_button = _make_button("", 224, 40)
	_bomb_button.name = "BombButton"
	_bomb_button.anchor_left = 1.0
	_bomb_button.anchor_top = 1.0
	_bomb_button.anchor_right = 1.0
	_bomb_button.anchor_bottom = 1.0
	_bomb_button.offset_left = -PAD_MARGIN - 224
	_bomb_button.offset_top = -PAD_MARGIN - 224
	_bomb_button.offset_right = -PAD_MARGIN
	_bomb_button.offset_bottom = -PAD_MARGIN
	_bomb_button.button_down.connect(_on_bomb_down)
	_root.add_child(_bomb_button)

	_pause_button = _make_button("", 168, 26)
	_pause_button.name = "PauseButton"
	_pause_button.anchor_left = 1.0
	_pause_button.anchor_top = 0.0
	_pause_button.anchor_right = 1.0
	_pause_button.anchor_bottom = 0.0
	_pause_button.offset_left = -PAD_MARGIN - 168
	_pause_button.offset_top = PAD_MARGIN
	_pause_button.offset_right = -PAD_MARGIN
	_pause_button.offset_bottom = PAD_MARGIN + 168
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_root.add_child(_pause_button)


func _add_dir_cell(grid: GridContainer, dir: Vector2i, text: String) -> void:
	if dir == Vector2i.ZERO:
		var filler := Control.new()
		filler.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(filler)
		return
	var button := _make_button(text, BUTTON_SIZE, 52)
	button.button_down.connect(_on_dir_down.bind(dir))
	button.button_up.connect(_on_dir_up.bind(dir))
	grid.add_child(button)


func _make_button(text: String, size: int, font_size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(size, size)
	button.focus_mode = Control.FOCUS_NONE
	button.keep_pressed_outside = true
	button.add_theme_font_size_override("font_size", font_size)
	var idle := UiKit.box(Color(0.030, 0.045, 0.070, 0.46), Color(0.55, 0.70, 0.88, 0.55), 2, 18)
	var down := UiKit.box(Color(0.070, 0.150, 0.220, 0.72), UiKit.ACCENT, 3, 18)
	var hover := UiKit.box(Color(0.045, 0.075, 0.110, 0.58), UiKit.ACCENT, 2, 18)
	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", down)
	button.add_theme_stylebox_override("focus", UiKit.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 18))
	button.add_theme_color_override("font_color", Color(0.86, 0.93, 1.0, 0.92))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.95))
	button.add_theme_constant_override("outline_size", 6)
	return button


func retranslate() -> void:
	if _bomb_button != null:
		_bomb_button.text = L10n.t("touch.bomb")
	if _pause_button != null:
		_pause_button.text = L10n.t("touch.pause")


## RTL keeps the d-pad on the left: directions are physical, not textual.
func set_rtl(_rtl: bool) -> void:
	pass


func set_active(on: bool) -> void:
	_active = on
	visible = on
	if not on:
		_release_all()


func is_active() -> bool:
	return _active


func _on_dir_down(dir: Vector2i) -> void:
	_held[dir] = true
	_last_dir = dir
	_refresh_dir()


func _on_dir_up(dir: Vector2i) -> void:
	_held.erase(dir)
	if _last_dir == dir:
		_last_dir = Vector2i.ZERO if _held.is_empty() else _held.keys().back()
	_refresh_dir()


func _refresh_dir() -> void:
	if _router == null:
		return
	_router.set_virtual_dir(_last_dir if _active else Vector2i.ZERO)


func _on_bomb_down() -> void:
	if _router != null and _active:
		_router.trigger_virtual_bomb()


func _release_all() -> void:
	_held.clear()
	_last_dir = Vector2i.ZERO
	if _router != null:
		_router.set_virtual_dir(Vector2i.ZERO)
