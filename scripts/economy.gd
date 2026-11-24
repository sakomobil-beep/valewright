extends Node
## Wirtschaft (Etappe 2): Lagerbestand, Baukosten und die erste Warenkette.
## Werte wie in der Browser-Version.

signal changed

var stock := {"stamm": 8, "bretter": 80, "stein": 55}
const ICONS := {"stamm": "🪵", "bretter": "🟫", "stein": "🪨"}
const COST := {
	"holzfaeller": {"bretter": 3},
	"foerster": {"bretter": 2},
	"saegewerk": {"bretter": 4, "stein": 2},
	"steinmetz": {"bretter": 3},
	"wohnhaus": {"bretter": 3, "stein": 1},
	"wachturm": {"bretter": 5, "stein": 4},
}
const BUILD_TIME := 8.0
# Arbeitszeit in Sekunden je Produktionsschritt
const WORK := {"saegewerk": 7.0}   # Holzfäller, Steinmetz, Förster arbeiten jetzt als echte Siedler

var terrain: Node3D
var buildings: Array = []
var pending: Array = []      # Waren, die Träger abholen sollen: {b, item}

func can_afford(t: String) -> bool:
	for k in COST[t]:
		if stock.get(k, 0) < COST[t][k]:
			return false
	return true

func pay(t: String) -> void:
	for k in COST[t]:
		stock[k] -= COST[t][k]
	changed.emit()

func cost_text(t: String) -> String:
	var s := ""
	for k in COST[t]:
		s += "%d%s " % [COST[t][k], ICONS[k]]
	return s.strip_edges()

func add(k: String, n: int) -> void:
	stock[k] = stock.get(k, 0) + n
	changed.emit()

func _process(dt: float) -> void:
	for b in buildings:
		if b.build < 1.0:
			if not b.get("builder_on_site", false):
				continue
			b.build = minf(1.0, b.build + dt / BUILD_TIME)
			b.node.scale = Vector3(b.s, b.s * (0.15 + 0.85 * b.build), b.s)
			continue
		if not WORK.has(b.type) or not b.get("worker_inside", false):
			continue
		b.t += dt
		if b.t < WORK[b.type]:
			continue
		b.t = 0.0
		_work(b)

func _work(b: Dictionary) -> void:
	match b.type:
		"holzfaeller":
			var tree_ = terrain.nearest_tree(b.pos, 22.0)
			if tree_ == null:
				b.status = "ST_NO_TREES"
				return
			terrain.fell_tree(tree_)
			add("stamm", 1)
			b.status = "ST_WORKING"
		"foerster":
			var tree_ = terrain.nearest_tree(b.pos, 14.0, false)
			if tree_ == null:
				b.status = "ST_IDLE"
				return
			terrain.plant_tree(tree_)
			b.status = "ST_WORKING"
		"saegewerk":
			if stock.stamm < 1:
				b.status = "ST_NO_LOGS"
				return
			stock.stamm -= 1
			changed.emit()
			pending.append({"b": b, "item": "bretter"})
			pending.append({"b": b, "item": "bretter"})
			b.status = "ST_WORKING"
		"steinmetz":
			var rk = terrain.nearest_rock(b.pos, 22.0)
			if rk == null:
				b.status = "ST_NO_ROCKS"
				return
			terrain.mine_rock(rk)
			add("stein", 1)
			b.status = "ST_WORKING"
