extends RefCounted
## Cardinal directions. Iteration order is part of the deterministic contract:
## event ordering and chain resolution must never depend on dictionary order.

const UP := Vector2i(0, -1)
const LEFT := Vector2i(-1, 0)
const DOWN := Vector2i(0, 1)
const RIGHT := Vector2i(1, 0)

const ALL := [UP, LEFT, DOWN, RIGHT]


static func is_cardinal(dir: Vector2i) -> bool:
	return absi(dir.x) + absi(dir.y) == 1


static func is_zero(dir: Vector2i) -> bool:
	return dir.x == 0 and dir.y == 0
