extends Node
## Wirtschaft (Etappe 4): alle Gebäude, Waren und Warenketten aus der Browser-Version.
## Die Daten stehen in res://data/game.json (aus der Browser-Version übernommen).

signal changed

const BUILD_TIME := 8.0
const WORK_TIME := 10.0
# Diese Berufe arbeiten draußen in der Welt (siehe settlers.gd)
const FIELD_WORKERS := ["holzfaeller", "steinmetz", "foerster"]
# Diese Gebäude produzieren (noch) keine Waren
const NO_PRODUCTION := ["wohnhaus", "denkmal", "kaserne", "wirtshaus", "rutengaenger", "lager", "markt", "burg", "wachturm", "wachstube", "wehrturm"]
# Mengen, die von 1 abweichen
const AMOUNT := {"saegewerk": {"bretter": 2}, "bogenbauer": {"pfeile": 5}, "imker": {"honig": 2}}

var data: Dictionary
var stock := {}
var terrain: Node3D
var buildings: Array = []
var pending: Array = []      # Waren, die Träger abholen sollen: {b, item}

func _init() -> void:
	var f := FileAccess.open("res://data/game.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	for k in data.items:
		stock[k] = int(data.start.get(k, 0))

func type_info(t: String) -> Dictionary:
	return data.types[t]

func icon(item: String) -> String:
	return data.items[item].icon if data.items.has(item) else ""

func can_afford(t: String) -> bool:
	var c: Dictionary = data.types[t].cost
	for k in c:
		if stock.get(k, 0) < c[k]:
			return false
	return true

func pay(t: String) -> void:
	var c: Dictionary = data.types[t].cost
	for k in c:
		stock[k] -= int(c[k])
	changed.emit()

func cost_text(t: String) -> String:
	var s := ""
	var c: Dictionary = data.types[t].cost
	for k in c:
		s += "%d%s " % [int(c[k]), icon(k)]
	return s.strip_edges()

func add(k: String, n: int) -> void:
	stock[k] = stock.get(k, 0) + n
	changed.emit()

func produces(t: String) -> bool:
	return data.io.has(t) and not t in NO_PRODUCTION and not t in FIELD_WORKERS

func inputs(t: String) -> Array:
	return data.io[t][0] if data.io.has(t) else []

func outputs(t: String) -> Array:
	var out: Array = []
	if data.io.has(t):
		for o in data.io[t][1]:
			if data.items.has(o):
				out.append(o)
	return out

func _process(dt: float) -> void:
	for b in buildings:
		if b.build < 1.0:
			if not b.get("builder_on_site", false):
				continue
			b.build = minf(1.0, b.build + dt / BUILD_TIME)
			b.node.scale = Vector3(b.s, b.s * (0.15 + 0.85 * b.build), b.s)
			continue
		if not produces(b.type) or not b.get("worker_inside", false):
			continue
		if not b.get("running", false):
			_try_start(b)
			continue
		b.t += dt
		if b.t >= WORK_TIME:
			b.t = 0.0
			b.running = false
			_finish(b)

# Eingangswaren nehmen ("a|b" heißt: eine davon reicht)
func _try_start(b: Dictionary) -> void:
	var take: Array = []
	for need in inputs(b.type):
		var found := ""
		for alt in String(need).split("|"):
			if stock.get(alt, 0) > 0:
				found = alt
				break
		if found == "":
			b.status = "ST_MISSING"
			b.missing = String(need).split("|")[0]
			return
		take.append(found)
	for k in take:
		stock[k] -= 1
	if take.size():
		changed.emit()
	b.running = true
	b.t = 0.0
	b.status = "ST_WORKING"

func _finish(b: Dictionary) -> void:
	var outs := outputs(b.type)
	if outs.is_empty():
		return
	# Bei mehreren Waren: die nehmen, von der am wenigsten im Lager ist
	var pick: String = outs[0]
	for o in outs:
		if stock.get(o, 0) < stock.get(pick, 0):
			pick = o
	var n: int = AMOUNT.get(b.type, {}).get(pick, 1)
	for i in n:
		pending.append({"b": b, "item": pick})
