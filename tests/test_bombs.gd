extends "res://tests/case.gd"

const Factory = preload("res://tests/helpers/sim_factory.gd")
const Dirs = preload("res://src/core/sim/dirs.gd")
const MatchSim = preload("res://src/core/sim/match_sim.gd")
const SimEvent = preload("res://src/core/sim/sim_event.gd")

const OPEN := "#######\n#1...2#\n#.....#\n#.....#\n#######"


func _play(layout: String = OPEN):
	var sim = Factory.build(layout)
	check(sim != null, "sim built")
	check(Factory.to_playing(sim), "reached playing phase")
	return sim


func test_placement_costs_a_capacity_slot_and_occupies_the_tile() -> void:
	var sim = _play()
	sim.rules.fuse_ticks = 999

	sim.submit_command(0, Vector2i.ZERO, true)
	sim.step()
	eq(sim.bombs.size(), 1, "one bomb placed")
	eq(sim.bombs[0].tile, Vector2i(1, 1), "bomb sits on the owner's tile")
	eq(sim.bombs[0].owner_id, 0, "owner recorded")

	# Standing on your own bomb cannot stack another one on the same tile.
	sim.submit_command(0, Vector2i.ZERO, true)
	sim.step()
	eq(sim.bombs.size(), 1, "same tile cannot hold two bombs")

	# One tile away the tile is free, but capacity 1 still blocks a second bomb.
	for i in 20:
		sim.submit_command(0, Dirs.RIGHT, false)
		sim.step()
	eq(sim.players[0].tile, Vector2i(2, 1), "stepped off the bomb")
	sim.submit_command(0, Vector2i.ZERO, true)
	sim.step()
	eq(sim.bombs.size(), 1, "capacity is enforced after leaving the tile")


func test_bomb_explodes_after_exactly_fuse_ticks() -> void:
	var sim = _play()
	sim.rules.fuse_ticks = 5

	sim.submit_command(0, Vector2i.ZERO, true)
	sim.step()
	eq(sim.bombs[0].fuse, 4, "fuse ticked once on placement")
	for i in 3:
		sim.step()
	eq(sim.bombs.size(), 1, "still armed after 3 more ticks")
	eq(sim.bombs[0].fuse, 1, "one tick left")

	sim.step()
	eq(sim.bombs.size(), 0, "exploded on the fifth tick")
	check(sim.blasts.has(Vector2i(1, 1)), "blast covers the bomb tile")
	check(not sim.players[0].alive, "owner standing on it is eliminated")
	eq(sim.phase, MatchSim.Phase.RESULTS, "last player standing ends the match")


func test_owner_may_step_off_but_not_back_on() -> void:
	var sim = _play()
	sim.rules.fuse_ticks = 999

	sim.submit_command(0, Vector2i.ZERO, true)
	sim.step()
	for i in 19:
		sim.submit_command(0, Dirs.RIGHT, false)
		sim.step()
	eq(sim.players[0].tile, Vector2i(2, 1), "stepped off the bomb")

	for i in 40:
		sim.submit_command(0, Dirs.LEFT, false)
		sim.step()
	eq(sim.players[0].tile, Vector2i(2, 1), "cannot walk back onto the armed bomb")
	check(sim.players[0].alive, "still alive")


func test_kick_power_slides_the_bomb_and_the_player_follows() -> void:
	var sim = _play()
	sim.players[0].has_kick = true
	sim.place_bomb_at(Vector2i(3, 1), -1, 999, 1)

	for i in 19:
		sim.submit_command(0, Dirs.RIGHT, false)
		sim.step()

	eq(sim.bombs[0].tile, Vector2i(4, 1), "bomb was kicked one tile ahead")
	var kicked: bool = sim.take_events().any(func(event): return event.type == SimEvent.Type.BOMB_KICKED)
	check(kicked, "BOMB_KICKED event emitted")
	eq(sim.players[0].tile, Vector2i(2, 1), "player advanced into the freed lane")
