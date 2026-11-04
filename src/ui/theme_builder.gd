extends RefCounted
## Builds the app theme. Noto Sans covers Latin; Noto Sans Arabic is registered as
## a fallback so Arabic strings shape correctly. Both are OFL-licensed and bundled
## (see assets/fonts/README.md), so no system font is required.

const LATIN_PATH := "res://assets/fonts/NotoSans-Variable.ttf"
const ARABIC_PATH := "res://assets/fonts/NotoSansArabic-Variable.ttf"


static func build() -> Theme:
	var theme := Theme.new()
	var latin: FontFile = load(LATIN_PATH)
	var arabic: FontFile = load(ARABIC_PATH)

	if latin != null:
		if arabic != null:
			# Base font handles Latin and punctuation, fallback handles Arabic glyphs
			# and shaping. Assigning here mutates the cached resource once at boot.
			latin.fallbacks = [arabic]
		theme.default_font = latin

	return theme
