extends Node
## Event -> SFX director. Owns a small voice pool and knows nothing about match
## rules; the app feeds it SimEvents and it maps each type to a procedural sound.

const SfxLibrary = preload("res://src/audio/sfx_library.gd")
const SimEvent = preload("res://src/core/sim/sim_event.gd")

const VOICES := 16

var master: float = 1.0
var muted: bool = false

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _next: int = 0


func _ready() -> void:
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		add_child(player)
		_players.append(player)
	for name in SfxLibrary.NAMES:
		_streams[name] = SfxLibrary.make_stream(name)


func play(sound: String) -> void:
	if muted or master <= 0.001:
		return
	var stream = _streams.get(sound, null)
	if stream == null or _players.is_empty():
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = stream
	# Headroom so chained explosions and hits do not clip.
	player.volume_db = linear_to_db(clampf(master * 0.7, 0.001, 1.0))
	player.play()


func handle_events(events: Array) -> void:
	for event in events:
		match event.type:
			SimEvent.Type.BOMB_PLACED:
				play("place")
			SimEvent.Type.BOMB_EXPLODED:
				play("explode")
			SimEvent.Type.CRATE_DESTROYED:
				play("crate")
			SimEvent.Type.PICKUP_COLLECTED:
				play("pickup")
			SimEvent.Type.PLAYER_HIT:
				play("hit")
			SimEvent.Type.MATCH_ENDED:
				play("win")
