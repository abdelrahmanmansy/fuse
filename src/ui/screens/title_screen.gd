extends "res://src/ui/screens/menu_panel.gd"
## Title / mode select. A live AI match runs behind the panel as an attract demo.

signal mode_selected(mode: int)
signal settings_requested
signal quit_requested

const AppFlow = preload("res://src/app/app_flow.gd")


func _build() -> void:
	var title := UiKit.label("FUSE", 150, UiKit.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 28)
	title.add_theme_color_override("font_outline_color", Color(0.040, 0.320, 0.520))
	_column.add_child(title)

	var subtitle := UiKit.label("2 . 5 D   B O M B   A R E N A", 26, UiKit.ACCENT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(subtitle)

	var build_tag := UiKit.label("M2 preview · grey-box build", 18, UiKit.TEXT_DIM)
	build_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(build_tag)

	_column.add_child(_spacer(26))

	var local := UiKit.button("LOCAL VERSUS   ·   2 PLAYERS")
	local.pressed.connect(func() -> void: mode_selected.emit(AppFlow.MODE_2P))
	_column.add_child(local)

	var solo := UiKit.button("SOLO   ·   1 PLAYER VS CPU")
	solo.pressed.connect(func() -> void: mode_selected.emit(AppFlow.MODE_1P))
	_column.add_child(solo)

	var settings_button := UiKit.button("SETTINGS")
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	_column.add_child(settings_button)

	var quit := UiKit.button("QUIT")
	quit.pressed.connect(func() -> void: quit_requested.emit())
	_column.add_child(quit)

	add_footer("UP / DOWN choose    ·    ENTER or SPACE confirm    ·    controllers supported")


func _spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
