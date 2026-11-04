extends SceneTree
## Diagnostic: prove the bundled fonts load, cover Arabic, and shape connected script.

const ThemeBuilder = preload("res://src/ui/theme_builder.gd")


func _initialize() -> void:
	var theme: Theme = ThemeBuilder.build()
	var font: Font = theme.default_font
	print("default_font=", font, " name=", font.get_font_name() if font != null else "<null>")
	print("has_latin_A=", font.has_char(0x41))
	print("has_arabic_alef=", font.has_char(0x0627))
	var fallbacks := font.fallbacks
	print("fallbacks=", fallbacks.size())
	for entry in fallbacks:
		print("  fallback=", entry.get_font_name(), " arabic=", entry.has_char(0x0627))

	var ts := TextServerManager.get_primary_interface()
	print("text_server=", ts.get_name())

	var shaped := ts.create_shaped_text()
	ts.shaped_text_add_string(shaped, "لا", font.get_rids(), 64)
	ts.shaped_text_shape(shaped)
	print("lam_alef glyphs=", ts.shaped_text_get_glyph_count(shaped),
		" width=", ts.shaped_text_get_width(shaped),
		" chars=", "لا".length())
	ts.free_rid(shaped)

	var word := ts.create_shaped_text()
	ts.shaped_text_add_string(word, "العربية", font.get_rids(), 64)
	ts.shaped_text_shape(word)
	print("arabic_word glyphs=", ts.shaped_text_get_glyph_count(word),
		" width=", ts.shaped_text_get_width(word),
		" chars=", "العربية".length())
	for i in ts.shaped_text_get_glyph_count(word):
		print("  glyph ", i, " flags=", ts.shaped_text_get_glyph_flags(word, i),
			" rtl=", (ts.shaped_text_get_glyph_flags(word, i) & TextServer.GRAPHEME_IS_RTL) != 0)
	ts.free_rid(word)

	var latin := ts.create_shaped_text()
	ts.shaped_text_add_string(latin, "FUSE", font.get_rids(), 64)
	ts.shaped_text_shape(latin)
	print("latin glyphs=", ts.shaped_text_get_glyph_count(latin),
		" width=", ts.shaped_text_get_width(latin))
	ts.free_rid(latin)
	quit(0)
