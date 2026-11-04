extends "res://src/ui/screens/menu_panel.gd"
## Settings overlay: volumes, series length, fullscreen, language. Values are written
## back to the `Settings` object immediately; the app persists and applies them.

signal closed
signal values_changed

const Settings = preload("res://src/app/settings.gd")
const L10n = preload("res://src/app/l10n.gd")

var _settings
var _title_label: Label
var _master_label: Label
var _sfx_label: Label
var _series_button: Button
var _fullscreen_button: Button
var _language_button: Button
var _back_button: Button
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}


func _build() -> void:
	var card := UiKit.panel(UiKit.ACCENT)
	_column.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)

	_title_label = UiKit.label("", 54, UiKit.TEXT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title_label)

	var master_row := _volume_row("master_volume")
	_master_label = master_row["label"]
	box.add_child(master_row["row"])

	var sfx_row := _volume_row("sfx_volume")
	_sfx_label = sfx_row["label"]
	box.add_child(sfx_row["row"])

	_series_button = UiKit.button("", 26)
	_series_button.custom_minimum_size = Vector2(620, 58)
	_series_button.pressed.connect(_cycle_series)
	box.add_child(_series_button)

	_fullscreen_button = UiKit.button("", 26)
	_fullscreen_button.custom_minimum_size = Vector2(620, 58)
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	box.add_child(_fullscreen_button)

	_language_button = UiKit.button("", 26)
	_language_button.custom_minimum_size = Vector2(620, 58)
	_language_button.pressed.connect(_cycle_language)
	box.add_child(_language_button)

	_column.add_child(_spacer(18))

	_back_button = UiKit.button("")
	_back_button.pressed.connect(_on_back)
	_column.add_child(_back_button)

	add_footer("")
	retranslate()


func _volume_row(key: String) -> Dictionary:
	# Frame gives sliders a visible keyboard focus ring (Buttons get one for free).
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _row_style(false))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	frame.add_child(row)

	var name_label := UiKit.label("", 24, UiKit.TEXT)
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
	return {"row": frame, "label": name_label}


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
	retranslate()
	open()


func retranslate() -> void:
	_title_label.text = L10n.t("settings.title")
	_master_label.text = L10n.t("settings.master")
	_sfx_label.text = L10n.t("settings.sfx")
	_back_button.text = L10n.t("settings.back")
	set_footer(L10n.t("settings.hint"))
	_refresh_control_labels()


func _refresh_control_labels() -> void:
	var best_of: int = _settings.best_of if _settings != null else 3
	var fullscreen: bool = _settings.fullscreen if _settings != null else false
	var code: String = _settings.locale if _settings != null else L10n.locale
	_series_button.text = L10n.t("settings.series") % best_of
	_fullscreen_button.text = L10n.t("settings.fullscreen_on" if fullscreen else "settings.fullscreen_off")
	_language_button.text = L10n.t("settings.language") % L10n.t("lang." + code)


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
	_refresh_control_labels()
	values_changed.emit()


func _toggle_fullscreen() -> void:
	if _settings == null:
		return
	_settings.fullscreen = not _settings.fullscreen
	_refresh_control_labels()
	values_changed.emit()


func _cycle_language() -> void:
	if _settings == null:
		return
	_settings.locale = "ar" if _settings.locale == "en" else "en"
	L10n.set_locale(_settings.locale)
	values_changed.emit()


func _on_back() -> void:
	closed.emit()


func _spacer(height: int) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
