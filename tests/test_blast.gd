extends "res://tests/case.gd"

const Factory = preload("res://tests/helpers/sim_factory.gd")
const Dirs = preload("res://src/core/sim/dirs.gd")
const Grid = preload("res://src/core/sim/grid.gd")
const MatchSim = preload("res://src/core/sim/match_sim.gd")
const SimEvent = preload("res://src/core/sim/sim_event.gd")

const WALL_AND_RANGE := "#########\n#1..#..2#\n#.......#\n#########"
const CRATE := "#######\n#1.=.2#\n#.....#\n#######"
const ADJACENT := "#######\n#12...#\n#.....#\n#######"


func _play(layout: String):
	var sim = Factory.build(layout)
	check(sim != null, "sim built")
	check(Factory.to_playing(sim), "reached playing phase")
	return sim


func _count(events: Array, type: int) -> int:
	var total := 0
	for event in events:
		if event.type == type:
			total += 1
	return total


func _explode(sim, range_value: int = 2, fuse: int = 5) -> void:
	sim.rules.fuse_ticks = fuse
	sim.players[0].blast_range = range_value
	sim.players[0].spawn_guard = 999     # propagation tests are not about damage
	sim.submit_command(0, Vector2i.ZERO, true)
	sim.step()
	# The placement step already consumes one fuse tick, so `fuse - 1` more
	# steps land exactly on the explosion tick.
	for i in fuse - 1:
		sim.step()


func test_blast_stops_at_walls_and_covers_exact_range() -> void:
	var sim = _play(WALL_AND_RANGE)
	_explode(sim, 5)

	eq(sim.blasts.size(), 4, "origin + 2 right + 1 down, then walls stop the rays")
	check(sim.blasts.has(Vector2i(1, 1)), "origin burns")
	check(sim.blasts.has(Vector2i(2, 1)), "range reaches 1 tile right")
	check(sim.blasts.has(Vector2i(3, 1)), "range reaches 2 tiles right")
	check(not sim.blasts.has(Vector2i(4, 1)), "wall blocks the ray")
	check(sim.blasts.has(Vector2i(1, 2)), "ray continues down until the border")


func test_blast_absorbs_on_a_crate_and_destroys_it() -> void:
	var sim = _play(CRATE)
	_explode(sim, 3)

	eq(sim.grid.get_tile(3, 1), Grid.Tile.FLOOR, "crate is gone")
	check(sim.blasts.has(Vector2i(3, 1)), "the crate tile burns")
	check(not sim.blasts.has(Vector2i(4, 1)), "the ray stops at the crate")
	var destroyed := _count(sim.take_events(), SimEvent.Type.CRATE_DESTROYED)
	eq(destroyed, 1, "one crate destroyed event")


func test_chain_reaction_explodes_both_bombs_in_one_tick() -> void:
	var sim = _play(ADJACENT)
	sim.rules.fuse_ticks = 5
	for player in sim.players:
		player.blast_range = 1
		player.spawn_guard = 0

	sim.submit_command(0, Vector2i.ZERO, true)
	sim.submit_command(1, Vector2i.ZERO, true)
	sim.step()
	eq(sim.bombs.size(), 2, "two armed bombs")
	for i in 4:
		sim.step()

	var events: Array = sim.take_events()
	eq(_count(events, SimEvent.Type.BOMB_EXPLODED), 2, "both bombs exploded")
	eq(sim.blasts.size(), 5, "union of both range-1 crosses")
	check(not sim.players[0].alive and not sim.players[1].alive, "both owners caught")
	eq(sim.winner_id, -1, "simultaneous deaths are a draw")
	eq(sim.phase, MatchSim.Phase.RESULTS, "match resolved")


func test_blast_lasts_exactly_blast_ticks() -> void:
	var sim = _play(WALL_AND_RANGE)
	sim.rules.blast_ticks = 10
	_explode(sim, 2)

	check(not sim.blasts.is_empty(), "blast exists on the explosion tick")
	for i in 9:
		sim.step()
	check(not sim.blasts.is_empty(), "still burning one tick before expiry")
	sim.step()
	check(sim.blasts.is_empty(), "removed after exactly 10 ticks")
