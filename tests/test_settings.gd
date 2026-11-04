extends "res://tests/case.gd"
## Settings persistence: roundtrip, defaults, clamping and hostile JSON.

const Settings = preload("res://src/app/settings.gd")

const TEST_PATH := "user://settings_test.json"


func _cleanup() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func _write(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_missing_file_keeps_defaults() -> void:
	_cleanup()
	var settings = Settings.new()
	settings.path = TEST_PATH
	eq(settings.load_settings(), false, "missing file reports false")
	eq(settings.best_of, 3, "default best of 3")
	eq(settings.master_volume, 0.80, "default master volume")
	eq(settings.sfx_volume, 0.85, "default sfx volume")
	eq(settings.locale, "en", "default locale")


func test_save_load_roundtrip() -> void:
	_cleanup()
	var saved = Settings.new()
	saved.path = TEST_PATH
	saved.best_of = 5
	saved.master_volume = 0.4
	saved.sfx_volume = 0.3
	saved.music_volume = 0.2
	saved.fullscreen = true
	saved.locale = "ar"
	eq(saved.save_settings(), true, "save succeeds")

	var loaded = Settings.new()
	loaded.path = TEST_PATH
	eq(loaded.load_settings(), true, "load succeeds")
	eq(loaded.best_of, 5, "best of persisted")
	eq(loaded.master_volume, 0.4, "master volume persisted")
	eq(loaded.sfx_volume, 0.3, "sfx volume persisted")
	eq(loaded.music_volume, 0.2, "music volume persisted")
	eq(loaded.fullscreen, true, "fullscreen persisted")
	eq(loaded.locale, "ar", "locale persisted")
	_cleanup()


func test_corrupt_file_is_rejected() -> void:
	_write("{ this is not json")
	var settings = Settings.new()
	settings.path = TEST_PATH
	eq(settings.load_settings(), false, "corrupt json reports false")
	eq(settings.best_of, 3, "defaults survive corrupt json")
	_cleanup()


func test_out_of_range_values_are_clamped() -> void:
	_write('{"best_of": 99, "master_volume": 5.0, "sfx_volume": -3, "music_volume": 0.5, "fullscreen": "yes", "locale": "fr"}')
	var settings = Settings.new()
	settings.path = TEST_PATH
	eq(settings.load_settings(), true, "valid json loads")
	eq(settings.best_of, 3, "unsupported series length falls back")
	eq(settings.master_volume, 1.0, "volume clamps to 1")
	eq(settings.sfx_volume, 0.0, "volume clamps to 0")
	eq(settings.music_volume, 0.5, "in-range volume kept")
	eq(settings.fullscreen, false, "non-bool fullscreen ignored")
	eq(settings.locale, "en", "unknown locale ignored")
	_cleanup()


func test_integral_float_series_is_accepted() -> void:
	_write('{"best_of": 5.0}')
	var settings = Settings.new()
	settings.path = TEST_PATH
	eq(settings.load_settings(), true, "json float parses")
	eq(settings.best_of, 5, "integral float accepted")
	_cleanup()


func test_reset_restores_defaults() -> void:
	var settings = Settings.new()
	settings.best_of = 1
	settings.master_volume = 0.1
	settings.locale = "ar"
	settings.reset()
	eq(settings.best_of, 3, "reset best of")
	eq(settings.master_volume, 0.80, "reset master volume")
	eq(settings.locale, "en", "reset locale")
