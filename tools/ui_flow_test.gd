extends SceneTree
## End-to-end menu flow check driven by synthesized keyboard events.
##
##   godot --headless --path . --script res://tools/ui_flow_test.gd
##
## Loads the real main scene, navigates the title with the keyboard, pauses,
## fast-forwards a real AI match to a result, plays out a full series and quits
## to title. Fails (exit 1) on the first broken expectation.

const MainScene = preload("res://scenes/main.tscn")
const AppFlow = preload("res://src/app/app_flow.gd")
const MatchSim = preload("res://src/core/sim/match_sim.gd")
const L10n = preload("res://src/app/l10n.gd")

var _main
var _failures: Array[String] = []
var _checks: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	_main = MainScene.instantiate()
	root.add_child(_main)
	await _settle()

	_check(_main._flow.screen == AppFlow.Screen.TITLE, "boots to the title screen")
	_check(_main._title.visible, "title panel is visible")
	_check(not _main._hud.visible, "HUD is hidden behind the title")
	_check(_main._flow.round == 0, "no series has started")

	# Keep this run from touching the player's real settings file.
	_main._settings.path = "user://settings_uitest.json"

	# Never inherit a locale from an earlier run: the Arabic toggle below assumes
	# the session starts in English.
	if _main._settings.locale != "en":
		_main._settings.locale = "en"
		_main._on_settings_changed()
	_check(L10n.locale == "en", "UI test runs in English first")

	# Settings screen: reachable from the title, adjustable and savable.
	var series_before: int = _main._settings.best_of
	var volume_before: float = _main._settings.master_volume
	await _press(KEY_DOWN)          # SOLO
	await _press(KEY_DOWN)          # SETTINGS
	await _press(KEY_ENTER)         # open settings
	_check(_main._settings_screen.visible, "SETTINGS opens the settings screen")
	_check(not _main._title.visible, "title hides behind settings")

	# First focus is the master-volume slider; RIGHT raises it.
	await _press(KEY_RIGHT)
	await _press(KEY_RIGHT)
	_check(_main._settings.master_volume > volume_before, "RIGHT raises master volume")
	var expected_master: float = _main._settings.master_volume * _main._settings.sfx_volume
	_check(absf(_main._audio.master - clampf(expected_master, 0.0, 1.0)) <= 0.001,
		"audio director follows the volume settings")

	# Move down to SERIES and cycle the length.
	await _press(KEY_DOWN)          # sfx slider
	await _press(KEY_DOWN)          # series button
	await _press(KEY_ENTER)         # cycle
	_check(_main._settings.best_of != series_before,
		"ENTER cycles the series length")
	_check(_main._flow.best_of == _main._settings.best_of,
		"flow adopts the new series length")

	# Normalise to best-of-3 so the rest of this run is deterministic.
	_main._settings.best_of = 3
	_main._on_settings_changed()
	_check(_main._flow.best_of == 3, "series length set back to best of 3")

	# Move to LANGUAGE, switch to Arabic and confirm live retranslation + RTL.
	await _press(KEY_DOWN)          # fullscreen
	await _press(KEY_DOWN)          # language
	await _press(KEY_ENTER)         # switch to Arabic
	_check(_main._settings.locale == "ar", "ENTER switches to Arabic")
	_check(L10n.locale == "ar", "localization layer follows the setting")
	_check(_main._settings_screen._title_label.text == L10n.table("ar")["settings.title"],
		"settings title retranslates immediately")
	_check(_main._settings_screen._root.layout_direction == Control.LAYOUT_DIRECTION_RTL,
		"settings layout mirrors for Arabic")
	_check(_main._title._tagline.text == L10n.table("ar")["tagline"],
		"hidden screens retranslate too")
	await _press(KEY_ENTER)         # back to English
	_check(_main._settings.locale == "en", "ENTER switches back to English")
	_check(L10n.locale == "en", "localization layer follows back to English")
	_check(_main._settings_screen._root.layout_direction == Control.LAYOUT_DIRECTION_LTR,
		"layout returns to left-to-right")

	# Leave via BACK.
	await _press(KEY_DOWN)          # back
	await _press(KEY_ENTER)
	_check(not _main._settings_screen.visible, "BACK closes settings")
	_check(_main._title.visible, "title returns after settings")

	# ESC also backs out of settings.
	await _press(KEY_DOWN)          # SOLO
	await _press(KEY_DOWN)          # SETTINGS
	await _press(KEY_ENTER)
	_check(_main._settings_screen.visible, "settings opens a second time")
	await _press(KEY_ESCAPE)
	_check(not _main._settings_screen.visible, "ESC closes settings")
	_check(_main._title.visible, "title returns after ESC")

	# Navigate: first button is LOCAL VERSUS, DOWN moves focus to SOLO.
	await _press(KEY_DOWN)
	await _press(KEY_ENTER)
	_check(_main._flow.screen == AppFlow.Screen.MATCH, "ENTER starts the selected mode")
	_check(_main._flow.mode == AppFlow.MODE_1P, "DOWN selected 1P vs CPU")
	_check(_main._flow.round == 1, "series starts at round 1")
	_check(not _main._title.visible, "title closes when the match starts")
	_check(_main._hud.visible, "HUD appears in the match")

	await _press(KEY_ESCAPE)
	_check(_main._paused, "ESC pauses the match")
	_check(_main._pause_menu.visible, "pause menu appears")

	await _press(KEY_ESCAPE)
	_check(not _main._paused, "ESC resumes the match")
	_check(not _main._pause_menu.visible, "pause menu disappears")

	# Stop engine stepping and drive the real simulation to a genuine result.
	_main.set_physics_process(false)
	var first_winner := await _play_round()
	_check(first_winner >= 0, "round 1 produced a winner")
	_check(_main.sim.phase == MatchSim.Phase.RESULTS, "simulation is in results")
	_check(_main._flow.screen == AppFlow.Screen.RESULTS, "flow switched to results")
	_check(_main._series.visible, "series panel is visible")
	_check(not _main._hud.visible, "HUD hides under the series panel")
	var scored: int = _main._flow.wins[0] + _main._flow.wins[1]
	_check(scored == 1, "exactly one round win recorded (got %d)" % scored)
	_check(_main._flow.wins[first_winner] == 1, "the winning side got the point")

	await _press(KEY_ENTER)
	_check(_main._flow.screen == AppFlow.Screen.MATCH, "NEXT ROUND returns to the match")
	_check(_main._flow.round == 2, "round counter advanced to 2")
	_check(not _main._series.visible, "series panel closed")
	_check(_main._hud.visible, "HUD restored for round 2")

	var second_winner := await _play_round()
	_check(second_winner == first_winner, "same CPU wins the second round")
	_check(_main._flow.series_over, "2-0 ends a best-of-3 series")
	_check(_main._flow.series_winner() == first_winner, "series winner is the round winner")
	_check(_main._series.visible, "series panel shows the final result")

	await _press(KEY_ENTER)
	_check(_main._flow.screen == AppFlow.Screen.MATCH, "REMATCH starts a fresh series")
	_check(_main._flow.wins == [0, 0], "rematch clears the score")
	_check(_main._flow.round == 1, "rematch resets to round 1")

	# Pause must work again after the manual stepping; then use the menu to leave.
	_main.set_physics_process(true)
	await _press(KEY_ESCAPE)
	_check(_main._paused, "ESC pauses after a rematch")
	await _press(KEY_DOWN)
	await _press(KEY_DOWN)
	await _press(KEY_ENTER)
	_check(_main._flow.screen == AppFlow.Screen.TITLE, "QUIT TO TITLE leaves the match")
	_check(_main._title.visible, "title is visible again")
	_check(not _main._hud.visible, "HUD hidden on the title")

	_report()


## Fast-forward the live match with the real AI/event pipeline until RESULTS.
## Returns the winner id, or -1 if the round did not finish.
func _play_round() -> int:
	var ticks := 0
	while _main.sim.phase != MatchSim.Phase.RESULTS and ticks < 9000:
		_main._shot_step()
		ticks += 1
	if _main.sim.phase != MatchSim.Phase.RESULTS:
		return -1
	return int(_main.sim.winner_id)


func _press(key: int) -> void:
	var press := InputEventKey.new()
	press.keycode = key
	press.physical_keycode = key
	press.pressed = true
	Input.parse_input_event(press)
	await _settle()

	var release := InputEventKey.new()
	release.keycode = key
	release.physical_keycode = key
	release.pressed = false
	Input.parse_input_event(release)
	await _settle()


func _settle() -> void:
	# Several physics frames so input polling and focus changes both settle.
	for i in 4:
		await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("UI flow: %d check(s)" % _checks)
		print("PASS")
		quit(0)
		return
	for failure in _failures:
		printerr("FAIL  " + failure)
	print("UI flow: %d check(s), %d failure(s)" % [_checks, _failures.size()])
	quit(1)
