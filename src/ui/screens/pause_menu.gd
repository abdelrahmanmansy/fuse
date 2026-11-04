extends "res://src/ui/screens/menu_panel.gd"
## Pause overlay. Owns no state; the app decides what each action means.

signal resume_requested
signal restart_requested
signal quit_requested


func _build() -> void:
	var card := UiKit.panel(UiKit.GOLD)
	_column.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var title := UiKit.label("PAUSED", 64, UiKit.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var hint := UiKit.label("ESC resumes", 20, UiKit.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	_column.add_child(_spacer(20))

	var resume := UiKit.button("RESUME")
	resume.pressed.connect(func() -> void: resume_requested.emit())
	_column.add_child(resume)

	var restart := UiKit.button("RESTART ROUND")
	restart.pressed.connect(func() -> void: restart_requested.emit())
	_column.add_child(restart)

	var quit := UiKit.button("QUIT TO TITLE")
	quit.pressed.connect(func() -> void: quit_requested.emit())
	_column.add_child(quit)


func _spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
