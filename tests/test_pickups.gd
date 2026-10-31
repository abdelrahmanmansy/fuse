extends "res://tests/case.gd"

const Factory = preload("res://tests/helpers/sim_factory.gd")
const MatchSim = preload("res://src/core/sim/match_sim.gd")
const SimEvent = preload("res://src/core/sim/sim_event.gd")

const OPEN := "#######\n#1...2#\n#.....#\n#.....#\n#######"
const CRATE := "#######\n#1.=.2#\n#.....#\n#######"


func _play(layout: String = OPEN):
	var sim = Factory.build(layout)
	check(sim != null, "sim built")
	check(Factory.to_playing(sim), "reached playing phase")
	return sim


func test_capacity_range_speed_and_kick_pickups_apply() -> void:
	var sim = _play()
	var player = sim.players[0]

	sim.spawn_pickup(Vector2i(1, 1), MatchSim.PickupType.CAPACITY)
	sim.step()
	eq(player.capacity, 2, "capacity +1")

	sim.spawn_pickup(Vector2i(1, 1), MatchSim.PickupType.RANGE)
	sim.step()
	eq(player.blast_range, 3, "range +1")

	sim.spawn_pickup(Vector2i(1, 1), MatchSim.PickupType.SPEED)
	sim.step()
	eq(player.speed_level, 1, "speed level +1")
	eq(player.speed_fp, sim.rules.speed_fp_for_level(1), "speed uses the rules curve")

	sim.spawn_pickup(Vector2i(1, 1), MatchSim.PickupType.KICK)
	sim.step()
	check(player.has_kick, "kick unlocked")


func test_stats_stop_at_the_caps_but_the_pickup_is_still_consumed() -> void:
	var sim = _play()
	var player = sim.players[0]
	player.capacity = sim.rules.max_capacity

	sim.spawn_pickup(Vector2i(1, 1), MatchSim.PickupType.CAPACITY)
	sim.step()
	eq(player.capacity, sim.rules.max_capacity, "cannot exceed max capacity")
	eq(sim.pickups.size(), 0, "pickup consumed")
	var events: Array = sim.take_events()
	var applied_flags := events.filter(func(e): return e.type == SimEvent.Type.PICKUP_COLLECTED)
	eq(applied_flags.size(), 1, "collection event emitted")
	eq(applied_flags[0].data["applied"], false, "event reports no stat change")


func test_blast_destroys_a_pickup_it_burns() -> void:
	var sim = _play()
	sim.rules.fuse_ticks = 5
	sim.players[0].blast_range = 2
	sim.players[0].spawn_guard = 999
	sim.spawn_pickup(Vector2i(2, 1), MatchSim.PickupType.RANGE)

	sim.submit_command(0, Vector2i.ZERO, true)
	sim.step()
	for i in 5:
		sim.step()

	eq(sim.pickups.size(), 0, "pickup burned")
	var destroyed: Array = sim.take_events().filter(func(e): return e.type == SimEvent.Type.PICKUP_DESTROYED)
	eq(destroyed.size(), 1, "destroy event emitted")


func test_destroyed_crate_drops_loot_when_the_roll_succeeds() -> void:
	var sim = _play(CRATE)
	sim.rules.drop_chance_percent = 100
	sim.rules.fuse_ticks = 5
	sim.players[0].blast_range = 3
	sim.players[0].spawn_guard = 999

	sim.submit_command(0, Vector2i.ZERO, true)
	sim.step()
	for i in 5:
		sim.step()

	eq(sim.pickups.size(), 1, "guaranteed drop spawned")
	eq(sim.pickups[0].tile, Vector2i(3, 1), "loot lands on the crate tile")
	check(sim.pickups[0].type >= 0 and sim.pickups[0].type <= 3, "roll produced a valid type")
