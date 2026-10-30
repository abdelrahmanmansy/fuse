extends RefCounted
## Pure tile grid used by the simulation. No nodes, no rendering, no engine
## singletons — it must be unit-testable headless and identical on client and
## dedicated server.
##
## Text layouts are the source format for arenas and adventure levels:
##   '#' indestructible wall   '=' destructible crate   '.' floor
## Blank lines are ignored so layout files can be grouped for readability.

enum Tile {
	FLOOR = 0,
	WALL = 1,
	CRATE = 2,
}

const CHAR_TO_TILE := {
	".": Tile.FLOOR,
	"#": Tile.WALL,
	"=": Tile.CRATE,
}
const TILE_TO_CHAR := [".", "#", "="]

var width: int = 0
var height: int = 0
## Human-readable reason for the last failed load; empty when load succeeded.
var last_error: String = ""

var _tiles := PackedByteArray()


func _init(w: int = 0, h: int = 0, fill: int = Tile.FLOOR) -> void:
	resize(w, h, fill)


func resize(w: int, h: int, fill: int = Tile.FLOOR) -> void:
	width = maxi(w, 0)
	height = maxi(h, 0)
	_tiles.resize(width * height)
	_tiles.fill(fill)


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


## Out-of-bounds reads return WALL so callers never need a bounds check before
## asking "can something move/expand here?".
func get_tile(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Tile.WALL
	return _tiles[y * width + x]


func set_tile(x: int, y: int, tile: int) -> bool:
	if not in_bounds(x, y):
		return false
	if tile < Tile.FLOOR or tile > Tile.CRATE:
		return false
	_tiles[y * width + x] = tile
	return true


func is_walkable(x: int, y: int) -> bool:
	return get_tile(x, y) == Tile.FLOOR


func count(tile: int) -> int:
	var total := 0
	for value in _tiles:
		if value == tile:
			total += 1
	return total


func dupe() -> RefCounted:
	var copy = get_script().new()
	copy.width = width
	copy.height = height
	copy._tiles = _tiles.duplicate()
	return copy


## Parses a text layout. All rows must be the same length. On failure the grid
## is reset to 0x0 and `last_error` explains why.
func load_ascii(text: String) -> bool:
	last_error = ""
	var lines: Array[String] = []
	for raw_line in text.replace("\r\n", "\n").split("\n"):
		var line: String = raw_line.strip_edges(false, true)
		if line.is_empty():
			continue
		lines.append(line)

	if lines.is_empty():
		return _fail("layout is empty")

	var row_width := lines[0].length()
	for i in lines.size():
		if lines[i].length() != row_width:
			return _fail("row %d has width %d, expected %d" % [i, lines[i].length(), row_width])

	resize(row_width, lines.size(), Tile.FLOOR)
	for y in height:
		var line := lines[y]
		for x in width:
			var char := line[x]
			if not CHAR_TO_TILE.has(char):
				resize(0, 0)
				return _fail("unknown tile '%s' at (%d, %d)" % [char, x, y])
			_tiles[y * width + x] = CHAR_TO_TILE[char]
	return true


func to_ascii() -> String:
	var lines: PackedStringArray = []
	for y in height:
		var line := ""
		for x in width:
			line += TILE_TO_CHAR[get_tile(x, y)]
		lines.append(line)
	return "\n".join(lines)


func _fail(reason: String) -> bool:
	last_error = reason
	resize(0, 0)
	return false
