extends RefCounted
## Arena definition: tile grid + spawn points + theme metadata.
##
## Text layouts use '#' wall, '=' crate, '.' floor and digits '1'..'4' for spawn
## points. Layouts are validated on load; adventure levels will share this format
## and add JSON metadata alongside it.

const Grid = preload("res://src/core/sim/grid.gd")
const Rng = preload("res://src/core/sim/rng.gd")

## Share of the free interior tiles that become crates. Classic arenas are dense
## with breakable cover, so the board reads as a battlefield instead of a maze of
## permanent pillars.
const DEFAULT_CRATE_PERCENT := 82
## Clear radius around each spawn. A 3x3 pocket keeps the opening safe without
## handing the bots a wide-open arena that the current AI escapes poorly.
const SPAWN_CLEAR_RADIUS := 1

var grid
var spawns: Array = []
var theme: String = ""
var name: String = ""
var last_error: String = ""


func _init(width: int = 15, height: int = 13) -> void:
	grid = Grid.new(width, height, Grid.Tile.WALL)


func load_ascii(text: String) -> bool:
	last_error = ""
	spawns.clear()

	var lines: Array[String] = []
	for raw_line in text.replace("\r\n", "\n").split("\n"):
		var line: String = raw_line.strip_edges(false, true)
		if not line.is_empty():
			lines.append(line)
	if lines.is_empty():
		return _fail("layout is empty")

	var width := lines[0].length()
	var slots: Array = [null, null, null, null]
	var cleaned := PackedStringArray()

	for y in lines.size():
		var line := lines[y]
		if line.length() != width:
			return _fail("row %d has width %d, expected %d" % [y, line.length(), width])
		var cleaned_row := ""
		for x in width:
			var ch := line[x]
			if ch >= "1" and ch <= "4":
				var index := int(ch) - 1
				if slots[index] != null:
					return _fail("spawn '%s' appears more than once" % ch)
				slots[index] = Vector2i(x, y)
				cleaned_row += "."
			elif ch == "." or ch == "#" or ch == "=":
				cleaned_row += ch
			else:
				return _fail("unknown character '%s' at (%d, %d)" % [ch, x, y])
		cleaned.append(cleaned_row)

	if not grid.load_ascii("\n".join(cleaned)):
		return _fail(grid.last_error)

	for slot in slots:
		if slot != null:
			spawns.append(slot)
	if spawns.size() < 2:
		return _fail("layout needs at least 2 spawn points, found %d" % spawns.size())
	return true


func generate(width: int, height: int, seed_value: int, spawn_count: int = 4,
		crate_percent: int = DEFAULT_CRATE_PERCENT) -> bool:
	last_error = ""
	if width < 7 or height < 5:
		return _fail("generated arenas need at least 7x5 tiles")

	var density := clampi(crate_percent, 0, 100)

	grid.resize(width, height, Grid.Tile.WALL)
	spawns.clear()

	var rng = Rng.new(seed_value)
	var corners := [
		Vector2i(1, 1),
		Vector2i(width - 2, 1),
		Vector2i(1, height - 2),
		Vector2i(width - 2, height - 2),
	]
	for i in mini(spawn_count, corners.size()):
		spawns.append(corners[i])

	# Classic pillar lattice on odd coordinates, crates elsewhere. The spawn
	# corners are odd/odd, so their 3x3 pocket stays open and the board keeps the
	# familiar two-tile lanes between permanent rocks.
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			if x % 2 == 1 and y % 2 == 1:
				grid.set_tile(x, y, Grid.Tile.WALL)
			elif _in_spawn_zone(Vector2i(x, y), spawns):
				grid.set_tile(x, y, Grid.Tile.FLOOR)
			elif rng.next_int(100) < density:
				grid.set_tile(x, y, Grid.Tile.CRATE)
			else:
				grid.set_tile(x, y, Grid.Tile.FLOOR)

	# Guarantee a clear pocket around every spawn so no one starts trapped.
	for spawn in spawns:
		for dy in range(-SPAWN_CLEAR_RADIUS, SPAWN_CLEAR_RADIUS + 1):
			for dx in range(-SPAWN_CLEAR_RADIUS, SPAWN_CLEAR_RADIUS + 1):
				var p: Vector2i = spawn + Vector2i(dx, dy)
				if _is_interior(p, width, height):
					grid.set_tile(p.x, p.y, Grid.Tile.FLOOR)
	return true


func spawn_for(player_index: int) -> Vector2i:
	return spawns[player_index % spawns.size()]


func _in_spawn_zone(point: Vector2i, points: Array) -> bool:
	for spawn in points:
		if absi(point.x - spawn.x) <= SPAWN_CLEAR_RADIUS and absi(point.y - spawn.y) <= SPAWN_CLEAR_RADIUS:
			return true
	return false


func _is_interior(point: Vector2i, width: int, height: int) -> bool:
	return point.x > 0 and point.y > 0 and point.x < width - 1 and point.y < height - 1


func _fail(reason: String) -> bool:
	last_error = reason
	return false
