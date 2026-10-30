extends "res://tests/case.gd"

const Grid = preload("res://src/core/sim/grid.gd")


func test_ascii_roundtrip() -> void:
	var source := "#####\n#...#\n#.=.#\n#####"
	var grid = Grid.new()
	check(grid.load_ascii(source), "valid layout parses: %s" % grid.last_error)
	eq(grid.width, 5, "width")
	eq(grid.height, 4, "height")
	eq(grid.to_ascii(), source, "roundtrip is byte-identical")
	eq(grid.count(Grid.Tile.CRATE), 1, "crate count")
	eq(grid.count(Grid.Tile.WALL), 14, "wall count")


func test_blank_lines_and_crlf_are_ignored() -> void:
	var grid = Grid.new()
	check(grid.load_ascii("\r\n###\r\n#.#\r\n\r\n###\r\n"), "CRLF + blank lines parse")
	eq(grid.width, 3, "width")
	eq(grid.height, 3, "height")


func test_out_of_bounds_is_solid_and_not_walkable() -> void:
	var grid = Grid.new()
	grid.load_ascii("...\n...\n...")
	eq(grid.get_tile(-1, 0), Grid.Tile.WALL, "negative x reads as wall")
	eq(grid.get_tile(0, 99), Grid.Tile.WALL, "overflowing y reads as wall")
	check(not grid.is_walkable(3, 0), "outside the grid is not walkable")
	check(grid.is_walkable(1, 1), "floor is walkable")
	check(not grid.set_tile(5, 5, Grid.Tile.CRATE), "writing out of bounds fails")


func test_invalid_layouts_are_rejected_with_a_reason() -> void:
	var grid = Grid.new()

	check(not grid.load_ascii("###\n#?#\n###"), "unknown tile rejected")
	check(grid.last_error.contains("unknown tile"), "error names the problem")
	eq(grid.width, 0, "failed load leaves an empty grid")

	check(not grid.load_ascii("###\n##\n###"), "ragged layout rejected")
	check(grid.last_error.contains("width"), "error explains the mismatch")

	check(not grid.load_ascii("   \n\n"), "blank-only layout rejected")
	check(grid.last_error.contains("empty"), "error explains emptiness")
