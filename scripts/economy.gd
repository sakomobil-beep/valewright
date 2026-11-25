extends Node
## Wirtschaft (Etappe 4): alle Gebäude, Waren und Warenketten aus der Browser-Version.
## Die Daten stehen in res://data/game.json (aus der Browser-Version übernommen).

signal changed
signal message(text: String)
signal house_level_changed(b: Dictionary)

# Wohnhäuser: Stufen und Bedürfnisse wie in der Browser-Version
const HOUSE_LV := [
	{"needs": ["*food", "wasser"], "tax": 0.0},
	{"needs": ["*fine", "wasser", "bier"], "tax": 0.0},
	{"needs": ["*fine", "kaese", "wasser", "bier", "kleidung"], "tax": 0.1},
	{"needs": ["*fine", "kaese", "kuchen", "wasser", "bier", "kleidung", "met", "kruege", "kerzen"], "tax": 0.2},
	{"needs": ["*fine", "kaese", "kuchen", "wasser", "bier", "kleidung", "met", "kruege", "kerzen", "schmuck", "wein"], "tax": 0.4},
]
const UPCOST := {3: {"ziegel": 2}, 4: {"ziegel": 4, "bretter": 2}}
const FOODS := ["brot", "fisch", "schinken"]
const FINE := ["raeucherfisch", "wurst"]
const HOUSE_TICK := 45.0
var unl := 0     # Freischalt-Stufe (steigt mit zufriedenen Wohnhäusern)

var BUILD_TIME := 8.0
var WORK_TIME := 10.0
# Diese Berufe arbeiten draußen in der Welt (siehe settlers.gd)
const FIELD_WORKERS := ["holzfaeller", "steinmetz", "foerster", "rutengaenger"]
# Diese Gebäude produzieren (noch) keine Waren
const NO_PRODUCTION := ["wohnhaus", "denkmal", "kaserne", "wirtshaus", "lager", "markt", "burg", "wachturm", "wachstube", "wehrturm"]
# Mengen, die von 1 abweichen
const AMOUNT := {"saegewerk": {"bretter": 2}, "bogenbauer": {"pfeile": 5}, "imker": {"honig": 2}}

var data: Dictionary
var stock := {}
var stats := {"prod": {}, "use": {}}
var terrain: Node3D
var buildings: Array = []
var pending: Array = []      # Waren, die Träger abholen sollen: {b, item}

func _init() -> void:
	var f := FileAccess.open("res://data/game.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	for k in data.items:
		stock[k] = int(round(int(data.start.get(k, 0)) * {"wenig": 0.5, "normal": 1.0, "viel": 2.0}.get(String(Session.cfg.get("start", "normal")), 1.0)))
	var tk: float = {"gemuetlich": 1.4, "normal": 1.0, "schnell": 0.7}.get(String(Session.cfg.get("tempo", "normal")), 1.0)
	WORK_TIME = 10.0 * tk
	BUILD_TIME = 8.0 * tk

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
		note("use", k, int(c[k]))
	changed.emit()

func cost_text(t: String) -> String:
	var s := ""
	var c: Dictionary = data.types[t].cost
	for k in c:
		s += "%d%s " % [int(c[k]), icon(k)]
	return s.strip_edges()

func add(k: String, n: int) -> void:
	stock[k] = stock.get(k, 0) + n
	note("prod", k, n)
	changed.emit()

func note(kind: String, k: String, n: int) -> void:
	stats[kind][k] = stats[kind].get(k, 0) + n

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
	# Gebäude mit Vorrang ⭐ bekommen ihre Zutaten zuerst
	var order: Array = buildings.filter(func(b): return b.get("prio", false)) + buildings.filter(func(b): return not b.get("prio", false))
	for b in order:
		if b.build < 1.0:
			continue   # Baustelle: siehe construction.gd
		if b.type == "wohnhaus":
			_house(b, dt)
			continue
		if not produces(b.type) or not b.get("worker_inside", false) or b.get("paused", false):
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
		note("use", k, 1)
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

# ---------- Freischalten ----------
func is_unlocked(t: String) -> bool:
	return int(data.unlock.get(t, 0)) <= unl

# ---------- Wohnhäuser ----------
func _need_ok(k: String) -> bool:
	if k == "*food":
		return FOODS.any(func(f): return stock.get(f, 0) > 0)
	if k == "*fine":
		return FINE.any(func(f): return stock.get(f, 0) > 0)
	return stock.get(k, 0) > 0

func _use(k: String) -> void:
	var list: Array = FOODS if k == "*food" else (FINE if k == "*fine" else [k])
	for f in list:
		if stock.get(f, 0) > 0:
			stock[f] -= 1
			note("use", f, 1)
			return

func need_item(k: String) -> String:
	return "brot" if k == "*food" else ("raeucherfisch" if k == "*fine" else k)

func _house(b: Dictionary, dt: float) -> void:
	if not b.has("lvl"):
		b.lvl = 0
		b.sat = 0
		b.bad = 0
		b.ht = HOUSE_TICK - 5.0
		b.tax = 0.0
		b.status = "ST_HOUSE_MISSING"
		b.miss = []
	b.ht += dt
	if b.ht < HOUSE_TICK:
		return
	b.ht = 0.0
	var L: Dictionary = HOUSE_LV[b.lvl]
	var miss: Array = L.needs.filter(func(k): return not _need_ok(k))
	for k in L.needs:
		_use(k)
	if miss.is_empty():
		b.sat = mini(3, b.sat + 1)
		b.bad = 0
		b.tax += L.tax
		if b.tax >= 1.0:
			b.tax -= 1.0
			stock.muenzen = stock.get("muenzen", 0) + 1
		b.status = "ST_HOUSE_OK"
		b.miss = []
		if b.lvl + 1 > unl:
			unl = b.lvl + 1
			message.emit(tr("MSG_UNLOCKED"))
		# Aufstieg
		if b.lvl < 4 and b.sat >= 3:
			var nx: Dictionary = HOUSE_LV[b.lvl + 1]
			var up: Dictionary = UPCOST.get(b.lvl + 1, {})
			var ok: bool = nx.needs.all(func(k): return _need_ok(k))
			for k in up:
				if stock.get(k, 0) < up[k]:
					ok = false
			if ok:
				for k in up:
					stock[k] -= up[k]
				b.lvl += 1
				b.sat = 0
				house_level_changed.emit(b)
				message.emit(tr("MSG_HOUSE_UP") % tr("HOUSE_%d" % b.lvl))
			else:
				b.miss = nx.needs.filter(func(k): return not _need_ok(k)).map(func(k): return need_item(k))
				for k in up:
					if stock.get(k, 0) < up[k]:
						b.miss.append(k)
				if not b.miss.is_empty():
					b.status = "ST_HOUSE_NEXT"
	else:
		b.sat = 0
		b.bad += 1
		b.status = "ST_HOUSE_MISSING"
		b.miss = miss.map(func(k): return need_item(k))
		if b.bad >= 3 and b.lvl > 0:
			b.lvl -= 1
			b.bad = 0
			house_level_changed.emit(b)
			message.emit(tr("MSG_HOUSE_DOWN"))
	changed.emit()
