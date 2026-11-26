extends Node
## Hintergrundmusik (im Code komponiert, siehe tools/compose_music.py):
## Hauptmenü = feierliches Stück, im Spiel wechseln sich drei Aufbau-Stücke ab,
## bei einem Angriff blendet die Kampfmusik ein und danach wieder zurück. Eigener Bus „Musik“.

var main: Node
var _a := AudioStreamPlayer.new()
var _b := AudioStreamPlayer.new()
var _cur: AudioStreamPlayer
var _track := ""
var _build := ["aufbau_1", "aufbau_2", "aufbau_3"]
var _bi := 0
var _t := 0.0

func _ready() -> void:
	if AudioServer.get_bus_index("Musik") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Musik")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for p in [_a, _b]:
		p.bus = "Musik"
		p.volume_db = -80.0
		add_child(p)
		p.finished.connect(_on_finished.bind(p))
	_bi = randi() % _build.size()
	_cur = _a

func set_volume(v: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Musik"), linear_to_db(maxf(0.001, v)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Musik"), v <= 0.01)

func _stream(name: String, loop: bool) -> AudioStream:
	var s: AudioStreamOggVorbis = load("res://music/%s.ogg" % name)
	s = s.duplicate()
	s.loop = loop
	return s

# weich überblenden auf ein anderes Stück
func play(name: String, loop := false) -> void:
	if name == _track:
		return
	_track = name
	var nxt: AudioStreamPlayer = _b if _cur == _a else _a
	nxt.stream = _stream(name, loop)
	nxt.volume_db = -40.0
	nxt.play()
	var old := _cur
	_cur = nxt
	var tw := create_tween()
	tw.tween_property(nxt, "volume_db", -6.0, 2.5)
	tw.parallel().tween_property(old, "volume_db", -80.0, 2.5)
	tw.tween_callback(old.stop)

func _on_finished(p: AudioStreamPlayer) -> void:
	if p != _cur:
		return
	if _track.begins_with("aufbau"):
		_bi = (_bi + 1) % _build.size()
		_track = ""
		play(_build[_bi])

func _process(dt: float) -> void:
	_t -= dt
	if _t > 0.0:
		return
	_t = 1.0
	if not Session.started:
		play("menu", true)
		return
	var mil = main.get_node_or_null("Militaer") if main else null
	if mil == null and main and "military" in main:
		mil = main.military
	var battle: bool = mil != null and "_warns" in mil and not mil._warns.is_empty()
	if battle:
		if not _track.begins_with("kampf"):
			play(["kampf", "kampf_2"][randi() % 2], true)
	elif _track == "" or _track.begins_with("kampf") or _track == "menu":
		play(_build[_bi])
