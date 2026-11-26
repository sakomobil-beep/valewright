extends RefCounted
class_name AiEconomy
## Wirtschaft der KI-Gegner – nach DENSELBEN Regeln wie der Spieler:
## gleicher Startvorrat, gleiche Baukosten, Bauplatz-Regeln (eigenes Gebiet, Hang, Wasser, Abstand,
## Bergwerke nur an selbst gefundenen Vorkommen), Bauzeit mit Trägern und Baumeistern
## (anfangs 2 Träger, 1 Baumeister, mehr nur über die Handwerkskammer: 1 Werkzeug, 5 Minuten),
## Einwohner aus Haupthaus und Wohnhäusern, jeder Arbeiter braucht einen freien Einwohner
## (und Werkzeug, außer bei werkzeugfreien Berufen), gleiche Rezepte und Arbeitszeiten,
## Wohnhäuser brauchen Essen und Wasser, Freischaltung über Wohnhaus-Stufen,
## Soldaten nur als Miliz (Kampfstock + Einwohner) oder aus der Kaserne (Schwert + Schild).
## Der Schwierigkeitsgrad ändert nur, wie schnell und klug die KI entscheidet – nie die Regeln.

const WALK := 2.6          # Meter pro Sekunde (Träger/Baumeister)
# Der Baumeister des Spielers läuft zwischen den Arbeitsschritten um die Baustelle herum.
# Gemessen an einer echten Spieler-Baustelle (Holzfäller: 192 s statt 60 s Nennzeit):
const LEVEL_FACTOR := 1.8   # Ebnen dauert so viel länger als die Nennzeit
const BUILD_FACTOR := 3.4   # Bauen dauert so viel länger als die Nennzeit
const THINK := {"leicht": 24.0, "mittel": 12.0, "schwer": 6.0}   # Bedenkzeit zwischen Entscheidungen
# Bauplan: was die KI der Reihe nach anstrebt (wird übersprungen, wenn nicht möglich)
const PLAN := ["holzfaeller", "holzfaeller", "saegewerk", "steinmetz", "foerster", "wohnhaus", "brunnen", "fischer",
	"bauernhof", "wohnhaus", "waffenschnitzer", "muehle", "baeckerei", "wachstube", "rutengaenger", "handwerkskammer",
	"wohnhaus", "kohlemine", "eisenmine", "schmelze", "schmied", "schweinezucht", "metzger", "wachstube", "holzfaeller",
	"saegewerk", "wohnhaus", "steinmine", "wachstube", "brauerei", "hopfenbauer", "wirtshaus", "wohnhaus",
	"waffenschmied", "kaserne", "wachstube", "wohnhaus", "wachturm"]
# Berufe ohne festes Rezept: [Ware, Sekunden je Stück, Bedingung]
const FIELD := {"holzfaeller": ["stamm", 12.0], "steinmetz": ["stein", 12.0], "fischer": ["fisch", 10.0], "foerster": ["", 14.0]}

var mil      # military.gd
var eco      # economy.gd des Spielers (nur für Regeln/Daten, nicht für den Vorrat!)
var terrain
var data: Dictionary

func _init(m) -> void:
	mil = m
	eco = m.economy
	terrain = m.terrain
	data = eco.data

func tf() -> float:
	return eco.tf()

# ---------- Start: wie der Spieler ----------
func setup(ai: Dictionary) -> void:
	var st := {}
	for k in data.items:
		st[k] = int(round(int(data.start.get(k, 0)) * {"wenig": 0.5, "normal": 1.0, "viel": 2.0}.get(String(Session.cfg.get("start", "normal")), 1.0)))
	ai.eco = {"stock": st, "residents": eco.BASE_HOMES, "builders": 2, "carriers": 2, "unl": 0, "plan": 0, "think": randf() * 4.0,
		"grow_t": 0.0, "found": [], "searched": [], "tq": [], "tq_t": 0.0, "stuck": 0}
	ai.lager.build = 1.0

func S(ai: Dictionary) -> Dictionary:
	return ai.eco.stock

func home_cap(ai: Dictionary) -> int:
	var n: int = eco.BASE_HOMES
	for b in ai.buildings:
		if b.type == "wohnhaus" and b.get("build", 1.0) >= 1.0 and not b.get("destroyed", false):
			n += eco.HOUSE_PEOPLE[clampi(int(b.get("lvl", 0)), 0, 4)]
	return n

func used_people(ai: Dictionary) -> int:
	var n: int = int(ai.eco.builders) + int(ai.eco.carriers)
	for b in ai.buildings:
		if b.get("worker", false):
			n += 1
	n += int(ai.lager.garrison) + int(ai.eco.get("out", 0))
	for b in ai.buildings:
		if mil.GARRISON.has(b.type):
			n += int(b.get("garrison", 0))
	return n

func free_people(ai: Dictionary) -> int:
	return int(ai.eco.residents) - used_people(ai)

func unlocked(ai: Dictionary, t: String) -> bool:
	if String(Session.cfg.get("unlock", "schritt")) == "alle":
		return true
	return int(data.get("unlock", {}).get(t, 0)) <= int(ai.eco.unl)

func afford(ai: Dictionary, t: String) -> bool:
	var c: Dictionary = data.types[t].get("cost", {})
	for k in c:
		if int(S(ai).get(k, 0)) < int(c[k]):
			return false
	return true

# ---------- Takt ----------
func tick(ai: Dictionary, dt: float) -> void:
	var E: Dictionary = ai.eco
	_grow(ai, dt)
	_sites(ai, dt)
	for b in ai.buildings:
		if b.get("destroyed", false) or b.get("build", 1.0) < 1.0:
			continue
		match b.type:
			"wohnhaus": _house(ai, b, dt)
			"handwerkskammer": _guild(ai, b, dt)
			"rutengaenger": _dowse(ai, b, dt)
			"kaserne": _barracks(ai, b, dt)
			_:
				if FIELD.has(b.type) or eco.REC.has(b.type):
					_work(ai, b, dt)
	_militia(ai)
	E.think -= dt
	if E.think <= 0.0:
		E.think = THINK.get(String(ai.diff), 12.0) * randf_range(0.8, 1.2)
		_decide(ai)

func _grow(ai: Dictionary, dt: float) -> void:
	var E: Dictionary = ai.eco
	E.grow_t += dt
	if E.grow_t < eco.GROW_TIME * tf():
		return
	E.grow_t = 0.0
	if int(E.residents) >= home_cap(ai):
		return
	var happy: bool = ai.buildings.any(func(b): return b.type == "wohnhaus" and b.get("build", 1.0) >= 1.0 and int(b.get("sat", 0)) > 0)
	if int(E.residents) < eco.BASE_HOMES or happy:
		E.residents += 1

# ---------- Baustellen: Träger bringen Material, Baumeister ebnet und baut ----------
func _sites(ai: Dictionary, dt: float) -> void:
	var E: Dictionary = ai.eco
	var busy := 0
	for b in ai.buildings:
		if b.get("build", 1.0) < 1.0 and b.get("site_builder", false):
			busy += 1
	for b in ai.buildings:
		if b.get("build", 1.0) >= 1.0 or b.get("destroyed", false):
			continue
		# Material anliefern: Träger teilen sich die Wege
		if b.deliver_t > 0.0:
			b.deliver_t -= dt * float(E.carriers) / maxf(1.0, float(_open_sites(ai)))
		# Baumeister anfordern
		if not b.get("site_builder", false):
			if busy < int(E.builders):
				b.site_builder = true
				b.walk_t = ai.pos.distance_to(b.pos) / WALK
				busy += 1
			else:
				continue
		if b.walk_t > 0.0:
			b.walk_t -= dt
			continue
		if b.level_t > 0.0:
			b.level_t -= dt
			continue
		if b.deliver_t > 0.0 and b.build >= 0.5:
			continue   # wartet auf Material
		var r: float = float(data.types[b.type].r)
		b.build = minf(1.0, b.build + dt / ((30.0 + r * 9.0) * tf() * BUILD_FACTOR))
		b.node.scale = Vector3(1.5, 1.5 * maxf(0.06, b.build), 1.5)
		if b.build >= 1.0:
			b.site_builder = false
			b.node.scale = Vector3.ONE * 1.5
			_on_built(ai, b)

func _open_sites(ai: Dictionary) -> int:
	return ai.buildings.filter(func(b): return b.get("build", 1.0) < 1.0 and b.deliver_t > 0.0 and not b.get("destroyed", false)).size()

func _on_built(ai: Dictionary, b: Dictionary) -> void:
	if mil.GARRISON.has(b.type):
		b.claim_wait = true   # Gebiet erst, wenn jemand drin ist
		return
	_hire(ai, b)

# Arbeiter einstellen: freier Einwohner + Werkzeug (außer werkzeugfreie Berufe)
func _hire(ai: Dictionary, b: Dictionary) -> bool:
	if b.get("worker", false) or b.type in ["wohnhaus", "lager"] or mil.GARRISON.has(b.type):
		return true
	if free_people(ai) < 1:
		return false
	if not b.type in eco.TOOL_FREE and not b.type in ["handwerkskammer", "wirtshaus", "kaserne"]:
		if int(S(ai).get("werkzeug", 0)) < 1:
			return false
		S(ai).werkzeug -= 1
	b.worker = true
	return true

# ---------- Produktion ----------
func _work(ai: Dictionary, b: Dictionary, dt: float) -> void:
	if not b.get("worker", false):
		b.hire_t = float(b.get("hire_t", 0.0)) - dt
		if b.hire_t <= 0.0:
			b.hire_t = 5.0
			_hire(ai, b)
		return
	if not b.get("running", false):
		var ok := true
		var inp: Dictionary = {}
		var out := ""
		var n := 1
		var dur := 10.0
		if FIELD.has(b.type):
			out = FIELD[b.type][0]
			dur = FIELD[b.type][1] * 2.5 * tf()
			match b.type:
				"holzfaeller":
					var tr_ = terrain.nearest_tree(b.pos, 30.0, true)
					ok = tr_ != null
					if ok:
						b.tree = tr_
				"steinmetz":
					ok = terrain.nearest_rock(b.pos, 30.0) != null
				"fischer":
					ok = _water_near(b.pos, 14.0)
		else:
			var rec: Array = eco.REC[b.type]
			inp = rec[0]
			out = rec[1]
			n = int(rec[2])
			dur = float(rec[3]) * 2.5 * tf()
			if b.type in eco.MINES:
				# Bergleute brauchen Essen
				var food := ""
				for f in eco.MINEFOOD:
					if int(S(ai).get(f, 0)) > 0:
						food = f
						break
				if food == "":
					ok = false
				else:
					inp = inp.duplicate()
					inp[food] = 1
		for k in inp:
			if int(S(ai).get(k, 0)) < int(inp[k]):
				ok = false
		if out != "" and data.items.has(out) and int(S(ai).get(out, 0)) >= 250:
			ok = false   # Lager voll
		if not ok:
			return
		for k in inp:
			S(ai)[k] -= int(inp[k])
		b.running = true
		b.t = 0.0
		b.dur = dur + 2.0 * ai.pos.distance_to(b.pos) / WALK / maxf(1.0, float(ai.eco.carriers))   # Wege der Träger
		b.out = out
		b.n = n
		return
	b.t += dt
	if b.t >= b.dur:
		b.running = false
		if b.type == "holzfaeller" and b.get("tree") != null and b.tree.alive:
			terrain.fell_tree(b.tree, null, true)
		elif b.type == "steinmetz":
			var rk = terrain.nearest_rock(b.pos, 30.0)
			if rk:
				terrain.mine_rock(rk)
		if b.out != "":
			S(ai)[b.out] = int(S(ai).get(b.out, 0)) + int(b.n)

func _water_near(p: Vector3, r: float) -> bool:
	for a in 12:
		var q := p + Vector3(cos(a * TAU / 12), 0, sin(a * TAU / 12)) * r
		if terrain.height(q.x, q.z) < terrain.WATER_Y:
			return true
	return false

# ---------- Wohnhäuser: Essen + Wasser, Zufriedenheit, Aufstieg, Freischaltung ----------
func _house(ai: Dictionary, b: Dictionary, dt: float) -> void:
	if not b.has("lvl"):
		b.lvl = 0
		b.sat = 0
		b.ht = eco.HOUSE_TICK - 5.0
	b.ht += dt
	if b.ht < eco.HOUSE_TICK:
		return
	b.ht = 0.0
	var L: Dictionary = eco.HOUSE_LV[b.lvl]
	var ok := true
	for k in L.needs:
		if not _take_need(ai, k, true):
			ok = false
	if ok:
		for k in L.needs:
			_take_need(ai, k, false)
		b.sat = mini(3, int(b.sat) + 1)
		ai.eco.unl = maxi(int(ai.eco.unl), int(b.lvl) + 1)
		if b.lvl < 4 and b.sat >= 3:
			var nx: Dictionary = eco.HOUSE_LV[b.lvl + 1]
			var up: Dictionary = eco.UPCOST.get(b.lvl + 1, {})
			var can := true
			for k in nx.needs:
				if not _take_need(ai, k, true):
					can = false
			for k in up:
				if int(S(ai).get(k, 0)) < int(up[k]):
					can = false
			if can:
				for k in up:
					S(ai)[k] -= int(up[k])
				b.lvl += 1
				b.sat = 0
	else:
		b.sat = maxi(0, int(b.sat) - 1)

func _take_need(ai: Dictionary, k: String, check: bool) -> bool:
	var opts: Array = [k]
	if k == "*food":
		opts = eco.FOODS
	elif k == "*fine":
		opts = eco.FINE
	elif k == "bier":
		if not ai.buildings.any(func(b): return b.type == "wirtshaus" and b.get("build", 1.0) >= 1.0):
			return false
	for f in opts:
		if int(S(ai).get(f, 0)) > 0:
			if not check:
				S(ai)[f] -= 1
			return true
	return false

# ---------- Handwerkskammer: Baumeister / Träger ausbilden ----------
func _guild(ai: Dictionary, b: Dictionary, dt: float) -> void:
	var E: Dictionary = ai.eco
	if E.tq.is_empty():
		return
	E.tq_t += dt
	if E.tq_t >= eco.TRAIN_TIME and free_people(ai) >= 1:
		E.tq_t = 0.0
		var k: String = E.tq.pop_front()
		if k == "bau":
			E.builders += 1
		else:
			E.carriers += 1

# ---------- Rutengänger: sucht selbst – Funde gehören nur dieser KI ----------
func _dowse(ai: Dictionary, b: Dictionary, dt: float) -> void:
	if not b.get("worker", false):
		_hire(ai, b)
		return
	b.t = float(b.get("t", 0.0)) + dt
	if b.t < 25.0 * tf():
		return
	b.t = 0.0
	var best = null
	var bd := 1e9
	for k in 60:
		var ang := randf() * TAU
		var rr := 6.0 + randf() * 40.0
		var x: float = b.pos.x + cos(ang) * rr
		var z: float = b.pos.z + sin(ang) * rr
		if terrain.mountain(x, z) < 2.5:
			continue
		if ai.eco.searched.any(func(q): return Vector2(q[0] - x, q[1] - z).length() < 5.0):
			continue
		var near := 0.0
		for i in terrain.deposits.size():
			var d: Dictionary = terrain.deposits[i]
			if not ai.eco.found.has(i) and Vector2(d.pos.x - x, d.pos.z - z).length() < 12.0:
				near = -15.0
				break
		if rr + near < bd:
			bd = rr + near
			best = [x, z]
	if best == null:
		return
	ai.eco.searched.append(best)
	if ai.eco.searched.size() > 80:
		ai.eco.searched.pop_front()
	for i in terrain.deposits.size():
		var d: Dictionary = terrain.deposits[i]
		if not ai.eco.found.has(i) and Vector2(d.pos.x - best[0], d.pos.z - best[1]).length() < 6.5:
			ai.eco.found.append(i)
			break

# ---------- Kaserne: Schwert + Schild + Einwohner → Kämpfer ----------
func _barracks(ai: Dictionary, b: Dictionary, dt: float) -> void:
	if float(b.get("train_t", 0.0)) > 0.0:
		b.train_t -= dt
		if b.train_t <= 0.0:
			ai.lager.garrison += 1
		return
	if free_people(ai) > 0 and int(S(ai).get("schwert", 0)) > 0 and int(S(ai).get("schild", 0)) > 0:
		S(ai).schwert -= 1
		S(ai).schild -= 1
		b.train_t = 6.0 * 2.5 * tf()

# ---------- Türme besetzen: Kämpfer aus dem Lager oder Miliz (Kampfstock + Einwohner) ----------
func _militia(ai: Dictionary) -> void:
	for b in ai.buildings:
		if not mil.GARRISON.has(b.type) or b.get("build", 1.0) < 1.0 or b.get("destroyed", false):
			continue
		if int(b.garrison) > 0:
			if b.get("claim_wait", false):
				b.claim_wait = false
				mil.claims.append({"pos": b.pos, "r": mil.CLAIM.get(b.type, 30.0), "owner": ai.id, "b": b})
				mil.recompute()
			continue
		if int(ai.lager.garrison) > 0:
			ai.lager.garrison -= 1
			b.garrison = 1
		elif int(S(ai).get("kampfstock", 0)) > 0 and free_people(ai) > 0:
			S(ai).kampfstock -= 1
			b.garrison = 1

# ---------- Entscheiden, was als Nächstes gebaut wird ----------
func _decide(ai: Dictionary) -> void:
	var E: Dictionary = ai.eco
	# Handwerkskammer nutzen, wenn Baustellen warten
	var hk: bool = ai.buildings.any(func(b): return b.type == "handwerkskammer" and b.get("build", 1.0) >= 1.0)
	var waiting: int = ai.buildings.filter(func(b): return b.get("build", 1.0) < 1.0 and not b.get("site_builder", false)).size()
	if hk and E.tq.size() < 2 and int(S(ai).get("werkzeug", 0)) > 3:
		if waiting >= 2 and int(E.builders) < 4:
			S(ai).werkzeug -= 1
			E.tq.append("bau")
		elif _open_sites(ai) >= 3 and int(E.carriers) < 6:
			S(ai).werkzeug -= 1
			E.tq.append("tr")
	# nicht zu viele Baustellen gleichzeitig (wie ein vernünftiger Spieler)
	if ai.buildings.filter(func(b): return b.get("build", 1.0) < 1.0).size() >= int(E.builders) + 2:
		return
	# Nachschub: zu wenig Bretter/Stämme → Holz zuerst
	var want := ""
	if int(S(ai).get("bretter", 0)) < 6 and int(S(ai).get("stamm", 0)) < 4 and ai.buildings.filter(func(b): return b.type == "holzfaeller").size() < 4:
		want = "holzfaeller"
	elif int(E.residents) >= home_cap(ai) - 1 and int(S(ai).get("bretter", 0)) >= 5 and _can_grow(ai) \
			and not ai.buildings.any(func(b): return b.type == "wohnhaus" and b.get("build", 1.0) < 1.0):
		want = "wohnhaus"
	elif int(E.plan) < PLAN.size():
		want = PLAN[E.plan]
	else:
		want = ["wohnhaus", "wachstube", "holzfaeller", "bauernhof", "fischer"][randi() % 5]
	if not data.types.has(want) or not unlocked(ai, want):
		E.plan += 1
		return
	if mil.GARRISON.has(want) and not _may_expand(ai):
		if int(E.plan) < PLAN.size() and PLAN[E.plan] == want:
			E.plan += 1
		return
	if not afford(ai, want):
		E.stuck += 1
		if E.stuck > 12:
			E.stuck = 0
			E.plan += 1   # kommt nicht weiter: später nochmal
		return
	var p = _find_spot(ai, want)
	if p == null:
		E.stuck += 1
		if E.stuck > 6:
			E.stuck = 0
			if want != "wachstube" and afford(ai, "wachstube") and _may_expand(ai) and not want in ["fischer", "steinmetz"]:
				var q = _find_spot(ai, "wachstube")   # kein Platz: Gebiet erweitern
				if q != null:
					_start_site(ai, "wachstube", q)
					return
			E.plan += 1
		return
	E.stuck = 0
	_start_site(ai, want, p)
	if int(E.plan) < PLAN.size() and PLAN[E.plan] == want:
		E.plan += 1

# Wachstube nur, wenn alle bisherigen Türme fertig und besetzt sind und jemand sie besetzen kann
func _may_expand(ai: Dictionary) -> bool:
	for b in ai.buildings:
		if mil.GARRISON.has(b.type) and not b.get("destroyed", false) and (b.get("build", 1.0) < 1.0 or int(b.garrison) == 0):
			return false
	return int(ai.lager.garrison) > 0 or (int(S(ai).get("kampfstock", 0)) > 0 and free_people(ai) > 1)

# Einwohner wachsen nur mit zufriedenem Wohnhaus (oder unter der Grundzahl)
func _can_grow(ai: Dictionary) -> bool:
	return int(ai.eco.residents) < eco.BASE_HOMES or ai.buildings.any(func(b): return b.type == "wohnhaus" and int(b.get("sat", 0)) > 0)

func _start_site(ai: Dictionary, t: String, p: Vector3) -> void:
	var c: Dictionary = data.types[t].get("cost", {})
	var units := 0
	for k in c:
		S(ai)[k] -= int(c[k])
		units += int(c[k])
	var b: Dictionary = mil._ai_building(ai, t, p, 0)
	b.build = 0.0
	b.node.scale = Vector3(1.5, 0.09, 1.5)
	# jede Ladung ein Weg vom Lager zur Baustelle und zurück
	b.deliver_t = units * (2.0 * ai.pos.distance_to(p) / WALK + 2.0)
	b.level_t = 12.0 * tf() * LEVEL_FACTOR
	b.walk_t = 0.0
	b.site_builder = false
	if t in eco.MINES:
		b.dep = _dep_for(ai, t, p)

func _dep_for(ai: Dictionary, t: String, p: Vector3):
	var kind: String = data.types[t].get("mine", "")
	for i in ai.eco.found:
		var d: Dictionary = terrain.deposits[i]
		if d.kind == kind and Vector2(d.pos.x - p.x, d.pos.z - p.z).length() < 6.0:
			return i
	return null

# Bauplatz nach den Regeln des Spielers (builder.can_place), nur im eigenen Gebiet
func _find_spot(ai: Dictionary, t: String):
	var info: Dictionary = data.types[t]
	var r: float = float(info.r) * 1.5
	var cands: Array = []
	if info.get("mine") != null:
		for i in ai.eco.found:
			var d: Dictionary = terrain.deposits[i]
			if d.kind == info.mine and int(d.get("left", 1)) > 0:
				for a in 8:
					cands.append(d.pos + Vector3(cos(a * TAU / 8), 0, sin(a * TAU / 8)) * randf_range(1.0, 4.5))
	elif mil.GARRISON.has(t):
		# Militär an den Rand des Gebiets, bevorzugt Richtung Berge und freiem Land
		for b in ai.buildings:
			if b.type == "lager" or mil.GARRISON.has(b.type):
				for k in 10:
					var a := randf() * TAU
					cands.append(b.pos + Vector3(cos(a), 0, sin(a)) * randf_range(18.0, 26.0))
	else:
		for k in 120:
			var a := k * 0.83
			var rr := 9.0 + k * 0.22
			cands.append(ai.pos + Vector3(cos(a) * rr, 0, sin(a) * rr))
	var best = null
	var bs := -1e9
	for q in cands:
		var pp: Vector3 = q
		pp.y = terrain.height(pp.x, pp.z)
		if not _can_place(ai, t, pp, r):
			continue
		var score := -pp.distance_to(ai.pos)
		if mil.GARRISON.has(t):
			score = 0.0
			for k in 8:   # wie viel neues, freies Land käme dazu
				var a := k * TAU / 8
				var z: Vector3 = pp + Vector3(cos(a), 0, sin(a)) * 24.0
				if mil.owner_at(z) == -1:
					score += 1.0 + (1.5 if terrain.mountain(z.x, z.z) > 2.0 else 0.0)
		elif t == "fischer":
			score = -pp.distance_to(ai.pos) - (0.0 if _water_near(pp, 12.0) else 1000.0)
		elif t in ["holzfaeller", "foerster"]:
			score = -pp.distance_to(ai.pos) * 0.5 - (0.0 if terrain.nearest_tree(pp, 20.0, true) != null else 200.0)
		elif t == "steinmetz":
			score = -pp.distance_to(ai.pos) * 0.5 - (0.0 if terrain.nearest_rock(pp, 25.0) != null else 400.0)
		elif t == "rutengaenger":
			score = -pp.distance_to(ai.pos) * 0.3 - _mount_dist(pp)
		if score > bs:
			bs = score
			best = pp
	if t in ["fischer", "steinmetz"] and bs < -300.0:
		return null
	return best

func _mount_dist(p: Vector3) -> float:
	var best := 200.0
	for m in terrain.mountains:
		best = minf(best, Vector2(m.p.x - p.x, m.p.y - p.z).length() - m.r)
	return best

func _can_place(ai: Dictionary, t: String, p: Vector3, r: float) -> bool:
	if mil.owner_at(p) != ai.id:
		return false
	for a in [0.0, PI / 2, PI, PI * 1.5]:
		var q := p + Vector3(cos(a), 0, sin(a)) * r
		if terrain.height(q.x, q.z) < terrain.WATER_Y + 0.4:
			return false
		if absf(terrain.height(q.x, q.z) - p.y) > 1.6:
			return false
		if mil.owner_at(q) != ai.id:
			return false
	var mine: bool = data.types[t].get("mine") != null
	if not mine and terrain.mountain(p.x, p.z) > 6.0:
		return false
	if mine and _dep_for(ai, t, p) == null:
		return false
	for b in ai.buildings:
		if b.pos.distance_to(p) < r + float(data.types[b.type].r) * 1.5 + 1.0:
			return false
	for b in eco.buildings:
		if not b.get("removed", false) and b.pos.distance_to(p) < r + float(data.types[b.type].r) * 1.5 + 1.0:
			return false
	return true

# ---------- Speichern ----------
func save(ai: Dictionary) -> Dictionary:
	var E: Dictionary = ai.eco
	var bl: Array = []
	for b in ai.buildings:
		if b.type == "lager" or b.get("destroyed", false):
			continue
		bl.append({"t": b.type, "p": [b.pos.x, b.pos.y, b.pos.z], "build": b.get("build", 1.0), "g": b.get("garrison", 0),
			"worker": b.get("worker", false), "lvl": b.get("lvl", 0), "sat": b.get("sat", 0), "claimed": not b.get("claim_wait", false),
			"deliver_t": b.get("deliver_t", 0.0), "level_t": b.get("level_t", 0.0)})
	return {"stock": E.stock, "residents": E.residents, "builders": E.builders, "carriers": E.carriers, "unl": E.unl,
		"plan": E.plan, "found": E.found, "tq": E.tq, "tq_t": E.tq_t, "bld": bl}

func restore(ai: Dictionary, s: Dictionary) -> void:
	var E: Dictionary = ai.eco
	for k in s.stock:
		E.stock[k] = int(s.stock[k])
	for k in ["residents", "builders", "carriers", "unl", "plan"]:
		E[k] = int(s.get(k, E[k]))
	E.found = s.get("found", []).map(func(x): return int(x))
	E.tq = s.get("tq", [])
	E.tq_t = float(s.get("tq_t", 0.0))
	for e in s.get("bld", []):
		var b: Dictionary = mil._ai_building(ai, String(e.t), Vector3(e.p[0], e.p[1], e.p[2]), int(e.g))
		b.build = float(e.build)
		b.worker = bool(e.worker)
		b.lvl = int(e.lvl)
		b.sat = int(e.sat)
		b.deliver_t = float(e.get("deliver_t", 0.0))
		b.level_t = float(e.get("level_t", 0.0))
		b.walk_t = 0.0
		b.site_builder = false
		if b.build < 1.0:
			b.node.scale = Vector3(1.5, 1.5 * maxf(0.06, b.build), 1.5)
		if mil.GARRISON.has(b.type):
			if bool(e.claimed) and b.build >= 1.0:
				mil.claims.append({"pos": b.pos, "r": mil.CLAIM.get(b.type, 30.0), "owner": ai.id, "b": b})
			else:
				b.claim_wait = true
		if b.type in eco.MINES:
			b.dep = _dep_for(ai, b.type, b.pos)
