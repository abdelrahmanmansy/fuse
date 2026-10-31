extends RefCounted
## One burning cell of an explosion. Lifetime is measured from the tick it was
## created, so a blast is present for exactly `blast_ticks` simulation ticks.

var tile: Vector2i = Vector2i.ZERO
var owner_id: int = -1
var created_tick: int = 0
