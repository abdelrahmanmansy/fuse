extends RefCounted
## Deterministic PRNG for simulation-owned randomness.
##
## Godot's RandomNumberGenerator is fine for cosmetics, but loot rolls, arena
## generation and sudden-death drops must be reproducible across runs and (for
## prediction) across machines. xorshift32 uses only 32-bit XOR/shift, so it is
## stable and cannot overflow a signed 64-bit int.

var state: int = 0x9E3779B9


func _init(seed_value: int = 1) -> void:
	reseed(seed_value)


func reseed(seed_value: int) -> void:
	state = seed_value & 0xFFFFFFFF
	if state == 0:
		state = 0x9E3779B9


func next_u32() -> int:
	var x := state
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	state = x & 0xFFFFFFFF
	return state


## Uniform-ish integer in [0, max_exclusive). Returns 0 for non-positive bounds.
func next_int(max_exclusive: int) -> int:
	if max_exclusive <= 0:
		return 0
	return next_u32() % max_exclusive


func next_range(min_inclusive: int, max_exclusive: int) -> int:
	if max_exclusive <= min_inclusive:
		return min_inclusive
	return min_inclusive + next_int(max_exclusive - min_inclusive)
