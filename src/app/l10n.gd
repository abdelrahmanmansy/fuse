extends RefCounted
## English + Arabic UI strings. Pure data and lookup: no nodes, no rendering.
##
## Keys use `%d`/`%s` placeholders; callers format with `%`. `tests/test_l10n.gd`
## enforces that every key exists in both tables with matching placeholders, and
## that every `L10n.t("...")` call in `src/` resolves.

static var locale: String = "en"

const SUPPORTED: Array[String] = ["en", "ar"]

const TABLES := {
	"en": {
		"tagline": "2 . 5 D   B O M B   A R E N A",
		"build_tag": "M2 preview · grey-box build",
		"menu.local2p": "LOCAL VERSUS   ·   2 PLAYERS",
		"menu.solo": "SOLO   ·   1 PLAYER VS CPU",
		"menu.settings": "SETTINGS",
		"menu.quit": "QUIT",
		"hint.nav": "UP / DOWN choose    ·    ENTER or SPACE confirm    ·    controllers supported",
		"pause.title": "PAUSED",
		"pause.hint": "ESC resumes",
		"pause.resume": "RESUME",
		"pause.restart": "RESTART ROUND",
		"pause.quit": "QUIT TO TITLE",
		"settings.title": "SETTINGS",
		"settings.master": "MASTER VOLUME",
		"settings.sfx": "SFX VOLUME",
		"settings.series": "SERIES: BEST OF %d",
		"settings.fullscreen_on": "FULLSCREEN: ON",
		"settings.fullscreen_off": "FULLSCREEN: OFF",
		"settings.language": "LANGUAGE: %s",
		"settings.back": "BACK",
		"settings.hint": "UP / DOWN choose    ·    LEFT / RIGHT adjust    ·    ENTER confirm",
		"lang.en": "ENGLISH",
		"lang.ar": "العربية",
		"player": "PLAYER %d",
		"series.round": "ROUND %d",
		"series.complete": "SERIES COMPLETE",
		"series.winner": "%s TAKES THE SERIES",
		"series.draw": "SERIES DRAWN",
		"series.summary": "BEST OF %d   ·   %d ROUNDS PLAYED",
		"series.rematch": "REMATCH",
		"series.round_winner": "%s WINS",
		"series.round_draw": "ROUND DRAWN",
		"series.status": "FIRST TO %d   ·   ROUND %d OF %d",
		"series.next": "NEXT ROUND",
		"series.change": "CHANGE MODE",
		"mode.1p": "1P vs CPU",
		"mode.2p": "2P LOCAL",
		"hud.hint": "P1 WASD + Space    P2 Arrows + Enter    R restart    1 / 2 mode    Esc pause",
		"hud.stats": "BOMBS %d   RANGE %d   SPEED %d   KICK %s",
		"hud.yes": "YES",
		"hud.no": "NO",
		"hud.eliminated": "ELIMINATED",
		"hud.ready": "READY",
		"hud.go": "GO!",
		"hud.winner": "PLAYER %d WINS",
		"hud.draw": "DRAW",
		"hud.phase_sudden": "SUDDEN DEATH",
		"hud.phase_battle": "BATTLE",
		"hud.phase_results": "RESULTS",
		"hud.phase_standby": "STANDBY",
		"hud.phase_ready": "GET READY",
	},
	"ar": {
		"tagline": "ساحة قنابل 2.5D",
		"build_tag": "معاينة M2 · نسخة رمادية",
		"menu.local2p": "مواجهة محلية   ·   لاعبان",
		"menu.solo": "فردي   ·   لاعب ضد الحاسوب",
		"menu.settings": "الإعدادات",
		"menu.quit": "خروج",
		"hint.nav": "أعلى / أسفل للاختيار    ·    Enter أو Space للتأكيد    ·    يد التحكم مدعومة",
		"pause.title": "إيقاف مؤقت",
		"pause.hint": "ESC للمتابعة",
		"pause.resume": "متابعة",
		"pause.restart": "إعادة الجولة",
		"pause.quit": "الخروج إلى القائمة",
		"settings.title": "الإعدادات",
		"settings.master": "مستوى الصوت",
		"settings.sfx": "صوت المؤثرات",
		"settings.series": "السلسلة: الأفضل من %d",
		"settings.fullscreen_on": "ملء الشاشة: مفعّل",
		"settings.fullscreen_off": "ملء الشاشة: متوقف",
		"settings.language": "اللغة: %s",
		"settings.back": "رجوع",
		"settings.hint": "أعلى / أسفل للاختيار    ·    يسار / يمين للتعديل    ·    Enter للتأكيد",
		"lang.en": "ENGLISH",
		"lang.ar": "العربية",
		"player": "اللاعب %d",
		"series.round": "الجولة %d",
		"series.complete": "انتهت السلسلة",
		"series.winner": "%s يفوز بالسلسلة",
		"series.draw": "سلسلة متعادلة",
		"series.summary": "الأفضل من %d   ·   %d جولات",
		"series.rematch": "إعادة المباراة",
		"series.round_winner": "%s يفوز",
		"series.round_draw": "جولة متعادلة",
		"series.status": "الأول إلى %d   ·   الجولة %d من %d",
		"series.next": "الجولة التالية",
		"series.change": "تغيير النمط",
		"mode.1p": "لاعب ضد الحاسوب",
		"mode.2p": "لاعبان محليًا",
		"hud.hint": "P1 WASD + Space    P2 الأسهم + Enter    R إعادة    1 / 2 النمط    Esc إيقاف",
		"hud.stats": "قنابل %d   مدى %d   سرعة %d   ركل %s",
		"hud.yes": "نعم",
		"hud.no": "لا",
		"hud.eliminated": "مُقصى",
		"hud.ready": "استعد",
		"hud.go": "انطلق!",
		"hud.winner": "اللاعب %d يفوز",
		"hud.draw": "تعادل",
		"hud.phase_sudden": "موت مفاجئ",
		"hud.phase_battle": "معركة",
		"hud.phase_results": "النتائج",
		"hud.phase_standby": "استعداد",
		"hud.phase_ready": "استعد",
	},
}


static func set_locale(code: String) -> void:
	locale = code if SUPPORTED.has(code) else "en"


static func is_rtl() -> bool:
	return locale == "ar"


static func has_key(key: String) -> bool:
	return TABLES["en"].has(key) and TABLES["ar"].has(key)


static func t(key: String) -> String:
	var table: Dictionary = TABLES.get(locale, TABLES["en"])
	if table.has(key):
		return String(table[key])
	return String(TABLES["en"].get(key, key))


## Raw table for tests and tooling.
static func table(code: String) -> Dictionary:
	return TABLES.get(code, {})
