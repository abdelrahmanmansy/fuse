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


func test_round_seed_is_stable_and_changes_every_round() -> void:
	var base := 4242
	eq(ArenaLayout.derive_seed(base, 1, 1), ArenaLayout.derive_seed(base, 1, 1),
		"same counters => same seed")
	check(ArenaLayout.derive_seed(base, 1, 1) != ArenaLayout.derive_seed(base, 2, 1),
		"next round changes the seed")
	check(ArenaLayout.derive_seed(base, 1, 1) != ArenaLayout.derive_seed(base, 1, 2),
		"a rematch changes the seed")

	# No collisions across a realistic series/round range, and the value must
	# stay positive so it can seed the arena RNG directly.
	var seen := {}
	for series_index in range(1, 6):
		for round_index in range(1, 9):
			var value := ArenaLayout.derive_seed(base, round_index, series_index)
			check(value >= 0 and value <= 0x7FFFFFFF, "seed is positive 31-bit: %d" % value)
			var key := "%d/%d" % [series_index, round_index]
			check(not seen.has(value), "seed for %s is unique (clashes with %s)" % [
				key, seen.get(value, "")])
			seen[value] = key


func test_every_round_generates_a_distinct_layout() -> void:
	var layouts := {}
	for round_index in range(1, 5):
		var arena = ArenaLayout.new()
		var round_seed := ArenaLayout.derive_seed(20261031, round_index, 1)
		check(arena.generate(21, 13, round_seed, 2, 82), "round %d generates" % round_index)
		var ascii: String = arena.grid.to_ascii()
		check(not layouts.has(ascii), "round %d layout is unique" % round_index)
		layouts[ascii] = true
