extends "res://src/ui/screens/menu_panel.gd"
## Title / mode select. A live AI match runs behind the panel as an attract demo.

signal mode_selected(mode: int)
signal settings_requested
signal quit_requested

const AppFlow = preload("res://src/app/app_flow.gd")
const L10n = preload("res://src/app/l10n.gd")

var _tagline: Label
var _build_tag: Label
var _local: Button
var _solo: Button
var _settings_button: Button
var _quit_button: Button


func _build() -> void:
	var title := UiKit.label("FUSE", 150, UiKit.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 28)
	title.add_theme_color_override("font_outline_color", Color(0.040, 0.320, 0.520))
	_column.add_child(title)

	_tagline = UiKit.label("", 26, UiKit.ACCENT)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_tagline)

	_build_tag = UiKit.label("", 18, UiKit.TEXT_DIM)
	_build_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(_build_tag)

	_column.add_child(_spacer(26))

	_local = UiKit.button("")
	_local.pressed.connect(func() -> void: mode_selected.emit(AppFlow.MODE_2P))
	_column.add_child(_local)

	_solo = UiKit.button("")
	_solo.pressed.connect(func() -> void: mode_selected.emit(AppFlow.MODE_1P))
	_column.add_child(_solo)

	_settings_button = UiKit.button("")
	_settings_button.pressed.connect(func() -> void: settings_requested.emit())
	_column.add_child(_settings_button)

	_quit_button = UiKit.button("")
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())
	_column.add_child(_quit_button)

	add_footer("")
	retranslate()


func retranslate() -> void:
	_tagline.text = L10n.t("tagline")
	_build_tag.text = L10n.t("build_tag")
	_local.text = L10n.t("menu.local2p")
	_solo.text = L10n.t("menu.solo")
	_settings_button.text = L10n.t("menu.settings")
	_quit_button.text = L10n.t("menu.quit")
	set_footer(L10n.t("hint.nav"))


func _spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
