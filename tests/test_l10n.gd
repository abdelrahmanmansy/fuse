extends "res://tests/case.gd"
## Localization tables: parity, placeholders, fallbacks, RTL flag, and a source scan
## that every literal `L10n.t("...")` key in `src/` actually exists in both languages.

const L10n = preload("res://src/app/l10n.gd")

const SRC_ROOT := "res://src"
const PLACEHOLDER := "%[-+0-9.]*[dsf]"


func _placeholders(text: String) -> Array[String]:
	var found: Array[String] = []
	var regex := RegEx.new()
	regex.compile(PLACEHOLDER)
	for match in regex.search_all(text):
		found.append(match.get_string())
	found.sort()
	return found


func _collect_scripts(directory: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := directory.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				found.append_array(_collect_scripts(full))
		elif entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found


func test_locale_tables_have_the_same_keys() -> void:
	var en := L10n.table("en")
	var ar := L10n.table("ar")
	check(en.size() > 40, "English table is populated (%d keys)" % en.size())
	eq(ar.size(), en.size(), "Arabic table has the same number of keys")
	var missing_ar: Array[String] = []
	var missing_en: Array[String] = []
	for key in en.keys():
		if not ar.has(key):
			missing_ar.append(key)
	for key in ar.keys():
		if not en.has(key):
			missing_en.append(key)
	eq(missing_ar, [] as Array[String], "no Arabic key is missing")
	eq(missing_en, [] as Array[String], "no English key is missing")


func test_values_are_non_empty() -> void:
	for code in L10n.SUPPORTED:
		var table := L10n.table(code)
		for key in table.keys():
			check(String(table[key]).strip_edges() != "", "%s/%s is not empty" % [code, key])


func test_placeholders_match_between_languages() -> void:
	var en := L10n.table("en")
	var ar := L10n.table("ar")
	for key in en.keys():
		if not ar.has(key):
			continue
		var left := _placeholders(String(en[key]))
		var right := _placeholders(String(ar[key]))
		eq(right, left, "placeholder parity for %s" % key)


func test_arabic_table_is_actually_arabic() -> void:
	var table := L10n.table("ar")
	var arabic := RegEx.new()
	arabic.compile("[%s-%s]" % [char(0x0600), char(0x06FF)])
	var translated := 0
	for key in table.keys():
		if arabic.search(String(table[key])) != null:
			translated += 1
	# Control/commands and language names are intentionally left in Latin script.
	check(translated >= 20, "Arabic table contains real Arabic text (%d keys)" % translated)
	check(arabic.search(L10n.table("ar")["menu.settings"]) != null,
		"settings label is Arabic")
	check(arabic.search(L10n.table("ar")["pause.title"]) != null,
		"pause title is Arabic")


func test_unknown_key_falls_back_to_itself() -> void:
	L10n.set_locale("en")
	eq(L10n.t("no.such.key"), "no.such.key", "unknown key returns the key")
	check(not L10n.has_key("no.such.key"), "unknown key is not reported as known")


func test_set_locale_accepts_supported_and_rejects_others() -> void:
	L10n.set_locale("ar")
	eq(L10n.locale, "ar", "Arabic is accepted")
	check(L10n.is_rtl(), "Arabic is right-to-left")
	L10n.set_locale("en")
	eq(L10n.locale, "en", "English is accepted")
	check(not L10n.is_rtl(), "English is left-to-right")
	L10n.set_locale("fr")
	eq(L10n.locale, "en", "unsupported locale falls back to English")
	L10n.set_locale("")
	eq(L10n.locale, "en", "empty locale falls back to English")


func test_formatting_uses_the_active_table() -> void:
	L10n.set_locale("en")
	eq(L10n.t("player") % 2, "PLAYER 2", "English player label formats")
	eq(L10n.t("settings.series") % 5, "SERIES: BEST OF 5", "English series label formats")
	L10n.set_locale("ar")
	eq(L10n.t("player") % 2, "اللاعب 2", "Arabic player label formats")
	check(L10n.t("hud.stats") % [3, 4, 2, L10n.t("hud.yes")] != "",
		"Arabic stats line formats with four arguments")
	L10n.set_locale("en")


func test_every_source_key_exists() -> void:
	# Only literal one-argument calls are scanned; dynamic keys are covered by the
	# parity/formatting tests above.
	var regex := RegEx.new()
	regex.compile("L10n\\.t\\(\"([A-Za-z0-9][A-Za-z0-9_.]*)\"\\)")
	var missing: Array[String] = []
	var seen := 0
	for path in _collect_scripts(SRC_ROOT):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var source := file.get_as_text()
		file.close()
		for match in regex.search_all(source):
			var key := match.get_string(1)
			seen += 1
			if not L10n.has_key(key) and not missing.has(key):
				missing.append(key)
	check(seen > 0, "found L10n.t() calls to audit (%d)" % seen)
	eq(missing, [] as Array[String], "all literal translation keys exist")
