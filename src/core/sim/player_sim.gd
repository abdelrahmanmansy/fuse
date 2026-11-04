extends RefCounted
## Pure player state. Positions are fixed-point (1024 = one tile); rendering never
## writes here, and the server owns these values during online play.

const FIXED_ONE := 1024

var id: int = 0
var tile: Vector2i = Vector2i.ZERO
var move_from: Vector2i = Vector2i.ZERO
var move_to: Vector2i = Vector2i.ZERO
var move_progress: int = 0
var moving: bool = false
var facing: Vector2i = Vector2i.DOWN
var buffered_dir: Vector2i = Vector2i.ZERO

var speed_level: int = 0
var speed_fp: int = 64
var capacity: int = 1
var blast_range: int = 2
var has_kick: bool = false
var bomb_buffer: int = 0

var alive: bool = true
var spawn_guard: int = 0


## Tiles the body currently overlaps. Being between tiles makes you vulnerable on
## both ends, which is how classic bomb games punish late escapes.
func occupied_tiles() -> Array:
	if not moving:
		return [tile]
	return [move_from, move_to]


## Tile the player is "standing on" for bombs and pickups: flips at the midpoint.
func nearest_tile() -> Vector2i:
	if not moving:
		return tile
	return move_to if move_progress >= FIXED_ONE / 2 else move_from


## Render-only position in tile units.
func visual_position() -> Vector2:
	if not moving:
		return Vector2(tile)
	var t := clampf(float(move_progress) / float(FIXED_ONE), 0.0, 1.0)
	return Vector2(move_from).lerp(Vector2(move_to), t)


func reset_for_round(spawn: Vector2i, rules) -> void:
	tile = spawn
	move_from = spawn
	move_to = spawn
	move_progress = 0
	moving = false
	buffered_dir = Vector2i.ZERO
	facing = Vector2i.DOWN
	speed_level = 0
	speed_fp = rules.speed_fp_for_level(0)
	capacity = rules.start_capacity
	blast_range = rules.start_range
	has_kick = false
	bomb_buffer = 0
	alive = true
	spawn_guard = 0
