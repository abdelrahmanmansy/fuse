extends RefCounted
## Shared presentation constants and helpers. Purely visual: nothing here feeds
## back into the simulation.
##
## World units: one tile is TILE_SIZE units. The arena is centred on the origin,
## so converting a grid cell to world space is a pure function of the arena size.

const TILE_SIZE := 2.0
const FLOOR_THICKNESS := 0.3
const WALL_HEIGHT := 1.45
const CRATE_HEIGHT := 1.05

const PLAYER_HEIGHT := 1.55
const PLAYER_RADIUS := 0.34

const COLOR_BG := Color(0.035, 0.045, 0.065)

# Classic arena palette: grass checkerboard (owned by floor.gdshader), terracotta
# brick and warm timber.
const COLOR_FLOOR_SLAB := Color(0.045, 0.075, 0.055)
const COLOR_WALL_TRIM := Color(0.560, 0.590, 0.630)
const COLOR_CRATE := Color(0.545, 0.353, 0.180)
const COLOR_CRATE_TRIM := Color(0.435, 0.263, 0.118)

const PLAYER_COLORS: Array[Color] = [
	Color(0.290, 0.780, 1.000),
	Color(1.000, 0.408, 0.373),
	Color(0.596, 0.910, 0.408),
	Color(1.000, 0.796, 0.310),
]

const PICKUP_COLORS := {
	0: Color(0.976, 0.596, 0.235),   # capacity
	1: Color(1.000, 0.365, 0.365),   # range
	2: Color(0.416, 0.878, 1.000),   # speed
	3: Color(0.749, 0.529, 1.000),   # kick
}

const PICKUP_LABELS := ["BOMB", "FIRE", "SPEED", "KICK"]

const SUIT_COLOR := Color(0.930, 0.945, 0.965)
const SKIN_COLOR := Color(0.984, 0.796, 0.639)
const EYE_COLOR := Color(0.055, 0.075, 0.105)


static func tile_to_world(tile: Vector2i, grid_size: Vector2i, height: float = 0.0) -> Vector3:
	var half_x := float(grid_size.x - 1) * 0.5
	var half_y := float(grid_size.y - 1) * 0.5
	return Vector3((float(tile.x) - half_x) * TILE_SIZE, height, (float(tile.y) - half_y) * TILE_SIZE)


static func position_to_world(position: Vector2, grid_size: Vector2i, height: float = 0.0) -> Vector3:
	var half_x := float(grid_size.x - 1) * 0.5
	var half_y := float(grid_size.y - 1) * 0.5
	return Vector3((position.x - half_x) * TILE_SIZE, height, (position.y - half_y) * TILE_SIZE)


## Stable pseudo-random 0..1 for dressing (no simulation impact).
static func noise01(x: int, y: int, salt: int = 0) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	n = absi(n) % 1000
	return float(n) / 999.0


static func make_material(color: Color, emission: Color = Color.BLACK, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


static func make_vertex_color_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.82
	return material


static func make_shader_material(path: String) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	var shader: Shader = load(path)
	if shader != null:
		material.shader = shader
	return material
