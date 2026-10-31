extends SceneTree

const MatchSim = preload("res://src/core/sim/match_sim.gd")
const Ruleset = preload("res://src/core/rules/ruleset.gd")
const ArenaLayout = preload("res://src/core/arena/arena_layout.gd")
const Dirs = preload("res://src/core/sim/dirs.gd")


func _initialize() -> void:
	for config in [[4242, 600, true], [4242, 200, false], [4243, 200, false], [4242, 200, true]]:
		print("%s -> %d" % [str(config), _run(config[0], config[1], config[2])])
	quit(0)


func _run(seed_value: int, ticks: int, with_input: bool) -> int:
	var rules = Ruleset.new()
	rules.countdown_ticks = 0
	rules.spawn_guard_ticks = 0
	rules.drop_chance_percent = 50

	var arena = ArenaLayout.new()
	arena.generate(15, 13, seed_value, 4)

	var sim = MatchSim.new()
	sim.setup(rules, arena, seed_value, 4)
	sim.start()
	sim.step()

	for i in ticks:
		if with_input:
			var dir0: Vector2i = Dirs.RIGHT if (i % 120) < 60 else Dirs.LEFT
			var dir1: Vector2i = Dirs.DOWN if (i % 90) < 45 else Dirs.UP
			sim.submit_command(0, dir0, i % 150 == 0)
			sim.submit_command(1, dir1, i % 210 == 0)
		sim.step()
	return sim.state_hash()
