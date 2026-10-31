extends RefCounted
## Test helpers. Static so tests can call Factory.build(...) without instances.

const MatchSim = preload("res://src/core/sim/match_sim.gd")
const Ruleset = preload("res://src/core/rules/ruleset.gd")
const ArenaLayout = preload("res://src/core/arena/arena_layout.gd")


## Builds a sim with a zero-length countdown, no spawn guard and no drops so
## tests describe exactly the ticks they exercise.
static func build(layout_text: String, player_count: int = 2, seed_value: int = 1234):
	var rules = Ruleset.new()
	rules.countdown_ticks = 0
	rules.spawn_guard_ticks = 0
	rules.drop_chance_percent = 0

	var arena = ArenaLayout.new()
	if not arena.load_ascii(layout_text):
		push_error("invalid test layout: %s" % arena.last_error)
		return null

	var sim = MatchSim.new()
	sim.setup(rules, arena, seed_value, player_count)
	sim.start()
	return sim


static func to_playing(sim) -> bool:
	var guard := 0
	while sim.phase == MatchSim.Phase.COUNTDOWN and guard < 1000:
		sim.step()
		guard += 1
	return sim.phase == MatchSim.Phase.PLAYING


static func run_for(sim, ticks: int, player_id: int = 0, dir: Vector2i = Vector2i.ZERO, bomb: bool = false) -> void:
	for i in ticks:
		if player_id >= 0:
			sim.submit_command(player_id, dir, bomb and i == 0)
		sim.step()
