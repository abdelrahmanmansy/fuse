extends SceneTree
## Diagnostic: count tile types for generated arenas and print the crate:rock
## ratio. Interior rocks exclude the unbreakable border.

const ArenaLayout = preload("res://src/core/arena/arena_layout.gd")
const Grid = preload("res://src/core/sim/grid.gd")


func _initialize() -> void:
	for spec in [[15, 13], [21, 13]]:
		for seed_value in [4242, 777, 20261031]:
			_report(spec[0], spec[1], seed_value)
	quit(0)


func _report(width: int, height: int, seed_value: int) -> void:
	var arena = ArenaLayout.new()
	if not arena.generate(width, height, seed_value, 4, 82):
		printerr("generate failed: %s" % arena.last_error)
		return
	var rocks := 0
	var interior_rocks := 0
	var crates := 0
	var floor_tiles := 0
	for y in height:
		for x in width:
			match arena.grid.get_tile(x, y):
				Grid.Tile.WALL:
					rocks += 1
					if x > 0 and y > 0 and x < width - 1 and y < height - 1:
						interior_rocks += 1
				Grid.Tile.CRATE:
					crates += 1
				Grid.Tile.FLOOR:
					floor_tiles += 1
	print("%dx%d seed=%d walls=%d (interior=%d) crates=%d floor=%d crate:interior-rock=%.2f" % [
		width, height, seed_value, rocks, interior_rocks, crates, floor_tiles,
		float(crates) / float(maxi(interior_rocks, 1)),
	])
