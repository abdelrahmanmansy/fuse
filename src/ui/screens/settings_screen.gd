extends "res://src/ui/screens/menu_panel.gd"
## Settings overlay: series length, volumes, fullscreen. Values are written back
## to the `Settings` object immediately and saved by the app.

signal closed
signal values_changed

const Settings = preload("res://src/app/settings.gd")

var _settings
var _series_button: Button
var _fullscreen_button: Button
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}


func _build() -> void:
	var card := UiKit.panel(UiKit.ACCENT)
	_column.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)

	var title := UiKit.label("SETTINGS", 54, UiKit.TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(_volume_row("MASTER VOLUME", "master_volume"))
	box.add_child(_volume_row("SFX VOLUME", "sfx_volume"))

	_series_button = UiKit.button("SERIES: BEST OF 3", 26)
	_series_button.custom_minimum_size = Vector2(620, 58)
	_series_button.pressed.connect(_cycle_series)
	box.add_child(_series_button)

	_fullscreen_button = UiKit.button("FULLSCREEN: OFF", 26)
	_fullscreen_button.custom_minimum_size = Vector2(620, 58)
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	box.add_child(_fullscreen_button)

	_column.add_child(_spacer(18))

	var back := UiKit.button("BACK")
	back.pressed.connect(_on_back)
	_column.add_child(back)

	add_footer("UP / DOWN choose    ·    LEFT / RIGHT adjust    ·    ENTER confirm")


func _volume_row(title: String, key: String) -> Control:
	# Frame gives sliders a visible keyboard focus ring (Buttons get one for free).
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _row_style(false))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	frame.add_child(row)

	var name_label := UiKit.label(title, 24, UiKit.TEXT)
	name_label.custom_minimum_size = Vector2(240, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 5.0
	slider.custom_minimum_size = Vector2(300, 44)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(_on_volume_changed.bind(key))
	slider.focus_entered.connect(_set_row_focus.bind(frame, true))
	slider.focus_exited.connect(_set_row_focus.bind(frame, false))
	row.add_child(slider)
	_sliders[key] = slider

	var value := UiKit.label("0%", 22, UiKit.TEXT_DIM)
	value.custom_minimum_size = Vector2(72, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	_value_labels[key] = value
	return frame


func _row_style(focused: bool) -> StyleBoxFlat:
	var style := UiKit.box(
		Color(0.060, 0.090, 0.130, 0.55) if focused else Color(0, 0, 0, 0),
		UiKit.GOLD if focused else Color(0, 0, 0, 0), 2, 8)
	style.set_content_margin_all(6)
	return style


func _set_row_focus(frame: PanelContainer, focused: bool) -> void:
	frame.add_theme_stylebox_override("panel", _row_style(focused))


func open_with(settings) -> void:
	_settings = settings
	_sliders["master_volume"].set_value_no_signal(settings.master_volume * 100.0)
	_sliders["sfx_volume"].set_value_no_signal(settings.sfx_volume * 100.0)
	_value_labels["master_volume"].text = "%d%%" % roundi(settings.master_volume * 100.0)
	_value_labels["sfx_volume"].text = "%d%%" % roundi(settings.sfx_volume * 100.0)
	_series_button.text = "SERIES: BEST OF %d" % settings.best_of
	_fullscreen_button.text = "FULLSCREEN: ON" if settings.fullscreen else "FULLSCREEN: OFF"
	open()


func _on_volume_changed(value: float, key: String) -> void:
	if _settings == null:
		return
	_settings.set(key, value / 100.0)
	_value_labels[key].text = "%d%%" % roundi(value)
	values_changed.emit()


func _cycle_series() -> void:
	if _settings == null:
		return
	var choices: Array[int] = Settings.BEST_OF_CHOICES
	var index := choices.find(_settings.best_of)
	_settings.best_of = choices[(index + 1) % choices.size()]
	_series_button.text = "SERIES: BEST OF %d" % _settings.best_of
	values_changed.emit()


func _toggle_fullscreen() -> void:
	if _settings == null:
		return
	_settings.fullscreen = not _settings.fullscreen
	_fullscreen_button.text = "FULLSCREEN: ON" if _settings.fullscreen else "FULLSCREEN: OFF"
	values_changed.emit()


func _on_back() -> void:
	closed.emit()


func _spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
