extends "res://tests/case.gd"

const MatchSim = preload("res://src/core/sim/match_sim.gd")
const Ruleset = preload("res://src/core/rules/ruleset.gd")
const ArenaLayout = preload("res://src/core/arena/arena_layout.gd")
const Dirs = preload("res://src/core/sim/dirs.gd")


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
	sim.step()   # countdown -> playing

	for i in ticks:
		if with_input:
			var dir0: Vector2i = Dirs.RIGHT if (i % 120) < 60 else Dirs.LEFT
			var dir1: Vector2i = Dirs.DOWN if (i % 90) < 45 else Dirs.UP
			sim.submit_command(0, dir0, i % 150 == 0)
			sim.submit_command(1, dir1, i % 210 == 0)
		sim.step()
	return sim.state_hash()


func test_identical_inputs_produce_identical_state() -> void:
	var first := _run(4242, 600, true)
	var second := _run(4242, 600, true)
	eq(first, second, "same seed + same commands => same hash after 600 ticks")


func test_seed_changes_the_world() -> void:
	var a := _run(4242, 200, false)
	var b := _run(4243, 200, false)
	check(a != b, "different seed changes the generated arena")


func test_commands_change_the_outcome() -> void:
	var with_input := _run(4242, 200, true)
	var idle := _run(4242, 200, false)
	check(with_input != idle, "commands are actually simulated")


## Locked values recorded with tools/dump_golden_hash.gd on Godot 4.7.2 (Windows).
## If a simulation change is intentional, re-run that tool and update the numbers.
func test_golden_hashes_are_locked() -> void:
	eq(_run(4242, 600, true), 3530677916, "600-tick scripted duel")
	eq(_run(4242, 200, false), 1752669574, "200 idle ticks, seed 4242")
	eq(_run(4242, 200, true), 4161587804, "200 scripted ticks, seed 4242")


func test_ten_thousand_ticks_without_a_scene_tree() -> void:
	var rules = Ruleset.new()
	var arena = ArenaLayout.new()
	check(arena.generate(15, 13, 99, 4), "arena generated")
	var sim = MatchSim.new()
	sim.setup(rules, arena, 99, 4)
	sim.start()

	var started := Time.get_ticks_msec()
	for i in 10000:
		sim.step()
	var elapsed := Time.get_ticks_msec() - started

	eq(sim.tick, 10000, "advanced exactly 10k ticks")
	check(elapsed < 5000, "10k ticks under 5 s (took %d ms)" % elapsed)
	check(sim.phase >= MatchSim.Phase.IDLE and sim.phase <= MatchSim.Phase.RESULTS,
		"phase stays in the valid range")
