extends Node3D
## Grey-box arena renderer. One MultiMesh per material family keeps the whole
## board at three draw calls, so the look can grow later without touching gameplay.
##
## The view only reads `grid`; destroyed crates are refreshed on demand from
## SimEvent.CRATE_DESTROYED.

const Style = preload("res://src/render/arena_style.gd")
const Grid = preload("res://src/core/sim/grid.gd")

var size: Vector2i = Vector2i(15, 13)

var _floor: MultiMeshInstance3D
var _walls: MultiMeshInstance3D
var _wall_caps: MultiMeshInstance3D
var _crates: MultiMeshInstance3D


func _ready() -> void:
	_floor = _make_layer("Floor", _box(Vector3(Style.TILE_SIZE, Style.FLOOR_THICKNESS, Style.TILE_SIZE)),
		Style.make_vertex_color_material(), false)
	_walls = _make_layer("Walls", _box(Vector3(Style.TILE_SIZE, Style.WALL_HEIGHT, Style.TILE_SIZE)),
		Style.make_vertex_color_material(), true)
	_wall_caps = _make_layer("WallCaps", _box(Vector3(Style.TILE_SIZE * 0.94, 0.16, Style.TILE_SIZE * 0.94)),
		Style.make_material(Style.COLOR_WALL_TRIM), false)
	_crates = _make_layer("Crates", _box(Vector3(Style.TILE_SIZE * 0.86, Style.CRATE_HEIGHT, Style.TILE_SIZE * 0.86)),
		Style.make_vertex_color_material(), true)


func build(grid) -> void:
	size = Vector2i(grid.width, grid.height)

	var floor_count := 0
	var wall_count := 0
	var crate_count := 0
	for y in grid.height:
		for x in grid.width:
			match grid.get_tile(x, y):
				Grid.Tile.WALL:
					wall_count += 1
				Grid.Tile.CRATE:
					crate_count += 1
					floor_count += 1
				_:
					floor_count += 1

	_floor.multimesh.instance_count = floor_count
	_walls.multimesh.instance_count = wall_count
	_wall_caps.multimesh.instance_count = wall_count
	_crates.multimesh.instance_count = crate_count

	var floor_index := 0
	var wall_index := 0
	var crate_index := 0
	for y in grid.height:
		for x in grid.width:
			var tile := Vector2i(x, y)
			var kind: int = grid.get_tile(x, y)
			if kind == Grid.Tile.WALL:
				_walls.multimesh.set_instance_transform(wall_index, _at(tile, 0.0))
				_walls.multimesh.set_instance_color(wall_index, _wall_color(x, y))
				_wall_caps.multimesh.set_instance_transform(wall_index, _at(tile, Style.WALL_HEIGHT))
				wall_index += 1
				continue

			_floor.multimesh.set_instance_transform(floor_index, _at(tile, -Style.FLOOR_THICKNESS * 0.5))
			_floor.multimesh.set_instance_color(floor_index, _floor_color(x, y))
			floor_index += 1

			if kind == Grid.Tile.CRATE:
				var scale := 0.97 + Style.noise01(x, y, 7) * 0.05
				var basis := Basis(Vector3.UP, (Style.noise01(x, y, 11) - 0.5) * 0.09).scaled(Vector3.ONE * scale)
				_crates.multimesh.set_instance_transform(crate_index,
					Transform3D(basis, Style.tile_to_world(tile, size, Style.CRATE_HEIGHT * 0.5)))
				_crates.multimesh.set_instance_color(crate_index, _crate_color(x, y))
				crate_index += 1


## Rebuild only the crate layer after a crate is destroyed.
func refresh_crates(grid) -> void:
	var crates: Array[Vector2i] = []
	for y in grid.height:
		for x in grid.width:
			if grid.get_tile(x, y) == Grid.Tile.CRATE:
				crates.append(Vector2i(x, y))

	_crates.multimesh.instance_count = crates.size()
	for i in crates.size():
		var tile: Vector2i = crates[i]
		var scale := 0.97 + Style.noise01(tile.x, tile.y, 7) * 0.05
		var basis := Basis(Vector3.UP, (Style.noise01(tile.x, tile.y, 11) - 0.5) * 0.09).scaled(Vector3.ONE * scale)
		_crates.multimesh.set_instance_transform(i,
			Transform3D(basis, Style.tile_to_world(tile, size, Style.CRATE_HEIGHT * 0.5)))
		_crates.multimesh.set_instance_color(i, _crate_color(tile.x, tile.y))


func _at(tile: Vector2i, y: float) -> Transform3D:
	return Transform3D(Basis(), Style.tile_to_world(tile, size, y))


func _floor_color(x: int, y: int) -> Color:
	var variant := Style.noise01(x, y, 3)
	return Style.COLOR_FLOOR_A.lerp(Style.COLOR_FLOOR_B, variant)


func _wall_color(x: int, y: int) -> Color:
	var variant := Style.noise01(x, y, 5)
	return Style.COLOR_WALL.darkened(variant * 0.12)


func _crate_color(x: int, y: int) -> Color:
	var variant := Style.noise01(x, y, 9)
	return Style.COLOR_CRATE.lerp(Style.COLOR_CRATE_TRIM, variant * 0.55)


func _box(size_vec: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size_vec
	return mesh


func _make_layer(node_name: String, mesh: Mesh, material: Material, shadows: bool) -> MultiMeshInstance3D:
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	instance.multimesh = multi
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance
