extends Node
## Mehrsprachigkeit: alle Texte stehen in res://translations/texts.tsv
## (Spalten: key, de, en – weitere Sprachen einfach als neue Spalte anhängen).

const FILE := "res://translations/texts.tsv"
const SETTINGS := "user://settings.cfg"
var languages: PackedStringArray = []

func _ready() -> void:
	_load()
	# Emoji-Schrift als Ersatz, damit 🪵🍞 usw. auch in der Web-Version erscheinen
	var emoji: Font = load("res://fonts/emoji.ttf")
	var base: Font = ThemeDB.fallback_font
	if emoji and base:
		var fb := base.fallbacks.duplicate()
		fb.append(emoji)
		base.fallbacks = fb
	var cfg := ConfigFile.new()
	var lang := ""
	if cfg.load(SETTINGS) == OK:
		lang = cfg.get_value("general", "language", "")
	if lang == "":
		lang = "de" if OS.get_locale_language() == "de" else "en"
	TranslationServer.set_locale(lang)

func _load() -> void:
	var f := FileAccess.open(FILE, FileAccess.READ)
	if f == null:
		push_error("Sprachdatei fehlt: " + FILE)
		return
	var head := f.get_line().split("\t")
	var trs: Array[Translation] = []
	for i in range(1, head.size()):
		var t := Translation.new()
		t.locale = head[i]
		trs.append(t)
		languages.append(head[i])
	while not f.eof_reached():
		var line := f.get_line()
		if line.strip_edges() == "":
			continue
		var cols := line.split("\t")
		for i in range(1, mini(cols.size(), head.size())):
			trs[i - 1].add_message(cols[0], cols[i].replace("\\n", "\n"))
	for t in trs:
		TranslationServer.add_translation(t)

func set_language(lang: String) -> void:
	TranslationServer.set_locale(lang)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("general", "language", lang)
	cfg.save(SETTINGS)
