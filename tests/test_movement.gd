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


func test_first_tile_takes_nineteen_ticks() -> void:
	var sim = _play()
	sim.submit_command(0, Dirs.RIGHT, false)
	for i in 18:
		sim.step()
	eq(sim.players[0].tile, Vector2i(1, 1), "still on the origin tile after 18 ticks")
	sim.step()
	eq(sim.players[0].tile, Vector2i(2, 1), "arrives on tick 19")


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
