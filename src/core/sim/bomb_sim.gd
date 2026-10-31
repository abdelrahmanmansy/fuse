extends RefCounted
## A bomb. Fuse and slide are tick-based; the tile updates immediately when kicked
## so collision and blast origin stay consistent even while it visually slides.

const FIXED_ONE := 1024
const SLIDE_FP_PER_TICK := 171   # ~6 ticks per tile

var id: int = -1
var owner_id: int = -1
var tile: Vector2i = Vector2i.ZERO
var fuse: int = 144
var blast_range: int = 2
var exploded: bool = false

var sliding: bool = false
var slide_from: Vector2i = Vector2i.ZERO
var slide_to: Vector2i = Vector2i.ZERO
var slide_dir: Vector2i = Vector2i.ZERO
var slide_progress: int = 0


func visual_position() -> Vector2:
	if not sliding:
		return Vector2(tile)
	var t := clampf(float(slide_progress) / float(FIXED_ONE), 0.0, 1.0)
	return Vector2(slide_from).lerp(Vector2(slide_to), t)
