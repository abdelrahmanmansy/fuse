extends "res://src/ui/screens/menu_panel.gd"
## Between-round / end-of-series overlay with score, winner and next actions.

signal advance_requested
signal change_mode_requested
signal quit_requested

const Style = preload("res://src/render/arena_style.gd")
const L10n = preload("res://src/app/l10n.gd")

var _round_label: Label
var _winner_label: Label
var _status: Label
var _score_labels: Array = []
var _name_labels: Array = []
var _primary: Button
var _change: Button
var _quit: Button


func _build() -> void:
	var card := UiKit.panel(UiKit.ACCENT)
	_column.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(540, 0)
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	_round_label = UiKit.label("", 22, UiKit.TEXT_DIM)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_round_label)

	_winner_label = UiKit.label("", 48)
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
		var name := UiKit.label("", 18, Style.PLAYER_COLORS[i])
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name)
		var value := UiKit.label("0", 56, UiKit.TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(value)
		score_row.add_child(column)
		_score_labels.append(value)
		_name_labels.append(name)
		if i == 0:
			var dash := UiKit.label("—", 40, UiKit.TEXT_DIM)
			dash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			score_row.add_child(dash)

	_status = UiKit.label("", 18, UiKit.TEXT_DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	_column.add_child(_spacer(18))

	_primary = UiKit.button("")
	_primary.pressed.connect(func() -> void: advance_requested.emit())
	_column.add_child(_primary)

	_change = UiKit.button("")
	_change.pressed.connect(func() -> void: change_mode_requested.emit())
	_column.add_child(_change)

	_quit = UiKit.button("")
	_quit.pressed.connect(func() -> void: quit_requested.emit())
	_column.add_child(_quit)

	retranslate()


func retranslate() -> void:
	for i in _name_labels.size():
		_name_labels[i].text = L10n.t("player") % (i + 1)
	_change.text = L10n.t("series.change")
	_quit.text = L10n.t("menu.quit")


## Populate from `flow` and show. `flow.rounds_played` already includes this round.
func open_with(flow) -> void:
	_round_label.text = L10n.t("series.complete") if flow.series_over else L10n.t("series.round") % flow.round
	_score_labels[0].text = str(flow.wins[0])
	_score_labels[1].text = str(flow.wins[1])

	if flow.series_over:
		var champion: int = flow.series_winner()
		if champion >= 0:
			_winner_label.text = L10n.t("series.winner") % (L10n.t("player") % (champion + 1))
			_winner_label.add_theme_color_override("font_color", Style.PLAYER_COLORS[champion])
		else:
			_winner_label.text = L10n.t("series.draw")
			_winner_label.add_theme_color_override("font_color", UiKit.TEXT)
		_status.text = L10n.t("series.summary") % [flow.best_of, flow.rounds_played]
		_primary.text = L10n.t("series.rematch")
	else:
		if flow.last_winner >= 0:
			_winner_label.text = L10n.t("series.round_winner") % (L10n.t("player") % (flow.last_winner + 1))
			_winner_label.add_theme_color_override("font_color", Style.PLAYER_COLORS[flow.last_winner])
		else:
			_winner_label.text = L10n.t("series.round_draw")
			_winner_label.add_theme_color_override("font_color", UiKit.TEXT)
		_status.text = L10n.t("series.status") % [flow.wins_needed(), flow.rounds_played, flow.best_of]
		_primary.text = L10n.t("series.next")

	open()


func _spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
