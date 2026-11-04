extends Node3D
## Classic-look arena renderer. The floor is one checkerboard slab; walls and
## crates are MultiMesh layers, so the whole board stays at a handful of draw
## calls while the look can grow later without touching gameplay.
##
## The view only reads `grid`; destroyed crates are refreshed on demand from
## SimEvent.CRATE_DESTROYED.

const Style = preload("res://src/render/arena_style.gd")
const Grid = preload("res://src/core/sim/grid.gd")

const BRICK_SHADER := "res://src/render/brick.gdshader"
const CRATE_SHADER := "res://src/render/crate.gdshader"
const FLOOR_SHADER := "res://src/render/floor.gdshader"

var size: Vector2i = Vector2i(15, 13)

var _slab: MeshInstance3D
var _floor: MeshInstance3D
var _walls: MultiMeshInstance3D
var _wall_caps: MultiMeshInstance3D
var _crates: MultiMeshInstance3D


func _ready() -> void:
	_slab = MeshInstance3D.new()
	_slab.name = "FloorSlab"
	_slab.mesh = BoxMesh.new()
	_slab.material_override = Style.make_material(Style.COLOR_FLOOR_SLAB)
	_slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_slab)

	_floor = MeshInstance3D.new()
	_floor.name = "Floor"
	_floor.mesh = BoxMesh.new()
	_floor.material_override = Style.make_shader_material(FLOOR_SHADER)
	_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_floor)

	_walls = _make_layer("Walls", _box(Vector3(Style.TILE_SIZE, Style.WALL_HEIGHT, Style.TILE_SIZE)),
		Style.make_shader_material(BRICK_SHADER), true)
	_wall_caps = _make_layer("WallCaps", _box(Vector3(Style.TILE_SIZE * 0.88, 0.18, Style.TILE_SIZE * 0.88)),
		Style.make_material(Style.COLOR_WALL_TRIM), false)
	_crates = _make_layer("Crates", _box(Vector3(Style.TILE_SIZE * 0.86, Style.CRATE_HEIGHT,
		Style.TILE_SIZE * 0.86)), Style.make_shader_material(CRATE_SHADER), true)


func build(grid) -> void:
	size = Vector2i(grid.width, grid.height)

	var floor_mesh: BoxMesh = _floor.mesh
	floor_mesh.size = Vector3(float(size.x) * Style.TILE_SIZE, Style.FLOOR_THICKNESS,
		float(size.y) * Style.TILE_SIZE)
	_floor.position = Vector3(0.0, -Style.FLOOR_THICKNESS * 0.5, 0.0)
	var floor_mat: ShaderMaterial = _floor.material_override
	floor_mat.set_shader_parameter("grid_size", Vector2(size))

	_slab.mesh.size = Vector3(float(size.x) * Style.TILE_SIZE + 0.7, 0.5,
		float(size.y) * Style.TILE_SIZE + 0.7)
	_slab.position = Vector3(0.0, -0.27, 0.0)

	var wall_count := 0
	var crate_count := 0
	for y in grid.height:
		for x in grid.width:
			match grid.get_tile(x, y):
				Grid.Tile.WALL:
					wall_count += 1
				Grid.Tile.CRATE:
					crate_count += 1

	_walls.multimesh.instance_count = wall_count
	_wall_caps.multimesh.instance_count = wall_count
	_crates.multimesh.instance_count = crate_count

	var wall_index := 0
	var crate_index := 0
	for y in grid.height:
		for x in grid.width:
			var tile := Vector2i(x, y)
			var kind: int = grid.get_tile(x, y)
			if kind == Grid.Tile.WALL:
				# Boxes are centred on their origin: lift by half height so they
				# actually sit on the floor instead of sinking into it.
				_walls.multimesh.set_instance_transform(wall_index,
					_at(tile, Style.WALL_HEIGHT * 0.5))
				_walls.multimesh.set_instance_color(wall_index, _wall_color(x, y))
				_wall_caps.multimesh.set_instance_transform(wall_index,
					_at(tile, Style.WALL_HEIGHT + 0.05))
				wall_index += 1
				continue

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


## Near-white tints: the brick shader supplies the actual colour.
func _wall_color(x: int, y: int) -> Color:
	var v := 0.90 + Style.noise01(x, y, 5) * 0.10
	return Color(v, v, v)


func _crate_color(x: int, y: int) -> Color:
	var v := 0.93 + Style.noise01(x, y, 9) * 0.10
	return Color(v, v, v)


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
