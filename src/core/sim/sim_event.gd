extends RefCounted
## One-shot simulation outcome. Presentation converts these into VFX/SFX;
## networking forwards them so clients never have to infer effects.

enum Type {
	BOMB_PLACED,
	BOMB_KICKED,
	BOMB_EXPLODED,
	BLAST_SPAWNED,
	CRATE_DESTROYED,
	PICKUP_SPAWNED,
	PICKUP_COLLECTED,
	PICKUP_DESTROYED,
	PLAYER_HIT,
	PLAYER_ELIMINATED,
	PHASE_CHANGED,
	MATCH_ENDED,
	SUDDEN_DEATH_BOMB,
}

var type: int = Type.BOMB_PLACED
var tick: int = 0
var data: Dictionary = {}


func _init(event_type: int = Type.BOMB_PLACED, at_tick: int = 0, payload: Dictionary = {}) -> void:
	type = event_type
	tick = at_tick
	data = payload


func _to_string() -> String:
	return "SimEvent(%d, tick=%d, %s)" % [type, tick, data]
