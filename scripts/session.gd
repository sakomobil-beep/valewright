extends Node
## Spielsitzung: Einstellungen für das nächste Spiel, Laden, Kampagnen-Fortschritt.

var started := false          # false = Hauptmenü zeigen
var cfg := {"mode": "free", "ais": 1, "diff": "leicht", "seed": 4711, "mission": 0}
var load_data = null          # Spielstand, der beim Start angewendet wird
var campaign := {}            # {"1": true, ...} geschaffte Kapitel

const CAMPAIGN_FILE := "user://campaign.json"
const SAVE_DIR := "user://saves"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(CAMPAIGN_FILE, FileAccess.READ)
	if f:
		campaign = JSON.parse_string(f.get_as_text())
		if campaign == null:
			campaign = {}

func chapter_done(id: int) -> void:
	campaign[str(id)] = true
	var f := FileAccess.open(CAMPAIGN_FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(campaign))

func new_game(c: Dictionary) -> void:
	cfg = c
	load_data = null
	started = true
	get_tree().change_scene_to_file("res://main.tscn")

func to_menu() -> void:
	started = false
	load_data = null
	get_tree().change_scene_to_file("res://main.tscn")

func save_path(slot: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot]

func slot_info(slot: String):
	var f := FileAccess.open(save_path(slot), FileAccess.READ)
	if f == null:
		return null
	var d = JSON.parse_string(f.get_as_text())
	return d

func load_game(slot: String) -> bool:
	var d = slot_info(slot)
	if d == null:
		return false
	cfg = d.cfg
	load_data = d
	started = true
	get_tree().change_scene_to_file("res://main.tscn")
	return true
