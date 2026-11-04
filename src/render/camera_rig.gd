extends Camera3D
## 2.5D arena camera with automatic framing and event-driven shake.
##
## The distance is solved from the arena's world bounds so the whole board plus
## margin always fits, at any arena size. Shake uses lens offsets, so the framing
## never drifts or clips.

const Style = preload("res://src/render/arena_style.gd")

const ELEVATION_DEG := 68.0
const FIT_MARGIN := 0.90

var _base_position: Vector3 = Vector3(0, 25, 17)
var _shake: float = 0.0
var _t: float = 0.0


func setup(grid_size: Vector2i) -> void:
	projection = Camera3D.PROJECTION_PERSPECTIVE
	fov = 50.0
	near = 0.5
	far = 240.0

	var elevation := deg_to_rad(ELEVATION_DEG)
	var forward := Vector3(0.0, -sin(elevation), -cos(elevation))
	var up := Vector3(0.0, cos(elevation), -sin(elevation))
	var right := Vector3(1.0, 0.0, 0.0)

	var aspect := 16.0 / 9.0
	if get_viewport() != null:
		var size := get_viewport().get_visible_rect().size
		if size.y > 0.0:
			aspect = size.x / size.y

	var kv := tan(deg_to_rad(fov * 0.5)) * FIT_MARGIN
	var kh := kv * aspect

	var half_width := float(grid_size.x) * Style.TILE_SIZE * 0.5 + Style.TILE_SIZE * 0.35
	var half_depth := float(grid_size.y) * Style.TILE_SIZE * 0.5 + Style.TILE_SIZE * 0.35
	var height := Style.WALL_HEIGHT

	var distance := 10.0
	for corner_x in [-half_width, half_width]:
		for corner_z in [-half_depth, half_depth]:
			for corner_y in [0.0, height]:
				var point := Vector3(corner_x, corner_y, corner_z)
				var zp := point.dot(forward)
				var yp := absf(point.dot(up))
				var xp := absf(point.dot(right))
				distance = maxf(distance, maxf(yp / kv, xp / kh) - zp)

	_base_position = -forward * distance
	position = _base_position
	look_at(Vector3.ZERO, Vector3.UP)


func kick(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	_t += delta
	_shake = move_toward(_shake, 0.0, delta * 6.0)
	if _shake <= 0.001:
		h_offset = 0.0
		v_offset = 0.0
		return
	var strength := _shake * 0.35
	h_offset = sin(_t * 91.0) * strength
	v_offset = cos(_t * 73.0) * strength * 0.7
