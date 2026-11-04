extends "res://src/ui/screens/menu_panel.gd"
## Between-round / end-of-series overlay with score, winner and next actions.

signal advance_requested
signal change_mode_requested
signal quit_requested

const Style = preload("res://src/render/arena_style.gd")
const AppFlow = preload("res://src/app/app_flow.gd")

var _round_label: Label
var _winner_label: Label
var _status: Label
var _score_labels: Array = []
var _primary: Button


func _build() -> void:
	var card := UiKit.panel(UiKit.ACCENT)
	_column.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(540, 0)
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	_round_label = UiKit.label("ROUND 1", 22, UiKit.TEXT_DIM)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_round_label)

	_winner_label = UiKit.label("PLAYER 1 WINS", 48)
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_winner_label)

	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 34)
	box.add_child(score_row)

	for i in 2:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(150, 0)
		column.add_theme_constant_override("separation", 0)
		var name := UiKit.label(AppFlow.player_label(i), 18, Style.PLAYER_COLORS[i])
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name)
		var value := UiKit.label("0", 56, UiKit.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(value)
		score_row.add_child(column)
		_score_labels.append(value)
		if i == 0:
			var dash := UiKit.label("—", 40, UiKit.TEXT_DIM)
			dash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			score_row.add_child(dash)

	_status = UiKit.label("", 18, UiKit.TEXT_DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	_column.add_child(_spacer(18))

	_primary = UiKit.button("NEXT ROUND")
	_primary.pressed.connect(func() -> void: advance_requested.emit())
	_column.add_child(_primary)

	var change := UiKit.button("CHANGE MODE")
	change.pressed.connect(func() -> void: change_mode_requested.emit())
	_column.add_child(change)

	var quit := UiKit.button("QUIT")
	quit.pressed.connect(func() -> void: quit_requested.emit())
	_column.add_child(quit)


## Populate from `flow` and show. `flow.rounds_played` already includes this round.
func open_with(flow) -> void:
	_round_label.text = "SERIES COMPLETE" if flow.series_over else "ROUND %d" % flow.round
	_score_labels[0].text = str(flow.wins[0])
	_score_labels[1].text = str(flow.wins[1])

	if flow.series_over:
		var champion: int = flow.series_winner()
		if champion >= 0:
			_winner_label.text = "%s TAKES THE SERIES" % AppFlow.player_label(champion)
			_winner_label.add_theme_color_override("font_color", Style.PLAYER_COLORS[champion])
		else:
			_winner_label.text = "SERIES DRAWN"
			_winner_label.add_theme_color_override("font_color", UiKit.TEXT)
		_status.text = "BEST OF %d   ·   %d ROUNDS PLAYED" % [flow.best_of, flow.rounds_played]
		_primary.text = "REMATCH"
	else:
		if flow.last_winner >= 0:
			_winner_label.text = "%s WINS" % AppFlow.player_label(flow.last_winner)
			_winner_label.add_theme_color_override("font_color", Style.PLAYER_COLORS[flow.last_winner])
		else:
			_winner_label.text = "ROUND DRAWN"
			_winner_label.add_theme_color_override("font_color", UiKit.TEXT)
		_status.text = "FIRST TO %d   ·   ROUND %d OF %d" % [flow.wins_needed(), flow.rounds_played, flow.best_of]
		_primary.text = "NEXT ROUND"

	open()


func _spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
