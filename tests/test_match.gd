extends "res://tests/case.gd"

const Factory = preload("res://tests/helpers/sim_factory.gd")
const Dirs = preload("res://src/core/sim/dirs.gd")
const MatchSim = preload("res://src/core/sim/match_sim.gd")

const DUEL := "#######\n#1.2..#\n#.....#\n#######"
const OPEN := "#######\n#1...2#\n#.....#\n#.....#\n#######"


func test_last_player_standing_wins() -> void:
	var sim = Factory.build(DUEL)
	check(Factory.to_playing(sim), "playing")
	sim.rules.fuse_ticks = 100
	sim.players[0].blast_range = 2

	sim.submit_command(0, Vector2i.ZERO, true)
	sim.step()
	for i in 110:
		sim.submit_command(0, Dirs.RIGHT, false)
		sim.step()

	check(not sim.players[1].alive, "opponent caught by the blast")
	check(sim.players[0].alive, "bomber escaped")
	eq(sim.winner_id, 0, "survivor wins")
	eq(sim.phase, MatchSim.Phase.RESULTS, "match moved to results")


func test_spawn_guard_absorbs_early_damage() -> void:
	var sim = Factory.build(OPEN)
	sim.rules.spawn_guard_ticks = 120
	sim.rules.fuse_ticks = 5
	check(Factory.to_playing(sim), "playing")
	eq(sim.players[0].spawn_guard, 120, "guard starts with the match")

	sim.submit_command(0, Vector2i.ZERO, true)
	sim.step()
	for i in 5:
		sim.step()

	check(sim.blasts.has(Vector2i(1, 1)), "bomb exploded under the player")
	check(sim.players[0].alive, "guard prevented the elimination")


func test_timer_transitions_to_sudden_death_and_drops_bombs() -> void:
	var sim = Factory.build(OPEN)
	sim.rules.match_ticks = 10
	sim.rules.sudden_death_interval_ticks = 2
	sim.rules.sudden_death_fuse_ticks = 1000
	check(Factory.to_playing(sim), "playing")

	for i in 10:
		sim.step()
	eq(sim.phase, MatchSim.Phase.SUDDEN_DEATH, "clock expired")
	eq(sim.match_ticks_left, 0, "match timer is spent")

	sim.step()
	eq(sim.bombs.size(), 1, "ceiling dropped a bomb")
	eq(sim.bombs[0].owner_id, -1, "world-owned bomb")


func test_results_phase_expires_back_to_idle() -> void:
	var sim = Factory.build(DUEL)
	sim.rules.results_ticks = 5
	check(Factory.to_playing(sim), "playing")
	sim.rules.fuse_ticks = 5
	sim.players[0].blast_range = 2

	sim.submit_command(0, Vector2i.ZERO, true)
	sim.step()
	for i in 5:
		sim.step()
	eq(sim.phase, MatchSim.Phase.RESULTS, "match ended")
	for i in 5:
		sim.step()
	eq(sim.phase, MatchSim.Phase.IDLE, "results timeout returns to idle")
