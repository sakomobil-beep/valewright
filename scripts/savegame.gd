extends Node
## Speichern & Laden. Spielstände liegen als JSON unter user://saves/ (auto, 1, 2, 3).

const VERSION := 1
var main: Node3D

func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]

func _p(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

func save(slot: String) -> void:
	var e: Node = main.economy
	var t: Node3D = main.terrain
	var m: Node3D = main.military
	var d := {"version": VERSION, "cfg": Session.cfg, "date": Time.get_datetime_string_from_system(false, true),
		"time": m.time, "stock": e.stock, "unl": e.unl, "mission": main.missions.mission, "step": main.missions.step,
		"mission_done": main.missions.done, "won": main.missions.won,
		"fog": Marshalls.raw_to_base64(main.fog.explored.compress(FileAccess.COMPRESSION_DEFLATE)), "fog_n": main.fog.explored.size()}
	var bl: Array = []
	for b in e.buildings:
		if b.get("destroyed", false):
			continue
		bl.append({"type": b.type, "pos": _v(b.pos), "rot": snappedf(b.node.rotation.y, 0.001), "build": b.build,
			"lvl": b.get("lvl", 0), "sat": b.get("sat", 0), "garrison": b.get("garrison", 0), "claimed": b.get("claimed", false), "site_in": b.get("site_in", {}), "site_level": b.get("site_level", 1.0), "in": b.get("in", {}), "out": b.get("out", {}), "orders": b.get("orders", 0), "wo": b.get("wo", {}), "trS": b.get("trS", 0), "trB": b.get("trB", 0), "promo": b.get("promo", 0), "up": b.get("up", 0)})
	d.buildings = bl
	d.bridges = t.bridges.map(func(br): return {"a": _v(br.a), "b": _v(br.b), "y": br.y, "len": br.get("len", 0.0)})
	var dead: Array = []
	for i in t.trees.size():
		if not t.trees[i].alive:
			dead.append(i)
	d.trees_dead = dead
	var rocks: Array = []
	for i in t.rocks.size():
		if t.rocks[i].left < 6:
			rocks.append([i, t.rocks[i].left])
	d.rocks = rocks
	var dep: Array = []
	for i in t.deposits.size():
		if t.deposits[i].found:
			dep.append(i)
	d.deposits = dep
	d.soldiers = m.soldiers.filter(func(s): return s.owner == 0 and s.state != "garrison").map(func(s): return [s.kind, s.rank])
	d.ais = m.ais.map(func(a): return {"id": a.id, "diff": a.diff, "alive": a.alive, "pos": _v(a.pos),
		"lager": a.lager.garrison, "peaceful": a.get("peaceful", false), "t_grow": a.t_grow, "t_expand": a.t_expand, "t_attack": a.t_attack,
		"towers": a.buildings.filter(func(b): return b.type == "wachturm").map(func(b): return {"pos": _v(b.pos), "g": b.garrison})})
	var f := FileAccess.open(Session.save_path(slot), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	if slot != "auto":
		main._toast(tr("MSG_SAVED"))

func apply(d: Dictionary) -> void:
	if d.has("fog") and int(d.get("fog_n", 0)) == main.fog.explored.size():
		main.fog.explored = Marshalls.base64_to_raw(d.fog).decompress(int(d.fog_n), FileAccess.COMPRESSION_DEFLATE)
		main.fog._dirty = true
	var e: Node = main.economy
	var t: Node3D = main.terrain
	var m: Node3D = main.military
	var bld: Node3D = main.builder
	for k in d.stock:
		e.stock[k] = int(d.stock[k])
	e.unl = int(d.unl)
	m.time = float(d.time)
	for i in d.trees_dead:
		t.fell_tree(t.trees[int(i)], null, true)
	for r in d.rocks:
		var k: Dictionary = t.rocks[int(r[0])]
		k.left = int(r[1]) + 1
		t.mine_rock(k)
	for i in d.deposits:
		t.reveal_deposit(t.deposits[int(i)])
	for br in d.bridges:
		bld.place_bridge({"a": _p(br.a), "b": _p(br.b), "y": float(br.y), "len": float(br.len)}, false)
	for b in d.buildings:
		bld.place_loaded(b)
	for st in d.soldiers:
		if st is Array:
			m._new_soldier(0, main.settlers.lager_door(), int(st[1]), String(st[0]))
		else:
			m._new_soldier(0, main.settlers.lager_door(), int(st))
	for a in d.ais:
		m.load_ai(a)
	m.recompute()
	main.missions.mission = int(d.get("mission", 0))
	main.missions.step = int(d.get("step", 0))
	main.missions.done = bool(d.get("mission_done", false))
	main.missions.won = bool(d.get("won", false))
	e.changed.emit()
