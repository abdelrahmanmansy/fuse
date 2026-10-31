extends "res://tests/case.gd"

const ArenaLayout = preload("res://src/core/arena/arena_layout.gd")
const Grid = preload("res://src/core/sim/grid.gd")

const FOUR_SPAWNS := "#######\n#1...2#\n#.....#\n#3...4#\n#######"


func test_text_layout_maps_digits_to_spawns_and_floor() -> void:
	var arena = ArenaLayout.new()
	check(arena.load_ascii(FOUR_SPAWNS), "layout parses: %s" % arena.last_error)
	eq(arena.spawns.size(), 4, "four spawns")
	eq(arena.spawns[0], Vector2i(1, 1), "spawn 1")
	eq(arena.spawns[1], Vector2i(5, 1), "spawn 2")
	eq(arena.spawns[2], Vector2i(1, 3), "spawn 3")
	eq(arena.spawns[3], Vector2i(5, 3), "spawn 4")
	eq(arena.grid.get_tile(1, 1), Grid.Tile.FLOOR, "spawn tiles are walkable floor")


func test_duplicate_and_missing_spawns_are_rejected() -> void:
	var arena = ArenaLayout.new()
	check(not arena.load_ascii("####\n#11#\n#..#\n####"), "duplicate spawn rejected")
	check(arena.last_error.contains("more than once"), "error explains the duplicate")

	check(not arena.load_ascii("####\n#1.#\n#..#\n####"), "single spawn rejected")
	check(arena.last_error.contains("at least 2"), "error explains the minimum")


func test_generated_arena_is_deterministic_and_has_safe_spawns() -> void:
	var a = ArenaLayout.new()
	var b = ArenaLayout.new()
	check(a.generate(15, 13, 777), "arena A generates")
	check(b.generate(15, 13, 777), "arena B generates")
	eq(a.spawns.size(), 4, "four corner spawns")
	eq(a.grid.get_tile(0, 0), Grid.Tile.WALL, "border is solid")
	eq(a.grid.to_ascii(), b.grid.to_ascii(), "same seed => identical layout")

	for spawn in a.spawns:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var point: Vector2i = spawn + Vector2i(dx, dy)
				if point.x <= 0 or point.y <= 0 or point.x >= 14 or point.y >= 12:
					continue
				eq(a.grid.get_tile(point.x, point.y), Grid.Tile.FLOOR,
					"spawn pocket clear at %s" % point)

	var c = ArenaLayout.new()
	c.generate(15, 13, 778)
	check(a.grid.to_ascii() != c.grid.to_ascii(), "different seed => different layout")
