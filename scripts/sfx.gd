extends Node
# Geräusche – werden beim Start erzeugt (keine Audiodateien nötig)

const RATE := 22050
var sounds := {}
var _players: Array = []

func _ready() -> void:
	sounds.place = _make(func(t): return _tone(t, 520, 0.12) * 0.5 + _noise(t, 0.04) * 0.3, 0.14)
	sounds.build = _make(func(t): return _knock(t, 0.0) + _knock(t, 0.18) + _knock(t, 0.36), 0.5)
	sounds.dig = _make(func(t): return _noise(t, 0.12) * 0.55 * (1.0 - t / 0.18), 0.18)
	sounds.chop = _make(func(t): return _knock(t, 0.0) * 1.2, 0.2)
	sounds.coin = _make(func(t): return _tone(t, 1320, 0.25) * 0.4 + _tone(t - 0.08, 1760, 0.25) * 0.4, 0.35)
	sounds.horn = _make(func(t): return _horn(t, 196, 0.9) + _horn(t, 294, 0.9) * 0.5, 0.9)
	sounds.msg = _make(func(t): return _tone(t, 660, 0.18) * 0.35 + _tone(t - 0.1, 880, 0.2) * 0.35, 0.3)
	sounds.win = _make(func(t):
		var v := 0.0
		for i in 4:
			v += _horn(t - i * 0.18, [262.0, 330.0, 392.0, 523.0][i], 0.9 - i * 0.1) * 0.5
		return v, 1.4)
	sounds.lose = _make(func(t): return _horn(t, 220, 0.6) * 0.6 + _horn(t - 0.4, 175, 0.9) * 0.6, 1.3)
	sounds.chirp = _make(func(t):
		var v := 0.0
		for k in 3:
			var u: float = t - k * 0.09
			if u > 0.0 and u < 0.06:
				v += sin(TAU * (2800.0 + u * 9000.0) * u) * (1.0 - u / 0.06) * 0.35
		return v, 0.3)
	# leise Dauergeräusche: Wasser und Wind (wie im Browser)
	_water = _loop(_brown(4.0, 0.06))
	_wind = _loop(_brown(4.0, 0.015))
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_amb_load()

var _water: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _bird_t := 1.0
var _gust_t := 6.0
var _work_t := 0.5
var terrain
var rig
var economy
var ambient := 0.8   # Lautstärke Umgebung (Einstellungen)
var _amb: Dictionary = {}       # Name → AudioStream (sounds/*.ogg)
var _p3d: Array = []            # Lautsprecher im Raum für Arbeitsgeräusche
var _p2d: Array = []            # Vögel und Wind (nicht ortsgebunden)
var _cool: Dictionary = {}      # Gebäude → Zeit bis zum nächsten Geräusch

# Arbeitsgeräusche je Gebäude: [Klang, Pause min, Pause max, Lautstärke dB]
const WORK := {
	"schmied": ["amboss", 1.2, 2.2, -4.0], "waffenschmied": ["amboss", 1.2, 2.2, -4.0], "goldschmied": ["amboss", 2.0, 3.5, -9.0],
	"muenzpraege": ["muenzen", 2.0, 3.5, -6.0], "saegewerk": ["saege", 1.5, 2.5, -6.0], "holzfaeller": ["holzhammer", 3.0, 6.0, -10.0],
	"wagner": ["holzhammer", 1.8, 3.2, -6.0], "bogenbauer": ["saege", 3.0, 5.0, -10.0], "waffenschnitzer": ["holzhammer", 2.0, 3.5, -8.0],
	"steinmine": ["spitzhacke", 1.4, 2.6, -5.0], "eisenmine": ["spitzhacke", 1.4, 2.6, -5.0], "kohlemine": ["spitzhacke", 1.4, 2.6, -5.0],
	"goldmine": ["spitzhacke", 1.4, 2.6, -5.0], "steinmetz": ["spitzhacke", 1.8, 3.2, -7.0], "lehmgrube": ["spitzhacke", 3.0, 5.0, -12.0],
	"schmelze": ["feuer", 0.2, 0.6, -6.0], "koehler": ["feuer", 0.4, 1.2, -9.0], "baeckerei": ["feuer", 1.5, 3.0, -12.0], "raeucherei": ["feuer", 1.0, 2.5, -11.0],
	"brauerei": ["brodeln", 0.3, 1.0, -8.0], "kaeserei": ["brodeln", 2.0, 4.0, -13.0], "kelterei": ["knarren", 1.5, 3.0, -7.0],
	"weberei": ["webstuhl", 0.4, 1.0, -7.0], "seilerei": ["knarren", 2.5, 4.5, -10.0], "brunnen": ["knarren", 3.0, 6.0, -9.0], "muehle": ["knarren", 2.0, 4.0, -8.0],
	"metzger": ["messer", 1.5, 3.0, -7.0], "toepfer": ["drehscheibe", 0.6, 1.5, -10.0], "konditorei": ["messer", 3.0, 5.0, -14.0],
	"schaefer": ["schaf", 4.0, 9.0, -9.0], "kuhstall": ["kuh", 6.0, 12.0, -8.0], "schweinezucht": ["schwein", 3.0, 7.0, -8.0], "imker": ["bienen", 0.5, 1.5, -12.0],
}
const BIRDS := ["amsel", "amsel", "meise", "meise", "fink", "fink", "kuckuck", "specht"]

func _amb_load() -> void:
	for f in ["amsel", "meise", "fink", "kuckuck", "specht", "blaetter", "bach", "amboss", "saege", "holzhammer", "spitzhacke", "feuer", "brodeln", "webstuhl", "knarren", "messer", "drehscheibe", "muenzen", "schaf", "kuh", "schwein", "bienen"]:
		var st = load("res://sounds/%s.ogg" % f)
		if st:
			_amb[f] = st
	for i in 10:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 9.0
		p.max_distance = 140.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.8
		add_child(p)
		_p3d.append(p)
	for i in 3:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_p2d.append(p)

func _amb_play2d(name: String, db: float) -> void:
	if not _amb.has(name):
		return
	for p in _p2d:
		if not p.playing:
			p.stream = _amb[name]
			p.volume_db = db + linear_to_db(maxf(0.001, ambient))
			p.pitch_scale = randf_range(0.94, 1.06)
			p.play()
			return

func _amb_play3d(name: String, pos: Vector3, db: float) -> void:
	if not _amb.has(name):
		return
	for p in _p3d:
		if not p.playing:
			p.stream = _amb[name]
			p.global_position = pos + Vector3(0, 1.5, 0)
			p.volume_db = db + linear_to_db(maxf(0.001, ambient))
			p.pitch_scale = randf_range(0.93, 1.07)
			p.play()
			return

func _loop(st: AudioStreamWAV) -> AudioStreamPlayer:
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p

# rotbraunes Rauschen (Wasser/Wind)
func _brown(len: float, step: float) -> AudioStreamWAV:
	var n := int(len * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var v := 0.0
	for i in n:
		v = clampf(v + randf_range(-1, 1) * step, -1.0, 1.0) * 0.995
		var fade := minf(1.0, minf(i, n - i) / 2000.0)
		data.encode_s16(i * 2, int(v * 22000 * fade))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s

func _process(dt: float) -> void:
	if not terrain or not rig or not Session.started:
		return
	var t: Vector3 = rig.target
	var wd: float = absf(t.x - terrain.river_x(t.z))
	for l in terrain.lakes:
		wd = minf(wd, Vector2(t.x, t.z).distance_to(l.p) - l.r)
	var zoom_k := clampf(1.5 - rig.dist / 70.0, 0.1, 1.0)
	_water.volume_db = linear_to_db(maxf(0.0005, maxf(0.0, 1.0 - wd / 35.0) * 0.5 * zoom_k * ambient))
	_wind.volume_db = linear_to_db(maxf(0.0005, (0.05 + clampf(rig.dist / 140.0, 0.0, 1.0) * 0.15) * ambient))
	# Windböen rauschen durchs Laub
	_gust_t -= dt
	if _gust_t < 0.0:
		_gust_t = randf_range(7.0, 16.0)
		_amb_play2d("blaetter", -15.0 + randf_range(-3, 2))
	# Arbeitsgeräusche der Gebäude in der Nähe der Kamera (im Raum verortet)
	_work_t -= dt
	if _work_t < 0.0 and economy:
		_work_t = 0.3
		var r: float = rig.dist * 0.9 + 18.0
		for b in economy.buildings:
			if not WORK.has(b.type) or b.get("owner", 0) != 0 or b.build < 1.0 or b.get("removed", false):
				continue
			if not b.get("running", false) or b.get("paused", false):
				continue
			if Vector2(b.pos.x - t.x, b.pos.z - t.z).length() > r:
				continue
			var bid: int = b.node.get_instance_id() if is_instance_valid(b.get("node")) else 0
			var cd: float = float(_cool.get(bid, 0.0)) - 0.3
			_cool[bid] = cd
			if cd > 0.0:
				continue
			var wk: Array = WORK[b.type]
			_cool[bid] = randf_range(float(wk[1]), float(wk[2])) + 1.0
			_amb_play3d(String(wk[0]), b.pos, float(wk[3]))
	# Vogelgezwitscher, wenn Bäume in der Nähe sind
	_bird_t -= dt
	if _bird_t < 0.0:
		_bird_t = randf_range(0.6, 3.1)
		var near := 0
		for k in 30:
			var tr_ = terrain.trees[randi() % terrain.trees.size()] if terrain.trees.size() else null
			if tr_ and tr_.alive and Vector2(tr_.pos.x - t.x, tr_.pos.z - t.z).length() < rig.dist * 0.8 + 10.0:
				near += 1
		if near > 1:
			play("chirp", -14.0 + randf_range(-4, 2))

func play(name: String, vol := 0.0) -> void:
	if not sounds.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = sounds[name]
			p.volume_db = vol
			p.play()
			return

func _make(f: Callable, len: float) -> AudioStreamWAV:
	var n := int(len * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = clampf(f.call(float(i) / RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	return s

func _env(t: float, len: float) -> float:
	if t < 0.0 or t > len:
		return 0.0
	return minf(1.0, t * 80.0) * (1.0 - t / len)

func _tone(t: float, f: float, len: float) -> float:
	return sin(TAU * f * t) * _env(t, len)

func _noise(t: float, len: float) -> float:
	return randf_range(-1, 1) * _env(t, len)

func _knock(t: float, at: float) -> float:
	var u := t - at
	if u < 0.0 or u > 0.12:
		return 0.0
	return (sin(TAU * 140.0 * u) * 0.7 + randf_range(-1, 1) * 0.5) * exp(-u * 40.0)

func _horn(t: float, f: float, len: float) -> float:
	var e := _env(t, len)
	return (sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.0 * t) + 0.2 * sin(TAU * f * 3.0 * t)) * e * 0.5
