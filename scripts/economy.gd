extends Node
## Wirtschaft (Etappe 4): alle Gebäude, Waren und Warenketten aus der Browser-Version.
## Die Daten stehen in res://data/game.json (aus der Browser-Version übernommen).

signal changed
signal message(text: String)
signal house_level_changed(b: Dictionary)

# Wohnhäuser: Stufen und Bedürfnisse wie in der Browser-Version
# Wohnhaus-Stufen: am Anfang genügsam, erst ab dem Fachwerkhaus anspruchsvoller
const HOUSE_LV := [
	{"needs": ["wasser"], "tax": 0.0},                                                     # Hütte
	{"needs": ["*food", "wasser"], "tax": 0.0},                                            # Bauernhaus
	{"needs": ["*food", "wasser", "bier"], "tax": 0.1},                                    # Fachwerkhaus
	{"needs": ["*food", "wasser", "bier", "kaese", "kleidung"], "tax": 0.2},               # Bürgerhaus
	{"needs": ["*food", "wasser", "bier", "kaese", "kleidung", "kuchen", "met", "kruege", "kerzen", "wein", "schmuck"], "tax": 0.4},   # Herrenhaus
]
const UPCOST := {3: {"ziegel": 2}, 4: {"ziegel": 4, "bretter": 2}}
const FOODS := ["brot", "fisch", "schinken"]
const FINE := ["raeucherfisch", "wurst"]
var HOUSE_TICK := 90.0
# Einwohner: Haupthaus bietet Platz für BASE_HOMES, jedes Wohnhaus je nach Stufe mehr.
# Alle Berufe, Träger, Baumeister und Soldaten kommen aus diesem Vorrat.
const BASE_HOMES := 20   # Platz im Haupthaus
const HOUSE_PEOPLE := [3, 5, 7, 9, 12]   # Bewohner je Stufe
const GROW_TIME := 45.0
var residents := 20   # Start: das Haupthaus ist voll bewohnt
var _grow_t := 0.0
var pop_src = null   # Siedler-Verwaltung (zählt, wer schon eine Aufgabe hat)
var builders_n := 2   # Baumeister zu Beginn (mehr nur über die Handwerkskammer)
const HQ_CARRIERS := 10   # wohnen fest im Haupthaus, zählen nicht als Einwohner
var carriers_n := 0   # zusätzliche Träger aus den Einwohnern (über die Handwerkskammer)
const TRAIN_TIME := 300.0   # 5 Minuten Ausbildung
var unl := 0     # Freischalt-Stufe (steigt mit zufriedenen Wohnhäusern)

var BUILD_TIME := 8.0
var WORK_TIME := 10.0
# Diese Berufe arbeiten draußen in der Welt (siehe settlers.gd)
# Diese Gebäude brauchen kein Werkzeug für ihren Arbeiter – so kommt man nie in eine Sackgasse
const TOOL_FREE := ["holzfaeller", "saegewerk", "steinmetz", "foerster", "rutengaenger", "steinmine", "kohlemine", "eisenmine", "koehler", "schmelze", "schmied", "brunnen"]
const FIELD_WORKERS := ["holzfaeller", "steinmetz", "foerster", "rutengaenger", "bauernhof", "schweinezucht", "brunnen"]
# Diese Gebäude produzieren (noch) keine Waren
const NO_PRODUCTION := ["umschlag", "handwerkskammer", "wohnhaus", "denkmal", "kaserne", "wirtshaus", "lager", "markt", "burg", "wachturm", "wachstube", "wehrturm"]
# Mengen, die von 1 abweichen
const AMOUNT := {"saegewerk": {"bretter": 2}, "bogenbauer": {"pfeile": 5}, "imker": {"honig": 2}}

var data: Dictionary
var stock := {}
var stats := {"prod": {}, "use": {}}
var terrain: Node3D
var buildings: Array = []

func _init() -> void:
	var f := FileAccess.open("res://data/game.json", FileAccess.READ)
	data = JSON.parse_string(f.get_as_text())
	for k in data.items:
		stock[k] = int(round(int(data.start.get(k, 0)) * {"wenig": 0.5, "normal": 1.0, "viel": 2.0}.get(String(Session.cfg.get("start", "normal")), 1.0)))
	var tk: float = {"gemuetlich": 1.4, "normal": 1.0, "schnell": 0.7}.get(String(Session.cfg.get("tempo", "normal")), 1.0)
	WORK_TIME = 10.0 * tk
	HOUSE_TICK = 90.0 * {"gemuetlich": 1.4, "normal": 1.0, "schnell": 0.5}.get(String(Session.cfg.get("tempo", "normal")), 1.0)
	BUILD_TIME = 8.0 * tk

func type_info(t: String) -> Dictionary:
	return data.types[t]

func icon(item: String) -> String:
	return data.items[item].icon if data.items.has(item) else ""

# Kosten wie costOf im Browser: jedes weitere Lagerhaus braucht 3 Dachziegel, sobald der Töpfer freigeschaltet ist
func cost_of(t: String) -> Dictionary:
	var c: Dictionary = data.types[t].cost.duplicate()
	if t == "lager" and buildings.any(func(b): return b.type == "lager" and not b.get("removed", false) and b.get("owner", 0) == 0) and is_unlocked("toepfer"):
		c["ziegel"] = 3
	return c

func can_afford(t: String) -> bool:
	var c: Dictionary = cost_of(t)
	var o := site_outstanding()
	for k in c:
		if int(stock.get(k, 0)) - int(o.get(k, 0)) < int(c[k]):
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

# ======================================================================
# Wirtschaft wie in der Browser-Version: jedes Gebäude hat ein Eingangslager (in),
# einen Ausgang (out); Träger bringen Waren direkt vom Erzeuger zum Verbraucher,
# Überschüsse ins Lager, und vom Lager zu Gebäuden, die etwas brauchen.
# ======================================================================
const RECIPE_IN := {"goldschmied": {"golderz": 1, "kohle": 1}, "kelterei": {"trauben": 2}, "bogenbauer": {"bretter": 2, "sehne": 1, "eisenbarren": 1}, "raeucherei": {"fisch": 1, "stamm": 1}, "kuhstall": {"getreide": 1, "wasser": 1}, "kaeserei": {"milch": 2}, "konditorei": {"mehl": 1, "milch": 1, "honig": 1}, "brauerei": {"getreide": 1, "hopfen": 1, "wasser": 1}, "wirtshaus": {"bier": 2}, "weberei": {"wolle": 1}, "schneider": {"stoff": 1}, "toepfer": {"lehm": 1}, "koehler": {"stamm": 2}, "saegewerk": {"stamm": 1}, "muehle": {"getreide": 1}, "baeckerei": {"mehl": 1, "wasser": 1}, "schmelze": {"eisenerz": 1, "kohle": 1}, "waffenschnitzer": {"bretter": 1}, "metzger": {"schwein": 1}, "schmied": {"eisenbarren": 1}, "muenzpraege": {"golderz": 2, "kohle": 1}, "schweinezucht": {"getreide": 1, "wasser": 1}, "seilerei": {"flachs": 1}, "wagner": {"bretter": 2, "eisenbarren": 1}}
const MINEFOOD := ["raeucherfisch", "wurst", "brot", "fisch", "schinken"]
const MINES := ["steinmine", "eisenmine", "kohlemine", "goldmine"]
const WS_REC := {"schwert": [{"eisenbarren": 1, "kohle": 1}, 1, 7], "schild": [{"bretter": 1, "eisenbarren": 1}, 1, 6]}

func bufs(b: Dictionary) -> void:
	if not b.has("in"):
		b["in"] = {}
		b["inc"] = {}
		b["out"] = {}
		b["out_res"] = {}

func prio(b: Dictionary) -> float:
	return 0.25 if b.get("prio", false) else 1.0

func put_out(b: Dictionary, item: String, n: int) -> void:
	bufs(b)
	b.out[item] = int(b.out.get(item, 0)) + n
	note("prod", item, n)
	changed.emit()

func has_in(b: Dictionary, inp: Dictionary) -> bool:
	bufs(b)
	for k in inp:
		if int(b["in"].get(k, 0)) < int(inp[k]):
			return false
	return true

func take_in(b: Dictionary, inp: Dictionary) -> void:
	for k in inp:
		b["in"][k] = int(b["in"].get(k, 0)) - int(inp[k])
		note("use", k, int(inp[k]))

func out_total(b: Dictionary) -> int:
	bufs(b)
	var n := 0
	for k in b.out:
		n += int(b.out[k])
	return n

func _have(b: Dictionary, k: String) -> int:
	return int(b["in"].get(k, 0)) + int(b.inc.get(k, 0))

func is_active(b: Dictionary) -> bool:
	return b.build >= 1.0 and not b.get("removed", false) and not b.get("paused", false) and (b.get("worker") != null or b.type == "kaserne")

# Was braucht das Gebäude noch? [[ware, anzahl], …]  (wie wantsOf im Browser)
func wants_of(b: Dictionary) -> Array:
	bufs(b)
	if b.get("removed", false) or b.get("owner", 0) != 0:
		return []
	if b.build < 1.0:
		if not b.has("site_need"):
			return []
		var r: Array = []
		for k in b.site_need:
			var m: int = int(b.site_need[k]) - int(b.site_in.get(k, 0)) - int(b.site_inc.get(k, 0))
			if m > 0:
				r.append([k, m])
		return r
	if b.type == "wohnhaus":
		return house_wants(b)
	if not is_active(b):
		return []
	var res: Array = []
	if b.type in MINES:
		var have := 0
		for f in MINEFOOD:
			have += _have(b, f)
		if have < 2:
			res.append(["*mfood", 2 - have])
		return res
	if b.type == "waffenschmied":
		var need := {}
		for p in b.get("wo", {}):
			if int(b.wo[p]) > 0 and WS_REC.has(p):
				for k in WS_REC[p][0]:
					need[k] = maxi(int(need.get(k, 0)), int(WS_REC[p][0][k]) * 2)
		for k in need:
			if _have(b, k) < need[k]:
				res.append([k, need[k] - _have(b, k)])
		return res
	if b.type == "kaserne":
		var need2 := {}
		if int(b.get("trS", 0)) > 0:
			need2.schwert = 1
			need2.schild = 1
		if int(b.get("trB", 0)) > 0:
			need2.bogen = 1
			need2.pfeile = 5
		if int(b.get("promo", 0)) > 0:
			need2.muenzen = 3
		for k in need2:
			if _have(b, k) < need2[k]:
				res.append([k, need2[k] - _have(b, k)])
		return res
	if b.type == "brauerei" and _have(b, "honig") < 2:
		res.append(["honig", 2 - _have(b, "honig")])
	if not RECIPE_IN.has(b.type):
		return res
	if b.type == "wagner" and int(b.get("orders", 0)) <= 0:
		return res
	var rc: Dictionary = RECIPE_IN[b.type]
	for k in rc:
		if _have(b, k) < int(rc[k]) * 2:
			res.append([k, int(rc[k]) * 2 - _have(b, k)])
	return res

func matches_want(want: String, item: String) -> bool:
	return want == item or (want == "*mfood" and item in MINEFOOD) or (want == "*food" and item in FOODS) or (want == "*fine" and item in FINE)

func best_consumer(item: String, pos: Vector3, except = null):
	var best = null
	var bk := 1e9
	for b in buildings:
		if b == except:
			continue
		for wv in wants_of(b):
			if matches_want(wv[0], item):
				var k: float = prio(b) * 400.0 + Vector2(b.pos.x - pos.x, b.pos.z - pos.z).length()
				if k < bk:
					bk = k
					best = b
				break
	return best

# Baustellen ziehen ihr Material erst beim Liefern aus dem Lager – das noch Fehlende ist reserviert
func site_outstanding() -> Dictionary:
	var o := {}
	for b in buildings:
		if b.get("removed", false) or b.build >= 1.0 or not b.has("site_need"):
			continue
		for k in b.site_need:
			o[k] = int(o.get(k, 0)) + maxi(0, int(b.site_need[k]) - int(b.site_in.get(k, 0)) - int(b.site_inc.get(k, 0)))
	return o

var _food_note := false
var _chk_t := 0.0
# Hinweise bei Problemen (wie checkProblems im Browser)
func _check_problems(dt: float) -> void:
	_chk_t += dt
	if _chk_t < 3.0:
		return
	_chk_t = 0.0
	var mine := buildings.any(func(b): return b.type in MINES and b.build >= 1.0 and not b.get("removed", false))
	var low: bool = mine and FOODS.all(func(f): return int(stock.get(f, 0)) <= 0) and not buildings.any(func(b): return b.type in MINES and MINEFOOD.any(func(f): return int(b.get("in", {}).get(f, 0)) > 0))
	if low and not _food_note:
		_food_note = true
		message.emit(tr("NOTE_NO_FOOD"))
	if not low:
		_food_note = false

func home_cap() -> int:
	var n := BASE_HOMES
	for b in buildings:
		if b.type == "wohnhaus" and b.build >= 1.0 and not b.get("removed", false) and int(b.get("owner", 0)) == 0:
			n += HOUSE_PEOPLE[clampi(int(b.get("lvl", 0)), 0, 4)]
	return n

func used_people() -> int:
	return pop_src.used_people() if pop_src else 0

func free_people() -> int:
	return residents - used_people()

# Für eine Einstellung: ist jemand frei? Wenn nicht, wird ein zweiter Nachbarschaftshelfer abgerufen.
func take_person() -> bool:
	if free_people() >= 1:
		return true
	return pop_src != null and pop_src.has_method("release_helper") and pop_src.release_helper()

func _grow(dt: float) -> void:
	_grow_t += dt
	if _grow_t < GROW_TIME * tf():
		return
	_grow_t = 0.0
	if residents >= home_cap():
		return
	var happy := buildings.any(func(b): return b.type == "wohnhaus" and b.build >= 1.0 and int(b.get("sat", 0)) > 0 and not b.get("removed", false))
	if residents < BASE_HOMES or happy:
		residents += 1
		changed.emit()

func _process(dt: float) -> void:
	_check_problems(dt)
	_grow(dt)
	for b in buildings:
		if b.build < 1.0 or b.get("removed", false):
			continue
		bufs(b)
		if b.type == "handwerkskammer":
			_train(b, dt)
		elif b.type == "wohnhaus":
			_house(b, dt)
		elif produces(b.type) and b.get("worker_inside", false):
			_produce(b, dt)
		elif b.type == "wirtshaus" and b.get("worker") != null:
			plan_rec(b)   # Status „Schenkt Bier aus“ / „Bier fehlt“

# Handwerkskammer: Warteschlange abarbeiten (Werkzeug wurde beim Auftrag bezahlt)
func _train(b: Dictionary, dt: float) -> void:
	var q: Array = b.get("tq", [])
	if q.is_empty():
		b.status = "ST_HK_IDLE"
		return
	b.tq_t = float(b.get("tq_t", 0.0)) + dt
	b.status = "ST_HK_TRAIN"
	if b.tq_t >= TRAIN_TIME:
		if not take_person():
			b.status = "ST_NO_PEOPLE"
			b.tq_t = TRAIN_TIME
			return
		b.tq_t = 0.0
		var k: String = q.pop_front()
		if k == "bau":
			builders_n += 1
			message.emit(tr("MSG_HK_BUILDER") % builders_n)
		else:
			carriers_n += 1
			message.emit(tr("MSG_HK_CARRIER") % (HQ_CARRIERS + carriers_n))
		changed.emit()

# Rezepte wie planNext im Browser: [Eingang, Ware, Menge, Sekunden]
const REC := {"goldschmied": [{"golderz": 1, "kohle": 1}, "schmuck", 1, 8], "winzer": [{}, "trauben", 2, 7], "kelterei": [{"trauben": 2}, "wein", 1, 7], "raeucherei": [{"fisch": 1, "stamm": 1}, "raeucherfisch", 2, 7], "kuhstall": [{"getreide": 1, "wasser": 1}, "milch", 2, 6], "kaeserei": [{"milch": 2}, "kaese", 1, 7], "konditorei": [{"mehl": 1, "milch": 1, "honig": 1}, "kuchen", 2, 7], "hopfenbauer": [{}, "hopfen", 1, 6], "schaefer": [{}, "wolle", 1, 6], "weberei": [{"wolle": 1}, "stoff", 1, 6], "schneider": [{"stoff": 1}, "kleidung", 1, 6], "imker": [{}, "honig", 2, 7], "lehmgrube": [{}, "lehm", 1, 5], "toepfer": [{"lehm": 1}, "kruege", 1, 6], "koehler": [{"stamm": 2}, "kohle", 1, 9], "brauerei": [{"getreide": 1, "hopfen": 1, "wasser": 1}, "bier", 2, 6], "saegewerk": [{"stamm": 1}, "bretter", 2, 4], "muehle": [{"getreide": 1}, "mehl", 1, 4], "baeckerei": [{"mehl": 1, "wasser": 1}, "brot", 2, 5], "steinmine": [{}, "stein", 1, 6], "eisenmine": [{}, "eisenerz", 1, 6], "kohlemine": [{}, "kohle", 1, 6], "goldmine": [{}, "golderz", 1, 9], "schmelze": [{"eisenerz": 1, "kohle": 1}, "eisenbarren", 1, 6], "waffenschnitzer": [{"bretter": 1}, "kampfstock", 1, 5], "muenzpraege": [{"golderz": 2, "kohle": 1}, "muenzen", 1, 8], "metzger": [{"schwein": 1}, "schinken", 2, 5], "wagner": [{"bretter": 2, "eisenbarren": 1}, "karren", 1, 9], "flachsbauer": [{}, "flachs", 1, 6], "seilerei": [{"flachs": 1}, "sehne", 1, 5], "schmied": [{"eisenbarren": 1}, "werkzeug", 1, 6], "brunnen": [{}, "wasser", 2, 2.4], "bauernhof": [{}, "getreide", 2, 9], "schweinezucht": [{"getreide": 1, "wasser": 1}, "schwein", 1, 8]}

func tf() -> float:
	return {"gemuetlich": 1.4, "normal": 1.0, "schnell": 0.5}.get(String(Session.cfg.get("tempo", "normal")), 1.0)

func _sv(k: String) -> int:
	return int(stock.get(k, 0))

# nächstes Rezept wählen (Alternativen wie im Browser)
func plan_rec(b: Dictionary):
	var T: String = b.type
	if T == "wirtshaus":
		b.status = "ST_PUB" if int(b["in"].get("bier", 0)) > 0 else "ST_MISSING"
		b.missing = "bier"
		return null
	if T == "waffenschmied":
		for p in WS_REC:
			if int(b.get("wo", {}).get(p, 0)) > 0 and has_in(b, WS_REC[p][0]):
				b.wo[p] -= 1
				return [WS_REC[p][0], p, WS_REC[p][1], WS_REC[p][2]]
		b.status = "ST_WAIT_ORDER" if not b.get("wo", {}).values().any(func(n): return int(n) > 0) else "ST_MISSING"
		return null
	var r = REC.get(T)
	if r == null:
		var o := outputs(T)
		if o.is_empty():
			return null
		var inp := {}
		for need in inputs(T):
			inp[String(need).split("|")[0]] = 1
		r = [inp, o[0], int(AMOUNT.get(T, {}).get(o[0], 1)), 8]
	r = r.duplicate(true)
	match T:
		"metzger":
			r[1] = "wurst" if _sv("wurst") < _sv("schinken") else "schinken"
		"toepfer":
			r[1] = "ziegel" if _sv("ziegel") < _sv("kruege") else "kruege"
		"brauerei":
			if int(b["in"].get("honig", 0)) >= 1 and int(b["in"].get("wasser", 0)) >= 1 and (_sv("met") <= _sv("bier") or not has_in(b, r[0])):
				r = [{"honig": 1, "wasser": 1}, "met", 1, 6]
		"bogenbauer":
			var needB := _sv("bogen") < 6
			var needP := _sv("pfeile") < 30
			if not needB and not needP:
				b.status = "ST_ENOUGH"
				return null
			var canB := has_in(b, {"bretter": 2, "sehne": 1})
			var canP := has_in(b, {"bretter": 1, "eisenbarren": 1})
			var bog: bool = (needB and canB and (not needP or not canP or _sv("bogen") * 5 <= _sv("pfeile"))) or not (needP and canP) and needB
			r = [{"bretter": 2, "sehne": 1}, "bogen", 1, 7] if bog else [{"bretter": 1, "eisenbarren": 1}, "pfeile", 5, 6]
		"goldmine":
			var dp = null
			var bd := 1e9
			for d in terrain.deposits if terrain else []:
				if d.kind == "gold" and d.found:
					var dd := Vector2(d.pos.x - b.pos.x, d.pos.z - b.pos.z).length()
					if dd < bd:
						bd = dd
						dp = d
			if dp:
				if not dp.has("left"):
					dp["left"] = 100
				if int(dp.left) <= 0:
					b.status = "ST_GOLD_EMPTY"
					return null
				b.gold_dep = dp
	if T in MINES:
		var food := ""
		for f in MINEFOOD:
			if int(b["in"].get(f, 0)) > 0:
				food = f
				break
		if food == "":
			b.status = "ST_MISSING"
			b.missing = "brot"
			return null
		r[0] = {food: 1}
		if food == "wurst" or food == "raeucherfisch":
			r[2] = 2
	if T == "wagner" and int(b.get("orders", 0)) <= 0:
		b.status = "ST_WAIT_ORDER"
		return null
	if stock_full(r[1]):
		b.status = "ST_STOCK_FULL"   # genug im Lager – Arbeiter und Träger werden für anderes frei
		return null
	if int(b.out.get(r[1], 0)) >= 8:
		b.status = "ST_OUT_FULL"
		return null
	if not has_in(b, r[0]):
		b.status = "ST_MISSING"
		for k in r[0]:
			if int(b["in"].get(k, 0)) < int(r[0][k]):
				b.missing = k
				break
		return null
	take_in(b, r[0])
	if T == "wagner":
		b.orders -= 1
	return r

func _produce(b: Dictionary, dt: float) -> void:
	if b.get("paused", false):
		b.running = false
		b.status = "ST_PAUSED"
		return
	if not b.get("running", false):
		b.idle_t = float(b.get("idle_t", 0.0)) - dt
		if b.idle_t > 0.0:
			return
		b.idle_t = 2.0
		if out_total(b) >= 6:   # Platz vor dem Haus voll: warten, bis abgeholt wird
			b.status = "ST_OUT_FULL"
			return
		var r = plan_rec(b)
		if r == null:
			return
		b.cur = r
		b.running = true
		b.t = 0.0
		b.dur = float(r[3]) * 2.5 * tf() * (0.8 if b.get("up", 0) > 0 else 1.0)
		b.status = "ST_WORKING"
		changed.emit()
		return
	b.t += dt
	if b.t >= float(b.get("dur", WORK_TIME)):
		b.running = false
		b.t = 0.0
		var r: Array = b.cur
		if b.type == "goldmine" and b.get("gold_dep") != null:
			b.gold_dep.left = maxi(0, int(b.gold_dep.left) - int(r[2]))
		put_out(b, r[1], int(r[2]))
		if b.type == "imker":
			put_out(b, "kerzen", 1)   # Wachs → Kerzen (wie im Browser)

# ---------- Wohnhäuser (Waren werden ins Haus geliefert, Bier im Wirtshaus) ----------
func near_pub(b: Dictionary):
	var best = null
	var bd := 50.0   # Einzugsbereich eines Wirtshauses (vorher 37,5 – zu knapp für normale Siedlungen)
	for p in buildings:
		if p.type != "wirtshaus" or p.build < 1.0 or p.get("removed", false) or p.get("paused", false) or p.get("worker") == null:
			continue
		bufs(p)
		if int(p["in"].get("bier", 0)) <= 0:
			continue
		var d := Vector2(p.pos.x - b.pos.x, p.pos.z - b.pos.z).length()
		if d < bd:
			bd = d
			best = p
	return best

func need_ok(b: Dictionary, k: String) -> bool:
	bufs(b)
	if k == "*food":
		return FOODS.any(func(f): return int(b["in"].get(f, 0)) > 0)
	if k == "*fine":
		return FINE.any(func(f): return int(b["in"].get(f, 0)) > 0)
	if k == "bier":
		return near_pub(b) != null
	return int(b["in"].get(k, 0)) > 0

func house_wants(b: Dictionary) -> Array:
	if b.build < 1.0 or b.get("removed", false):
		return []
	var lv: int = int(b.get("lvl", 0))
	var L: Dictionary = HOUSE_LV[lv]
	var res: Array = []
	for k in L.needs:
		if k == "bier":
			continue
		if k == "*fine" or k == "*food":
			var have := 0
			for f in (FINE if k == "*fine" else FOODS):
				have += _have(b, f)
			if have < 2:
				res.append([k, 2 - have])
			continue
		if _have(b, k) < 2:
			res.append([k, 2 - _have(b, k)])
	var uc: Dictionary = UPCOST.get(lv + 1, {})
	if int(b.get("sat", 0)) >= 1:
		for k in uc:
			if int(stock.get(k, 0)) > 0 and _have(b, k) < int(uc[k]):
				res.append([k, int(uc[k]) - _have(b, k)])
	if lv < 4:
		var nx: Dictionary = HOUSE_LV[lv + 1]
		for k in nx.needs:
			if k in L.needs or k == "bier":
				continue
			if k == "*fine" or k == "*food":
				# Essen für die nächste Stufe schon vorab liefern (sonst kann die Hütte nie aufsteigen)
				var grp: Array = FINE if k == "*fine" else FOODS
				var hv := 0
				for f in grp:
					hv += _have(b, f)
				if hv < 1 and grp.any(func(f): return int(stock.get(f, 0)) > 0):
					res.append([k, 1 - hv])
				continue
			if int(stock.get(k, 0)) <= 0:
				continue
			if _have(b, k) < 1:
				res.append([k, 1 - _have(b, k)])
	return res

# ---------- Freischalten ----------
# Lager-Obergrenze: ist genug da, pausiert der Erzeuger (sonst schleppen Träger nur noch Wasser & Co. ins Lager)
const STOCK_CAP := {"stamm": 250, "bretter": 250, "stein": 250}
func stock_full(item) -> bool:
	if item == null or not (item is String) or not stock.has(item):
		return false
	return int(stock.get(item, 0)) >= int(STOCK_CAP.get(item, 60))

func is_unlocked(t: String) -> bool:
	if String(Session.cfg.get("unlock", "normal")) == "alle":
		return true
	return int(data.unlock.get(t, 0)) <= unl

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
	bufs(b)
	var L: Dictionary = HOUSE_LV[b.lvl]
	var miss: Array = L.needs.filter(func(k): return not need_ok(b, k))
	# verbrauchen, was im Haus ist (Bier im Wirtshaus)
	for k in L.needs:
		if k == "*food" or k == "*fine":
			for f in (FOODS if k == "*food" else FINE):
				if int(b["in"].get(f, 0)) > 0:
					b["in"][f] -= 1
					note("use", f, 1)
					break
		elif k == "bier":
			var pub = near_pub(b)
			if pub:
				pub["in"].bier -= 1
				note("use", "bier", 1)
		elif int(b["in"].get(k, 0)) > 0:
			b["in"][k] -= 1
			note("use", k, 1)
	if miss.is_empty():
		b.sat = mini(3, b.sat + 1)
		b.bad = 0
		b.tax += L.tax
		if b.tax >= 1.0:
			b.tax -= 1.0
			stock.muenzen = stock.get("muenzen", 0) + 1
			note("prod", "muenzen", 1)
		b.status = "ST_HOUSE_OK"
		b.miss = []
		if b.lvl + 1 > unl:
			unl = b.lvl + 1
			message.emit(tr("MSG_UNLOCKED"))
		# Aufstieg
		if b.lvl < 4 and b.sat >= 3:
			var nx: Dictionary = HOUSE_LV[b.lvl + 1]
			var up: Dictionary = UPCOST.get(b.lvl + 1, {})
			var ok: bool = nx.needs.all(func(k): return need_ok(b, k))
			for k in up:
				if int(b["in"].get(k, 0)) < up[k]:
					ok = false
			if ok:
				for k in up:
					b["in"][k] -= up[k]
				b.lvl += 1
				b.sat = 0
				house_level_changed.emit(b)
				message.emit(tr("MSG_HOUSE_UP") % tr("HOUSE_%d" % b.lvl))
			else:
				b.miss = nx.needs.filter(func(k): return not need_ok(b, k)).map(func(k): return need_item(k))
				for k in up:
					if int(b["in"].get(k, 0)) < up[k]:
						b.miss.append(k)
				if not b.miss.is_empty():
					b.status = "ST_HOUSE_NEXT"
	else:
		b.sat = 0
		b.bad += 1
		b.status = "ST_HOUSE_MISSING"
		b.miss = miss.map(func(k): return need_item(k))
		# Kein Abstieg mehr: ein unzufriedenes Haus behält seine Stufe,
		# zahlt aber keine Steuern, bis wieder alle Waren da sind.
	changed.emit()
