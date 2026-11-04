extends CanvasLayer
## Match HUD: phase banner, clock, per-player stats and input hints.
## Presentation only — reads simulation state and never mutates it.

const Style = preload("res://src/render/arena_style.gd")
const MatchSim = preload("res://src/core/sim/match_sim.gd")

var _timer: Label
var _phase: Label
var _banner: Label
var _hint: Label
var _pause: Label
var _panels: Array = []


func setup(player_count: int) -> void:
	layer = 10

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_timer = _label(root, 56, Color(0.93, 0.95, 1.0))
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 0)
	_timer.offset_left = -180
	_timer.offset_right = 180
	_timer.offset_top = 14

	_phase = _label(root, 22, Color(0.80, 0.86, 0.95))
	_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 0)
	_phase.offset_left = -260
	_phase.offset_right = 260
	_phase.offset_top = 78

	for i in player_count:
		_panels.append(_build_panel(root, i, player_count))

	_banner = _label(root, 66, Color.WHITE)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 0)
	_banner.offset_left = -520
	_banner.offset_right = 520
	_banner.offset_top = -60
	_banner.offset_bottom = 60
	_banner.visible = false

	_pause = _label(root, 44, Color(0.98, 0.86, 0.55))
	_pause.text = "PAUSED\nEsc to resume"
	_pause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 0)
	_pause.offset_left = -260
	_pause.offset_right = 260
	_pause.offset_top = -70
	_pause.offset_bottom = 70
	_pause.visible = false

	_hint = _label(root, 19, Color(0.72, 0.79, 0.88))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = "P1 WASD + Space    P2 Arrows + Enter    R restart    1 / 2 mode    Esc pause"
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 0)
	_hint.offset_left = -620
	_hint.offset_right = 620
	_hint.offset_top = -36
	_hint.offset_bottom = -8


func update_from_sim(sim, mode: String, paused: bool) -> void:
	var clock: int = sim.rules.match_ticks if sim.phase == MatchSim.Phase.COUNTDOWN else sim.match_ticks_left
	var seconds := maxi(clock, 0) / 60
	_timer.text = "%d:%02d" % [seconds / 60, seconds % 60]
	_timer.add_theme_color_override("font_color",
		Color(1.0, 0.45, 0.35) if sim.phase == MatchSim.Phase.SUDDEN_DEATH else Color(0.93, 0.95, 1.0))

	_phase.text = _phase_text(sim, mode)

	for i in _panels.size():
		_update_panel(i, sim)

	_pause.visible = paused
	_banner.visible = false
	var countdown := ""
	if sim.phase == MatchSim.Phase.COUNTDOWN:
		var ticks: int = sim.phase_ticks_left
		var number := int(ceil(float(ticks) / 60.0))
		countdown = "GO!" if number <= 0 else str(number)
		if number > 3:
			countdown = "READY"
		_banner.text = countdown
		_banner.visible = true
	elif sim.phase == MatchSim.Phase.RESULTS:
		if sim.winner_id >= 0:
			_banner.text = "PLAYER %d WINS" % (sim.winner_id + 1)
			_banner.add_theme_color_override("font_color", Style.PLAYER_COLORS[sim.winner_id % Style.PLAYER_COLORS.size()])
		else:
			_banner.text = "DRAW"
			_banner.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		_banner.visible = true

	if sim.phase == MatchSim.Phase.PLAYING and sim.match_ticks_left > sim.rules.match_ticks - 30:
		_banner.text = "GO!"
		_banner.add_theme_color_override("font_color", Color(0.72, 1.0, 0.62))
		_banner.visible = true


func _phase_text(sim, mode: String) -> String:
	var phase := "SUDDEN DEATH" if sim.phase == MatchSim.Phase.SUDDEN_DEATH else ""

	if sim.phase == MatchSim.Phase.PLAYING:
		phase = "BATTLE"
	elif sim.phase == MatchSim.Phase.RESULTS:
		phase = "RESULTS"
	elif sim.phase == MatchSim.Phase.IDLE:
		phase = "STANDBY"
	elif sim.phase == MatchSim.Phase.COUNTDOWN:
		phase = "GET READY"
	return "%s   ·   %s" % [phase, mode]


func _build_panel(root: Control, index: int, player_count: int) -> Dictionary:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.027, 0.035, 0.051, 0.78)
	style.border_color = Style.PLAYER_COLORS[index % Style.PLAYER_COLORS.size()]
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	match index:
		0:
			panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 22)
		1:
			panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 22)
		2:
			panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 22)
		_:
			panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 22)
	if player_count <= 2 and index == 1:
		panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 22)

	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var name_label := _label(box, 24, Style.PLAYER_COLORS[index % Style.PLAYER_COLORS.size()])
	name_label.text = "PLAYER %d" % (index + 1)
	var stats := _label(box, 20, Color(0.92, 0.95, 1.0))
	stats.text = ""

	return {"panel": panel, "stats": stats, "name": name_label}


func _update_panel(index: int, sim) -> void:
	if index >= sim.players.size():
		_panels[index]["panel"].visible = false
		return
	var player = sim.players[index]
	var stats: Label = _panels[index]["stats"]
	var text := "BOMBS %d   RANGE %d   SPEED %d   KICK %s" % [
		player.capacity, player.blast_range, player.speed_level,
		"YES" if player.has_kick else "NO",
	]
	if not player.alive:
		text = "ELIMINATED"
		stats.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
	else:
		stats.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	if stats.text != text:
		stats.text = text


func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
