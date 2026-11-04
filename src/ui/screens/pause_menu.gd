extends "res://src/ui/screens/menu_panel.gd"
## Pause overlay. Owns no state; the app decides what each action means.

signal resume_requested
signal restart_requested
signal quit_requested

const L10n = preload("res://src/app/l10n.gd")

var _title_label: Label
var _hint_label: Label
var _resume: Button
var _restart: Button
var _quit: Button


func _build() -> void:
	var card := UiKit.panel(UiKit.GOLD)
	_column.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	_title_label = UiKit.label("", 64, UiKit.GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title_label)

	_hint_label = UiKit.label("", 20, UiKit.TEXT_DIM)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint_label)

	_column.add_child(_spacer(20))

	_resume = UiKit.button("")
	_resume.pressed.connect(func() -> void: resume_requested.emit())
	_column.add_child(_resume)

	_restart = UiKit.button("")
	_restart.pressed.connect(func() -> void: restart_requested.emit())
	_column.add_child(_restart)

	_quit = UiKit.button("")
	_quit.pressed.connect(func() -> void: quit_requested.emit())
	_column.add_child(_quit)

	retranslate()


func retranslate() -> void:
	_title_label.text = L10n.t("pause.title")
	_hint_label.text = L10n.t("pause.hint")
	_resume.text = L10n.t("pause.resume")
	_restart.text = L10n.t("pause.restart")
	_quit.text = L10n.t("pause.quit")


func _spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
