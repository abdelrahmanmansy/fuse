extends RefCounted
## A collectible on the floor. `type` uses MatchSim.PickupType to avoid a
## circular dependency between the entity and the simulation.

var tile: Vector2i = Vector2i.ZERO
var type: int = 0
var spawn_tick: int = 0
