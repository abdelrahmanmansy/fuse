extends SceneTree
## Diagnostic: run 4-player AI self-play across crate densities, arena sizes and
## seeds, and report the pacing metrics used by tools/ai_selfplay.gd. This keeps
## arena tuning honest: a layout is only accepted if the bots can still play it.

const MatchSim = preload("res://src/core/sim/match_sim.gd")
const Ruleset = preload("res://src/core/rules/ruleset.gd")
const ArenaLayout = preload("res://src/core/arena/arena_layout.gd")
const SimpleAi = preload("res://src/ai/simple_ai.gd")
const SimEvent = preload("res://src/core/sim/sim_event.gd")

const MAX_TICKS := 9000


func _initialize() -> void:
	var sizes := [Vector2i(15, 13), Vector2i(21, 13)]
	var densities := [62, 72, 82]
	var seeds := [20261031, 4242, 7, 777, 99]
	for size in sizes:
		for density in densities:
			for seed_value in seeds:
				_run(size.x, size.y, int(density), int(seed_value))
	quit(0)


func _run(width: int, height: int, density: int, seed_value: int) -> void:
	var rules = Ruleset.new()
	rules.countdown_ticks = 0
	var arena = ArenaLayout.new()
	if not arena.generate(width, height, seed_value, 4, density):
		printerr("generate failed")
		return
	var sim = MatchSim.new()
	sim.setup(rules, arena, seed_value, 4)
	sim.start()
	sim.step()
	var ais: Array = []
	for i in 4:
		ais.append(SimpleAi.new(seed_value + 97 * (i + 1)))

	var bombs := 0
	var explosions := 0
	var crates := 0
	var eliminations := 0
	var first_elim := -1
	var tick := 0
	while tick < MAX_TICKS and sim.phase != MatchSim.Phase.RESULTS and sim.phase != MatchSim.Phase.IDLE:
		for i in 4:
			var command: Dictionary = ais[i].think(sim, i)
			sim.submit_command(i, command["dir"], command["bomb"])
		sim.step()
		tick += 1
		for event in sim.take_events():
			match event.type:
				SimEvent.Type.BOMB_PLACED:
					bombs += 1
				SimEvent.Type.BOMB_EXPLODED:
					explosions += 1
				SimEvent.Type.CRATE_DESTROYED:
					crates += 1
				SimEvent.Type.PLAYER_ELIMINATED:
					eliminations += 1
					if first_elim < 0:
						first_elim = sim.tick
	var passed: bool = bombs >= 20 and explosions >= 10 and crates >= 5 and eliminations >= 1 \
		and sim.phase == MatchSim.Phase.RESULTS and tick >= 200
	print("%2dx%2d crate=%d%% seed=%-8d ticks=%4d bombs=%3d boom=%3d crates=%3d elim=%d %s" % [
		width, height, density, seed_value, tick, bombs, explosions, crates, eliminations,
		"PASS" if passed else "FAIL",
	])
