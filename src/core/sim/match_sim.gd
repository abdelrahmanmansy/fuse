extends RefCounted
## Authoritative, deterministic match simulation.
##
## Contract:
## - advances only via step(); never reads the clock, input devices or nodes
## - all durations are integer ticks, all positions are fixed-point (1024 = 1 tile)
## - identical setup + identical commands => identical state_hash()
## - outcomes are emitted as ordered SimEvents; nothing here knows about rendering
##
## Used by local play, adventure, tests, and (from M5) the headless server.

const Ruleset = preload("res://src/core/rules/ruleset.gd")
const ArenaLayout = preload("res://src/core/arena/arena_layout.gd")
const Rng = preload("res://src/core/sim/rng.gd")
const PlayerSim = preload("res://src/core/sim/player_sim.gd")
const BombSim = preload("res://src/core/sim/bomb_sim.gd")
const BlastCell = preload("res://src/core/sim/blast_cell.gd")
const Pickup = preload("res://src/core/sim/pickup.gd")
const SimEvent = preload("res://src/core/sim/sim_event.gd")
const Dirs = preload("res://src/core/sim/dirs.gd")
const Grid = preload("res://src/core/sim/grid.gd")

enum Phase { IDLE, COUNTDOWN, PLAYING, SUDDEN_DEATH, RESULTS }
enum PickupType { CAPACITY, RANGE, SPEED, KICK }

const FIXED_ONE := 1024
const EMPTY_COMMAND := {"dir": Vector2i.ZERO, "bomb": false}

var rules
var arena
var grid
var rng

var tick: int = 0
var phase: int = Phase.IDLE
var phase_ticks_left: int = 0
var match_ticks_left: int = 0
var winner_id: int = -1
var eliminations: int = 0

var players: Array = []
var bombs: Array = []
var blasts: Dictionary = {}        # Vector2i -> BlastCell
var pickups: Array = []
var events: Array = []

var _bombs_by_tile: Dictionary = {}
var _pickups_by_tile: Dictionary = {}
var _commands: Dictionary = {}
var _next_bomb_id: int = 1
var _sudden_counter: int = 0


func setup(ruleset, layout, seed_value: int, player_count: int) -> void:
	rules = ruleset
	arena = layout
	grid = arena.grid
	rng = Rng.new(seed_value)

	players.clear()
	bombs.clear()
	blasts.clear()
	pickups.clear()
	events.clear()
	_bombs_by_tile.clear()
	_pickups_by_tile.clear()
	_commands.clear()

	tick = 0
	phase = Phase.IDLE
	phase_ticks_left = 0
	match_ticks_left = 0
	winner_id = -1
	eliminations = 0
	_next_bomb_id = 1
	_sudden_counter = 0

	var count: int = mini(player_count, arena.spawns.size())
	for i in count:
		var player = PlayerSim.new()
		player.id = i
		player.reset_for_round(arena.spawn_for(i), rules)
		players.append(player)


func start() -> void:
	if players.size() < 1:
		push_error("MatchSim.start() called without players")
		return
	phase = Phase.COUNTDOWN
	phase_ticks_left = rules.countdown_ticks
	_emit(SimEvent.Type.PHASE_CHANGED, {"phase": phase})


## Queue one player's intent for the next step(). Last write per tick wins.
func submit_command(player_id: int, dir: Vector2i, bomb: bool) -> void:
	if not Dirs.is_zero(dir) and not Dirs.is_cardinal(dir):
		return
	_commands[player_id] = {"dir": dir, "bomb": bomb}


func alive_count() -> int:
	var total := 0
	for player in players:
		if player.alive:
			total += 1
	return total


func step() -> void:
	tick += 1
	if phase == Phase.COUNTDOWN:
		_buffer_countdown_bombs()
		phase_ticks_left -= 1
		if phase_ticks_left <= 0:
			_enter_playing()
	elif phase == Phase.PLAYING or phase == Phase.SUDDEN_DEATH:
		_step_active()
	elif phase == Phase.RESULTS:
		phase_ticks_left -= 1
		# Let the final explosion fade instead of freezing mid-burn during the
		# results screen; damage is already over because _step_active is not run.
		_tick_blasts()
		if phase_ticks_left <= 0:
			phase = Phase.IDLE
			_emit(SimEvent.Type.PHASE_CHANGED, {"phase": phase})
	_commands.clear()


func take_events() -> Array:
	var drained := events
	events = []
	return drained


func _enter_playing() -> void:
	phase = Phase.PLAYING
	match_ticks_left = rules.match_ticks
	for player in players:
		if player.alive:
			player.spawn_guard = rules.spawn_guard_ticks
	_emit(SimEvent.Type.PHASE_CHANGED, {"phase": phase})


## A bomb pressed during READY stays queued until GO instead of being dropped.
## Direction is re-read every tick anyway, so only the edge-triggered bomb needs this.
func _buffer_countdown_bombs() -> void:
	for player in players:
		if not player.alive:
			continue
		var command: Dictionary = _commands.get(player.id, EMPTY_COMMAND)
		if command["bomb"]:
			player.bomb_buffer = maxi(player.bomb_buffer, rules.bomb_buffer_ticks)


func _step_active() -> void:
	for player in players:
		if not player.alive:
			continue
		var command: Dictionary = _commands.get(player.id, EMPTY_COMMAND)
		_move_player(player, command["dir"])
		if player.spawn_guard > 0:
			player.spawn_guard -= 1
		if command["bomb"]:
			player.bomb_buffer = maxi(player.bomb_buffer, rules.bomb_buffer_ticks)
		if player.bomb_buffer > 0:
			if _try_place_bomb(player):
				player.bomb_buffer = 0
			else:
				player.bomb_buffer -= 1
		_collect_pickups(player)

	_update_bombs()
	_resolve_explosions()
	_apply_blast_damage()
	_tick_blasts()
	_update_match_timer()
	_sudden_death_tick()
	_check_match_end()


## --- movement -----------------------------------------------------------------

func _move_player(player, want: Vector2i) -> void:
	# Pressing the opposite direction reverses the step in place instead of
	# waiting for the tile boundary. This is the single biggest feel win: the
	# character reacts on the tick you press, not up to 16 ticks later.
	if player.moving and not Dirs.is_zero(want):
		var travel: Vector2i = _move_direction(player)
		if want == Vector2i(-travel.x, -travel.y) and _can_reverse(player):
			_reverse_move(player, want)

	# A zero direction means "no input": drop any buffered intent so releasing a
	# key stops the player at the next tile boundary instead of chaining on.
	if Dirs.is_zero(want):
		player.buffered_dir = Vector2i.ZERO
	else:
		player.buffered_dir = want

	if not player.moving:
		var next_dir: Vector2i = player.buffered_dir
		player.buffered_dir = Vector2i.ZERO
		if not Dirs.is_zero(next_dir):
			_start_move(player, next_dir)

	if not player.moving:
		return

	player.move_progress += player.speed_fp
	var guard := 0
	while player.moving and player.move_progress >= FIXED_ONE and guard < 4:
		guard += 1
		# Carry the remainder so chained tiles keep the exact configured speed.
		var leftover: int = mini(player.move_progress - FIXED_ONE, FIXED_ONE - 1)
		player.tile = player.move_to
		player.moving = false
		player.move_progress = 0

		var next_dir: Vector2i = player.buffered_dir
		player.buffered_dir = Vector2i.ZERO
		if not Dirs.is_zero(next_dir) and _start_move(player, next_dir):
			player.move_progress = leftover
		else:
			break


func _move_direction(player) -> Vector2i:
	return player.move_to - player.move_from


## Reversing must not walk back into a bomb or through a wall that appeared.
func _can_reverse(player) -> bool:
	var target: Vector2i = player.move_from
	if not grid.is_walkable(target.x, target.y):
		return false
	return not _bombs_by_tile.has(target)


## Swap the step's endpoints and mirror the progress, so the visible position is
## unchanged on the reversal tick and the walk continues the other way.
func _reverse_move(player, want: Vector2i) -> void:
	var forward: Vector2i = _move_direction(player)
	player.tile = player.move_to
	player.move_from = player.move_to
	player.move_to = player.tile - forward
	player.move_progress = FIXED_ONE - player.move_progress
	player.facing = want
	player.buffered_dir = want


func _start_move(player, dir: Vector2i) -> bool:
	if Dirs.is_zero(dir):
		return false
	var target: Vector2i = player.tile + dir
	if not grid.is_walkable(target.x, target.y):
		return false

	var bomb = _bombs_by_tile.get(target, null)
	if bomb != null:
		if not player.has_kick or bomb.sliding:
			return false
		if not _kick_bomb(bomb, dir):
			return false
		# The bomb vacated the target tile, so the walk may continue this tick.

	player.facing = dir
	player.move_from = player.tile
	player.move_to = target
	player.move_progress = 0
	player.moving = true
	return true


## --- bombs --------------------------------------------------------------------

func _try_place_bomb(player) -> bool:
	var tile: Vector2i = player.nearest_tile()
	if _bombs_by_tile.has(tile):
		return false
	if _active_bombs(player.id) >= player.capacity:
		return false
	var bomb = _spawn_bomb(player.id, tile, rules.fuse_ticks, player.blast_range)
	_emit(SimEvent.Type.BOMB_PLACED, {"bomb_id": bomb.id, "tile": tile, "owner": player.id})
	return true


## Public spawner for adventure scripts and tests. Returns null if blocked.
func place_bomb_at(tile: Vector2i, owner_id: int = -1, fuse_ticks: int = -1, blast_range: int = -1):
	if not grid.is_walkable(tile.x, tile.y) or _bombs_by_tile.has(tile):
		return null
	var fuse: int = fuse_ticks if fuse_ticks > 0 else rules.fuse_ticks
	var reach: int = blast_range if blast_range > 0 else rules.start_range
	var bomb = _spawn_bomb(owner_id, tile, fuse, reach)
	_emit(SimEvent.Type.BOMB_PLACED, {"bomb_id": bomb.id, "tile": tile, "owner": owner_id})
	return bomb


func _spawn_bomb(owner_id: int, tile: Vector2i, fuse: int, blast_range: int):
	var bomb = BombSim.new()
	bomb.id = _next_bomb_id
	_next_bomb_id += 1
	bomb.owner_id = owner_id
	bomb.tile = tile
	bomb.fuse = fuse
	bomb.blast_range = blast_range
	bombs.append(bomb)
	_bombs_by_tile[tile] = bomb
	return bomb


func _active_bombs(owner_id: int) -> int:
	var total := 0
	for bomb in bombs:
		if not bomb.exploded and bomb.owner_id == owner_id:
			total += 1
	return total


func _kick_bomb(bomb, dir: Vector2i) -> bool:
	var target: Vector2i = bomb.tile + dir
	if not _bomb_can_occupy(target):
		return false
	_bombs_by_tile.erase(bomb.tile)
	bomb.slide_from = bomb.tile
	bomb.slide_to = target
	bomb.slide_dir = dir
	bomb.slide_progress = 0
	bomb.sliding = true
	bomb.tile = target
	_bombs_by_tile[target] = bomb
	_emit(SimEvent.Type.BOMB_KICKED, {
		"bomb_id": bomb.id, "from": bomb.slide_from, "to": target,
	})
	return true


func _advance_slide(bomb) -> void:
	if not bomb.sliding:
		return
	bomb.slide_progress += BombSim.SLIDE_FP_PER_TICK
	var guard := 0
	while bomb.sliding and bomb.slide_progress >= FIXED_ONE and guard < 4:
		guard += 1
		var carry: int = bomb.slide_progress - FIXED_ONE
		bomb.sliding = false
		bomb.slide_progress = 0

		var next: Vector2i = bomb.tile + bomb.slide_dir
		if not _bomb_can_occupy(next):
			break
		_bombs_by_tile.erase(bomb.tile)
		bomb.slide_from = bomb.tile
		bomb.slide_to = next
		bomb.tile = next
		bomb.sliding = true
		bomb.slide_progress = carry
		_bombs_by_tile[next] = bomb


func _bomb_can_occupy(tile: Vector2i) -> bool:
	if not grid.is_walkable(tile.x, tile.y):
		return false
	return not _bombs_by_tile.has(tile)


func _update_bombs() -> void:
	for bomb in bombs:
		if bomb.exploded:
			continue
		if bomb.sliding:
			_advance_slide(bomb)
		bomb.fuse -= 1


## --- explosions ---------------------------------------------------------------

func _resolve_explosions() -> void:
	var queue: Array = []
	for bomb in bombs:
		if not bomb.exploded and bomb.fuse <= 0:
			queue.append(bomb)

	var guard := 0
	while not queue.is_empty() and guard < 64:
		guard += 1
		var bomb = queue.pop_front()
		if bomb.exploded:
			continue
		bomb.exploded = true
		_bombs_by_tile.erase(bomb.tile)
		_emit(SimEvent.Type.BOMB_EXPLODED, {
			"bomb_id": bomb.id, "tile": bomb.tile, "owner": bomb.owner_id,
		})
		_add_blast(bomb.tile, bomb.owner_id)

		for dir in Dirs.ALL:
			for distance in range(1, bomb.blast_range + 1):
				var cell: Vector2i = bomb.tile + dir * distance
				var kind: int = grid.get_tile(cell.x, cell.y)
				if kind == Grid.Tile.WALL:
					break
				_add_blast(cell, bomb.owner_id)
				if kind == Grid.Tile.CRATE:
					_destroy_crate(cell)
					break
				var other = _bombs_by_tile.get(cell, null)
				if other != null:
					other.fuse = 0
					queue.append(other)
					break

	var remaining: Array = []
	for bomb in bombs:
		if not bomb.exploded:
			remaining.append(bomb)
	bombs = remaining


func _add_blast(tile: Vector2i, owner_id: int) -> void:
	if blasts.has(tile):
		return
	var cell = BlastCell.new()
	cell.tile = tile
	cell.owner_id = owner_id
	cell.created_tick = tick
	blasts[tile] = cell
	_emit(SimEvent.Type.BLAST_SPAWNED, {"tile": tile, "owner": owner_id})
	# Anything already lying on the floor burns before a crate can drop loot here.
	_destroy_pickup_at(tile)


func _tick_blasts() -> void:
	var expired: Array = []
	for tile in blasts:
		if tick - blasts[tile].created_tick >= rules.blast_ticks:
			expired.append(tile)
	for tile in expired:
		blasts.erase(tile)


## --- crates and pickups -------------------------------------------------------

func _destroy_crate(tile: Vector2i) -> void:
	grid.set_tile(tile.x, tile.y, Grid.Tile.FLOOR)
	_emit(SimEvent.Type.CRATE_DESTROYED, {"tile": tile})
	if rng.next_int(100) < rules.drop_chance_percent:
		spawn_pickup(tile, _roll_pickup_type())


func spawn_pickup(tile: Vector2i, type: int):
	if not grid.is_walkable(tile.x, tile.y):
		return null
	if _pickups_by_tile.has(tile):
		return null
	var pickup = Pickup.new()
	pickup.tile = tile
	pickup.type = type
	pickup.spawn_tick = tick
	pickups.append(pickup)
	_pickups_by_tile[tile] = pickup
	_emit(SimEvent.Type.PICKUP_SPAWNED, {"tile": tile, "type": type})
	return pickup


func _roll_pickup_type() -> int:
	var roll: int = rng.next_int(100)
	if roll < 30:
		return PickupType.CAPACITY
	if roll < 60:
		return PickupType.RANGE
	if roll < 85:
		return PickupType.SPEED
	return PickupType.KICK


func _collect_pickups(player) -> void:
	var tile: Vector2i = player.nearest_tile()
	var pickup = _pickups_by_tile.get(tile, null)
	if pickup == null:
		return
	pickups.erase(pickup)
	_pickups_by_tile.erase(tile)
	var changed := _apply_pickup(player, pickup.type)
	_emit(SimEvent.Type.PICKUP_COLLECTED, {
		"player": player.id, "type": pickup.type, "tile": tile, "applied": changed,
	})


func _apply_pickup(player, type: int) -> bool:
	match type:
		PickupType.CAPACITY:
			if player.capacity >= rules.max_capacity:
				return false
			player.capacity += 1
		PickupType.RANGE:
			if player.blast_range >= rules.max_range:
				return false
			player.blast_range += 1
		PickupType.SPEED:
			if player.speed_level >= rules.max_speed_level:
				return false
			player.speed_level += 1
			player.speed_fp = rules.speed_fp_for_level(player.speed_level)
		PickupType.KICK:
			if player.has_kick:
				return false
			player.has_kick = true
		_:
			return false
	return true


func _destroy_pickup_at(tile: Vector2i) -> void:
	var pickup = _pickups_by_tile.get(tile, null)
	if pickup == null:
		return
	pickups.erase(pickup)
	_pickups_by_tile.erase(tile)
	_emit(SimEvent.Type.PICKUP_DESTROYED, {"tile": tile, "type": pickup.type})


## --- damage, timer, sudden death ----------------------------------------------

func _apply_blast_damage() -> void:
	for player in players:
		if not player.alive or player.spawn_guard > 0:
			continue
		for tile in player.occupied_tiles():
			if blasts.has(tile):
				player.alive = false
				eliminations += 1
				_emit(SimEvent.Type.PLAYER_HIT, {"player": player.id, "tile": tile})
				_emit(SimEvent.Type.PLAYER_ELIMINATED, {"player": player.id, "tile": tile})
				break


func _update_match_timer() -> void:
	if phase != Phase.PLAYING:
		return
	match_ticks_left -= 1
	if match_ticks_left > 0:
		return
	phase = Phase.SUDDEN_DEATH
	_sudden_counter = rules.sudden_death_interval_ticks
	_emit(SimEvent.Type.PHASE_CHANGED, {"phase": phase})


func _sudden_death_tick() -> void:
	if phase != Phase.SUDDEN_DEATH:
		return
	_sudden_counter -= 1
	if _sudden_counter > 0:
		return
	_sudden_counter = rules.sudden_death_interval_ticks
	_drop_sudden_death_bomb()


func _drop_sudden_death_bomb() -> void:
	for attempt in range(50):
		var x: int = rng.next_int(grid.width)
		var y: int = rng.next_int(grid.height)
		var tile := Vector2i(x, y)
		if not grid.is_walkable(x, y) or _bombs_by_tile.has(tile):
			continue
		var bomb = _spawn_bomb(-1, tile, rules.sudden_death_fuse_ticks, rules.start_range)
		_emit(SimEvent.Type.SUDDEN_DEATH_BOMB, {"bomb_id": bomb.id, "tile": tile})
		return


func _check_match_end() -> void:
	if phase != Phase.PLAYING and phase != Phase.SUDDEN_DEATH:
		return
	if eliminations == 0:
		return
	var alive := alive_count()
	if alive > 1:
		return

	winner_id = -1
	if alive == 1:
		for player in players:
			if player.alive:
				winner_id = player.id
				break
	phase = Phase.RESULTS
	phase_ticks_left = rules.results_ticks
	_emit(SimEvent.Type.MATCH_ENDED, {"winner_id": winner_id})
	_emit(SimEvent.Type.PHASE_CHANGED, {"phase": phase})


## --- deterministic state hash -------------------------------------------------

## 32-bit FNV-1a over every value that can affect future ticks. Used by golden
## tests and (later) desync detection. Never include floats or wall-clock time.
func state_hash() -> int:
	var h := 2166136261
	h = _mix(h, tick)
	h = _mix(h, phase)
	h = _mix(h, phase_ticks_left)
	h = _mix(h, match_ticks_left)
	h = _mix(h, winner_id)
	h = _mix(h, eliminations)
	h = _mix(h, rng.state)
	h = _mix(h, _sudden_counter)

	for y in grid.height:
		for x in grid.width:
			var tile := Vector2i(x, y)
			h = _mix(h, grid.get_tile(x, y))
			var blast = blasts.get(tile, null)
			h = _mix(h, blast.created_tick if blast != null else -1)
			var pickup = _pickups_by_tile.get(tile, null)
			h = _mix(h, pickup.type if pickup != null else -1)

	for player in players:
		h = _mix(h, player.id)
		h = _mix(h, player.tile.x)
		h = _mix(h, player.tile.y)
		h = _mix(h, player.move_from.x)
		h = _mix(h, player.move_from.y)
		h = _mix(h, player.move_to.x)
		h = _mix(h, player.move_to.y)
		h = _mix(h, player.move_progress)
		h = _mix(h, 1 if player.moving else 0)
		h = _mix(h, player.facing.x)
		h = _mix(h, player.facing.y)
		h = _mix(h, player.buffered_dir.x)
		h = _mix(h, player.buffered_dir.y)
		h = _mix(h, player.speed_level)
		h = _mix(h, player.capacity)
		h = _mix(h, player.blast_range)
		h = _mix(h, 1 if player.has_kick else 0)
		h = _mix(h, player.bomb_buffer)
		h = _mix(h, 1 if player.alive else 0)
		h = _mix(h, player.spawn_guard)

	for bomb in bombs:
		h = _mix(h, bomb.id)
		h = _mix(h, bomb.owner_id)
		h = _mix(h, bomb.tile.x)
		h = _mix(h, bomb.tile.y)
		h = _mix(h, bomb.fuse)
		h = _mix(h, bomb.blast_range)
		h = _mix(h, 1 if bomb.sliding else 0)
		h = _mix(h, bomb.slide_progress)

	return h & 0xFFFFFFFF


func _mix(h: int, value: int) -> int:
	return ((h ^ (value & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF


func _emit(type: int, data: Dictionary) -> void:
	events.append(SimEvent.new(type, tick, data))



