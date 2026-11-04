extends RefCounted
## Persisted user settings (volumes, series length, display, language).
##
## Pure data + JSON I/O so it can be tested headlessly and unit-tested without a
## scene tree. Invalid or hostile values are sanitised on load instead of trusted.

const DEFAULT_PATH := "user://settings.json"
const BEST_OF_CHOICES: Array[int] = [1, 3, 5]
const LOCALES: Array[String] = ["en", "ar"]

var path: String = DEFAULT_PATH

var best_of: int = 3
var master_volume: float = 0.80
var sfx_volume: float = 0.85
var music_volume: float = 0.55
var fullscreen: bool = false
var locale: String = "en"


func load_settings() -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return false
	var parsed = json.data
	if not (parsed is Dictionary):
		return false
	_apply(_sanitize(parsed))
	return true


func save_settings() -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_to_dict(), "\t"))
	file.close()
	return true


func reset() -> void:
	_apply(_defaults())


func _to_dict() -> Dictionary:
	return {
		"best_of": best_of,
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"fullscreen": fullscreen,
		"locale": locale,
	}


func _defaults() -> Dictionary:
	return {
		"best_of": 3,
		"master_volume": 0.80,
		"sfx_volume": 0.85,
		"music_volume": 0.55,
		"fullscreen": false,
		"locale": "en",
	}


static func _sanitize(raw: Dictionary) -> Dictionary:
	var out := {
		"best_of": 3,
		"master_volume": 0.80,
		"sfx_volume": 0.85,
		"music_volume": 0.55,
		"fullscreen": false,
		"locale": "en",
	}

	var series = raw.get("best_of", 3)
	if _is_number(series):
		var value := int(series)
		if BEST_OF_CHOICES.has(value):
			out["best_of"] = value
	for key in ["master_volume", "sfx_volume", "music_volume"]:
		var value = raw.get(key, out[key])
		if _is_number(value):
			out[key] = clampf(float(value), 0.0, 1.0)
	var fullscreen = raw.get("fullscreen", false)
	if typeof(fullscreen) == TYPE_BOOL:
		out["fullscreen"] = bool(fullscreen)
	var locale = raw.get("locale", "en")
	if locale is String and LOCALES.has(locale):
		out["locale"] = locale
	return out


static func _is_number(value) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


func _apply(data: Dictionary) -> void:
	best_of = int(data["best_of"])
	master_volume = float(data["master_volume"])
	sfx_volume = float(data["sfx_volume"])
	music_volume = float(data["music_volume"])
	fullscreen = bool(data["fullscreen"])
	locale = String(data["locale"])
