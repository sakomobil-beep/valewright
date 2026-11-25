extends Node
# Geräusche – werden beim Start erzeugt (keine Audiodateien nötig)

const RATE := 22050
var sounds := {}
var _players: Array = []

func _ready() -> void:
	sounds.place = _make(func(t): return _tone(t, 520, 0.12) * 0.5 + _noise(t, 0.04) * 0.3, 0.14)
	sounds.build = _make(func(t): return _knock(t, 0.0) + _knock(t, 0.18) + _knock(t, 0.36), 0.5)
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

var _water: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _bird_t := 1.0
var terrain
var rig

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
	_water.volume_db = linear_to_db(maxf(0.0005, maxf(0.0, 1.0 - wd / 35.0) * 0.5 * zoom_k))
	_wind.volume_db = linear_to_db(0.05 + clampf(rig.dist / 140.0, 0.0, 1.0) * 0.15)
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
