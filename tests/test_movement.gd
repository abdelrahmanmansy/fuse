extends "res://tests/case.gd"

const Factory = preload("res://tests/helpers/sim_factory.gd")
const Dirs = preload("res://src/core/sim/dirs.gd")
const Grid = preload("res://src/core/sim/grid.gd")

const OPEN := "#######\n#1...2#\n#.....#\n#.....#\n#######"
const WALL_AHEAD := "#######\n#1#..2#\n#.....#\n#######"
const CRATE_AHEAD := "#######\n#1=..2#\n#.....#\n#######"


func _play(layout: String = OPEN):
	var sim = Factory.build(layout)
	check(sim != null, "sim built")
	check(Factory.to_playing(sim), "reached playing phase")
	return sim


func test_first_tile_takes_sixteen_ticks() -> void:
	var sim = _play()
	sim.submit_command(0, Dirs.RIGHT, false)
	for i in 15:
		sim.step()
	eq(sim.players[0].tile, Vector2i(1, 1), "still on the origin tile after 15 ticks")
	sim.step()
	eq(sim.players[0].tile, Vector2i(2, 1), "arrives on tick 16")


func test_held_direction_chains_tiles_without_pausing() -> void:
	var sim = _play()
	for i in 40:
		sim.submit_command(0, Dirs.RIGHT, false)
		sim.step()
	eq(sim.players[0].tile, Vector2i(3, 1), "three tiles in 40 ticks, no per-tile hitch")


func test_tap_is_buffered_for_exactly_one_tile() -> void:
	var sim = _play()
	sim.submit_command(0, Dirs.RIGHT, false)
	for i in 40:
		sim.step()
	eq(sim.players[0].tile, Vector2i(2, 1), "one tap moves one tile")
	check(not sim.players[0].moving, "stops at the tile centre")
	eq(sim.players[0].move_progress, 0, "no leftover progress")


func test_releasing_the_key_stops_at_the_next_tile_boundary() -> void:
	var sim = _play()
	for i in 25:
		sim.submit_command(0, Dirs.RIGHT, false)
		sim.step()
	eq(sim.players[0].tile, Vector2i(2, 1), "already chaining into the second tile")

	for i in 25:
		sim.submit_command(0, Vector2i.ZERO, false)
		sim.step()
	eq(sim.players[0].tile, Vector2i(3, 1), "finishes the current tile, then stops")
	check(not sim.players[0].moving, "no phantom buffered step after release")
	eq(sim.players[0].move_progress, 0, "clean stop at the tile centre")


func test_wall_blocks_movement() -> void:
	var sim = _play(WALL_AHEAD)
	for i in 40:
		sim.submit_command(0, Dirs.RIGHT, false)
		sim.step()
	eq(sim.players[0].tile, Vector2i(1, 1), "wall stops the player")


## Instant turnaround: pressing the opposite direction mid-tile flips the step
## on the spot instead of waiting for the tile boundary.
func test_opposite_direction_reverses_mid_tile() -> void:
	var sim = _play()
	for i in 7:
		sim.submit_command(0, Dirs.RIGHT, false)
		sim.step()
	var before: Vector2 = sim.players[0].visual_position()
	check(before.x > 1.0 and before.x < 1.5, "midway through the first tile")

	sim.submit_command(0, Dirs.LEFT, false)
	sim.step()
	eq(sim.players[0].facing, Dirs.LEFT, "facing flips immediately")
	check(sim.players[0].visual_position().x < before.x, "movement direction flipped")
	check(sim.players[0].visual_position().x > 1.0, "no teleport back to the tile centre")

	for i in 10:
		sim.submit_command(0, Dirs.LEFT, false)
		sim.step()
	eq(sim.players[0].tile, Vector2i(1, 1), "returns to the origin tile")
	check(not sim.players[0].moving, "stops against the wall behind it")


func test_reversal_is_refused_when_a_bomb_blocks_the_origin() -> void:
	var sim = _play()
	for i in 7:
		sim.submit_command(0, Dirs.RIGHT, false)
		sim.step()

	# A bomb appears on the tile the player came from; walking back would clip it.
	sim.place_bomb_at(Vector2i(1, 1), 0, 999, 1)
	for i in 12:
		sim.submit_command(0, Dirs.LEFT, false)
		sim.step()

	eq(sim.players[0].tile, Vector2i(2, 1), "finishes forward instead of entering the bomb tile")
	check(sim.bombs.size() == 1, "bomb still intact")


func test_crate_blocks_until_the_grid_changes() -> void:
	var sim = _play(CRATE_AHEAD)
	for i in 40:
		sim.submit_command(0, Dirs.RIGHT, false)
		sim.step()
	eq(sim.players[0].tile, Vector2i(1, 1), "crate blocks the player")

	sim.grid.set_tile(2, 1, Grid.Tile.FLOOR)
	for i in 20:
		sim.submit_command(0, Dirs.RIGHT, false)
		sim.step()
	eq(sim.players[0].tile, Vector2i(2, 1), "moves once the crate is gone")
