extends RefCounted
## Simple grey-box opponent. It reads the simulation through the same public state
## a human client sees and emits ordinary {dir, bomb} commands, so it is a normal
## participant — not a scripted override of match rules.
##
## Safety model: every decision is checked against a danger map that stores, per
## tile, the tick its bomb will detonate. Escaping uses a time-aware BFS: a route
## is only valid if the player reaches each tile before that tile burns, so the
## AI stops walking *along* its own blast lane (the M1 bug found in self-play).
## Planting is refused unless such a route exists after the new bomb is added.
##
## The BFS is bounded by the arena grid, so cost is negligible at 60 Hz.

const Dirs = preload("res://src/core/sim/dirs.gd")
const Grid = preload("res://src/core/sim/grid.gd")
const MatchSim = preload("res://src/core/sim/match_sim.gd")
const Rng = preload("res://src/core/sim/rng.gd")

const SAFETY_MARGIN_TICKS := 6
const MAX_ROUTE_NODES := 900
const PLANT_COOLDOWN_TICKS := 24
const SUDDEN_DEATH_PLANT_COOLDOWN := 40

var _rng
var _last_plant_tick: int = -1000


func _init(seed_value: int = 7) -> void:
	_rng = Rng.new(seed_value)


func think(sim, player_id: int) -> Dictionary:
	var idle := {"dir": Vector2i.ZERO, "bomb": false}
	if player_id < 0 or player_id >= sim.players.size():
		return idle
	var player = sim.players[player_id]
	if not player.alive:
		return idle
	if sim.phase != MatchSim.Phase.PLAYING and sim.phase != MatchSim.Phase.SUDDEN_DEATH:
		return idle

	var here: Vector2i = player.nearest_tile()
	# While crossing a tile, plan from the tile we will actually stand on.
	var from: Vector2i = player.move_to if player.moving else here
	var danger := _danger_map(sim)
	var travel := _travel_ticks(player)

	var in_danger: bool = danger.has(here)
	if player.moving and danger.has(player.move_to):
		in_danger = true
	if in_danger:
		# If the step already in flight ends outside the blast, just finish it.
		if not danger.has(from):
			return idle
		var route := _escape_route(sim, from, danger, travel)
		if route.size() >= 2:
			return {"dir": _dir_between(from, route[1]), "bomb": false}
		var fallback := _least_bad_step(sim, from, danger)
		if fallback != Vector2i.ZERO:
			return {"dir": fallback, "bomb": false}

	if _should_plant(sim, player, from, danger, travel):
		_last_plant_tick = sim.tick
		return {"dir": Vector2i.ZERO, "bomb": true}

	# If the tile we are walking into is a good firing position, stop buffering
	# movement so the current step ends there. Without this the AI always has a
	# queued direction and can never stand still long enough to plant.
	if player.moving and _can_plant_from(sim, player, from, danger, travel):
		return idle

	var objective := _find_crate_objective(sim, from, danger)
	if objective != Vector2i(-1, -1) and objective != from:
		var step := _first_step(sim, from, objective, danger)
		if step != Vector2i.ZERO:
			return {"dir": step, "bomb": false}

	# No crates to farm (or none reachable): close in on the nearest opponent so
	# the match can be decided instead of two bots circling empty corners.
	var chase := _find_enemy_objective(sim, from, player.id, danger)
	if chase != Vector2i(-1, -1) and chase != from:
		var chase_step := _first_step(sim, from, chase, danger)
		if chase_step != Vector2i.ZERO:
			return {"dir": chase_step, "bomb": false}

	# Nothing to farm: roam to a reachable safe tile so the AI never freezes in a
	# corner and always keeps the match moving.
	var roam := _random_reachable_safe(sim, from, danger)
	if roam != Vector2i(-1, -1) and roam != from:
		var step := _first_step(sim, from, roam, danger)
		if step != Vector2i.ZERO:
			return {"dir": step, "bomb": false}
	return idle


## --- planting -----------------------------------------------------------------

func _should_plant(sim, player, here: Vector2i, danger: Dictionary, travel: int) -> bool:
	if player.moving:
		return false
	return _can_plant_from(sim, player, here, danger, travel)


## Safety/usefulness test shared by "plant now" and "stop on this tile to plant".
func _can_plant_from(sim, player, here: Vector2i, danger: Dictionary, travel: int) -> bool:
	if danger.has(here):
		return false
	if sim.tick - _last_plant_tick < PLANT_COOLDOWN_TICKS:
		return false
	if _active_bombs(sim, player.id) >= player.capacity:
		return false
	if _bomb_at(sim, here) != null:
		return false
	if not _plant_is_useful(sim, player, here):
		return false

	# The new bomb is part of the world as soon as the command lands, so the
	# escape plan must be computed with it included.
	var hypothetical := _danger_with_bomb(sim, here, player.blast_range)
	var route := _escape_route(sim, here, hypothetical, travel)
	return route.size() >= 2


func _plant_is_useful(sim, player, here: Vector2i) -> bool:
	# 1. Farm: a crate next to us.
	for dir in Dirs.ALL:
		var tile: Vector2i = here + dir
		if sim.grid.get_tile(tile.x, tile.y) == Grid.Tile.CRATE:
			return true
	# 2. Attack: an opponent in a straight blast lane with nothing solid between.
	for dir in Dirs.ALL:
		for distance in range(1, player.blast_range + 1):
			var tile: Vector2i = here + dir * distance
			var kind: int = sim.grid.get_tile(tile.x, tile.y)
			if kind == Grid.Tile.WALL or kind == Grid.Tile.CRATE:
				break
			for other in sim.players:
				if other.id == player.id or not other.alive:
					continue
				if other.occupied_tiles().has(tile):
					return true
	# 3. Endgame: no crates left anywhere, keep pressure with bombs.
	return _crates_remaining(sim) == 0


func _crates_remaining(sim) -> int:
	var count := 0
	for y in sim.grid.height:
		for x in sim.grid.width:
			if sim.grid.get_tile(x, y) == Grid.Tile.CRATE:
				count += 1
	return count


func _active_bombs(sim, player_id: int) -> int:
	var total := 0
	for bomb in sim.bombs:
		if not bomb.exploded and bomb.owner_id == player_id:
			total += 1
	return total


func _bomb_at(sim, tile: Vector2i):
	for bomb in sim.bombs:
		if not bomb.exploded and bomb.tile == tile:
			return bomb
	return null


## --- danger maps --------------------------------------------------------------

## tile -> ticks until it burns (best approximation the AI needs to survive).
## Armed bombs and currently burning blast tiles are both lethal.
func _danger_map(sim) -> Dictionary:
	var danger := {}
	for tile in sim.blasts:
		var cell = sim.blasts[tile]
		var remaining: int = sim.rules.blast_ticks - (sim.tick - cell.created_tick)
		danger[tile] = mini(maxi(remaining, 1), int(danger.get(tile, 9999)))
	for bomb in sim.bombs:
		if bomb.exploded:
			continue
		_stamp_bomb(danger, sim, bomb.tile, bomb.blast_range, bomb.fuse)
	return danger


func _danger_with_bomb(sim, tile: Vector2i, blast_range: int) -> Dictionary:
	var danger := _danger_map(sim)
	_stamp_bomb(danger, sim, tile, blast_range, sim.rules.fuse_ticks)
	return danger


func _stamp_bomb(danger: Dictionary, sim, tile: Vector2i, blast_range: int, fuse: int) -> void:
	danger[tile] = mini(fuse, int(danger.get(tile, 9999)))
	for dir in Dirs.ALL:
		for distance in range(1, blast_range + 1):
			var cell: Vector2i = tile + dir * distance
			var kind: int = sim.grid.get_tile(cell.x, cell.y)
			if kind == Grid.Tile.WALL:
				break
			danger[cell] = mini(fuse, int(danger.get(cell, 9999)))
			if kind == Grid.Tile.CRATE:
				break
			if _bomb_at(sim, cell) != null:
				break


## --- escape planning ----------------------------------------------------------

## Returns the tile path [start, ..., safe_tile]. A step is legal only while the
## player arrives before that tile's blast tick (with a safety margin).
func _escape_route(sim, start: Vector2i, danger: Dictionary, travel: int) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not _walkable_tile(sim, start):
		return empty

	var queue: Array[Vector2i] = [start]
	var arrival := {start: 0}
	var parent := {}
	var visited := {start: true}
	var head := 0
	while head < queue.size() and head < MAX_ROUTE_NODES:
		var tile: Vector2i = queue[head]
		head += 1
		var at: int = arrival[tile]
		if tile != start and not danger.has(tile):
			var path: Array[Vector2i] = [tile]
			var cursor: Vector2i = tile
			while parent.has(cursor):
				cursor = parent[cursor]
				path.push_front(cursor)
			return path

		for dir in Dirs.ALL:
			var next: Vector2i = tile + dir
			if visited.has(next) or not _passable(sim, next):
				continue
			var eta: int = at + travel
			if danger.has(next) and eta + SAFETY_MARGIN_TICKS >= int(danger[next]):
				continue
			visited[next] = true
			parent[next] = tile
			arrival[next] = eta
			queue.append(next)
	return empty


func _least_bad_step(sim, start: Vector2i, danger: Dictionary) -> Vector2i:
	var best := Vector2i.ZERO
	var best_ttl := int(danger.get(start, 0))
	for dir in Dirs.ALL:
		var next: Vector2i = start + dir
		if not _passable(sim, next):
			continue
		var ttl := int(danger.get(next, 9999))
		if ttl > best_ttl:
			best_ttl = ttl
			best = dir
	return best


## --- navigation ---------------------------------------------------------------

## Nearest reachable safe tile that is adjacent to a crate.
func _find_crate_objective(sim, start: Vector2i, danger: Dictionary) -> Vector2i:
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var head := 0
	while head < queue.size() and head < MAX_ROUTE_NODES:
		var tile: Vector2i = queue[head]
		head += 1
		if tile != start and _touches_crate(sim, tile):
			return tile
		for dir in Dirs.ALL:
			var next: Vector2i = tile + dir
			if seen.has(next) or not _passable(sim, next) or danger.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return Vector2i(-1, -1)


func _touches_crate(sim, tile: Vector2i) -> bool:
	for dir in Dirs.ALL:
		var next: Vector2i = tile + dir
		if sim.grid.get_tile(next.x, next.y) == Grid.Tile.CRATE:
			return true
	return false


## Nearest reachable safe tile that touches a living opponent.
func _find_enemy_objective(sim, start: Vector2i, player_id: int, danger: Dictionary) -> Vector2i:
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var head := 0
	while head < queue.size() and head < MAX_ROUTE_NODES:
		var tile: Vector2i = queue[head]
		head += 1
		if tile != start and _touches_enemy(sim, tile, player_id):
			return tile
		for dir in Dirs.ALL:
			var next: Vector2i = tile + dir
			if seen.has(next) or not _passable(sim, next) or danger.has(next):
				continue
			seen[next] = true
			queue.append(next)
	return Vector2i(-1, -1)


func _touches_enemy(sim, tile: Vector2i, player_id: int) -> bool:
	for dir in Dirs.ALL:
		var next: Vector2i = tile + dir
		for other in sim.players:
			if other.id == player_id or not other.alive:
				continue
			if other.occupied_tiles().has(next):
				return true
	return false


## Any safe tile reachable right now; used as a roam target with a seeded pick.
func _random_reachable_safe(sim, start: Vector2i, danger: Dictionary) -> Vector2i:
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var safe: Array[Vector2i] = []
	var head := 0
	while head < queue.size() and head < MAX_ROUTE_NODES:
		var tile: Vector2i = queue[head]
		head += 1
		if tile != start and not danger.has(tile):
			safe.append(tile)
		for dir in Dirs.ALL:
			var next: Vector2i = tile + dir
			if seen.has(next) or not _passable(sim, next) or danger.has(next):
				continue
			seen[next] = true
			queue.append(next)
	if safe.is_empty():
		return Vector2i(-1, -1)
	return safe[_rng.next_range(0, safe.size() - 1)]


## BFS from `here` to `goal`, returning the first cardinal step. When
## `allow_danger` is false, blast tiles are avoided entirely.
func _first_step(sim, here: Vector2i, goal: Vector2i, danger: Dictionary, allow_danger: bool = false) -> Vector2i:
	if goal == Vector2i(-1, -1) or goal == here:
		return Vector2i.ZERO

	var queue: Array[Vector2i] = [here]
	var seen := {here: true}
	var first := {}
	var head := 0
	while head < queue.size() and head < MAX_ROUTE_NODES:
		var tile: Vector2i = queue[head]
		head += 1
		for dir in Dirs.ALL:
			var next: Vector2i = tile + dir
			if seen.has(next) or not _passable(sim, next):
				continue
			if not allow_danger and danger.has(next) and next != goal:
				continue
			seen[next] = true
			first[next] = dir if tile == here else first[tile]
			if next == goal:
				return first[next]
			queue.append(next)
	return Vector2i.ZERO


func _passable(sim, tile: Vector2i) -> bool:
	if not sim.grid.is_walkable(tile.x, tile.y):
		return false
	if _bomb_at(sim, tile) != null:
		return false
	return true


func _walkable_tile(sim, tile: Vector2i) -> bool:
	return sim.grid.is_walkable(tile.x, tile.y)


## --- small helpers ------------------------------------------------------------

func _travel_ticks(player) -> int:
	var speed: int = maxi(player.speed_fp, 1)
	return int(ceil(1024.0 / float(speed)))


func _dir_between(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta: Vector2i = to - from
	if absi(delta.x) + absi(delta.y) != 1:
		return Vector2i.ZERO
	return delta
