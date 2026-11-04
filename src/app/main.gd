extends Node3D
## M1 grey-box game shell: fixed-tick simulation driver + presentation layer.
##
## Responsibilities are deliberately split:
##   - simulation: src/core (pure, deterministic, tested headless)
##   - views:      src/render (read sim state, never write it)
##   - input:      src/input (device -> command dictionary)
##   - opponent:   src/ai (emits normal commands)
##   - HUD:        src/ui
##
## Debug/automation flags (user args after `--`):
##   --shot=<path>        fast-forward a seed and save a PNG, then quit
##   --shot-ticks=<n>     simulation ticks to run before the shot (default 480)
##   --seed=<n>           fixed arena/match seed

const Style = preload("res://src/render/arena_style.gd")
const ArenaView = preload("res://src/render/arena_view.gd")
const PlayerView = preload("res://src/render/player_view.gd")
const BombView = preload("res://src/render/bomb_view.gd")
const BlastView = preload("res://src/render/blast_view.gd")
const PickupView = preload("res://src/render/pickup_view.gd")
const CameraRig = preload("res://src/render/camera_rig.gd")
const Hud = preload("res://src/ui/hud.gd")
const InputRouter = preload("res://src/input/input_router.gd")
const SimpleAi = preload("res://src/ai/simple_ai.gd")

const MatchSim = preload("res://src/core/sim/match_sim.gd")
const SimEvent = preload("res://src/core/sim/sim_event.gd")
const Ruleset = preload("res://src/core/rules/ruleset.gd")
const ArenaLayout = preload("res://src/core/arena/arena_layout.gd")

const TICK_DT := 1.0 / 60.0
const PLAYER_COUNT := 2

enum Mode { ONE_PLAYER, TWO_PLAYER }

var sim
var rules
var arena
var seed_value: int = 4242

var _mode: int = Mode.ONE_PLAYER
var _paused: bool = false
var _accum: float = 0.0

var _arena_view
var _camera
var _entity_root: Node3D
var _hud

var _input_router
var _ai: Dictionary = {}

var _player_views: Dictionary = {}
var _bomb_views: Dictionary = {}
var _blast_views: Dictionary = {}
var _pickup_views: Dictionary = {}

var _shot_path: String = ""
var _shot_ticks: int = 480
var _shot_frames: int = 0
var _shot_done: bool = false
var _shot_frozen: bool = false


func _ready() -> void:
	_parse_args()
	_build_world()
	_input_router = InputRouter.new()
	_start_match()
	if not _shot_path.is_empty():
		_fast_forward_for_shot()


func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Style.COLOR_BG
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.38, 0.47, 0.62)
	environment.ambient_light_energy = 0.46
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.glow_enabled = true
	environment.glow_intensity = 0.65
	environment.glow_bloom = 0.10
	environment.ssao_enabled = true
	environment.ssao_intensity = 1.6
	world_env.environment = environment
	add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-57, -38, 0)
	key_light.light_color = Color(1.0, 0.94, 0.86)
	key_light.light_energy = 1.45
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 90.0
	add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.rotation_degrees = Vector3(-38, 142, 0)
	fill_light.light_color = Color(0.52, 0.68, 1.0)
	fill_light.light_energy = 0.35
	fill_light.shadow_enabled = false
	add_child(fill_light)

	_camera = CameraRig.new()
	_camera.name = "Camera"
	add_child(_camera)

	_arena_view = ArenaView.new()
	_arena_view.name = "Arena"
	add_child(_arena_view)

	_entity_root = Node3D.new()
	_entity_root.name = "Entities"
	add_child(_entity_root)

	_hud = Hud.new()
	_hud.name = "Hud"
	_hud.setup(PLAYER_COUNT)
	add_child(_hud)


func _start_match() -> void:
	_paused = false
	_accum = 0.0
	_player_views.clear()
	_bomb_views.clear()
	_blast_views.clear()
	_pickup_views.clear()
	for child in _entity_root.get_children():
		child.queue_free()
	_ai.clear()

	rules = Ruleset.new()
	arena = ArenaLayout.new()
	if not arena.generate(15, 13, seed_value, PLAYER_COUNT):
		push_error("arena generation failed: %s" % arena.last_error)
		return

	sim = MatchSim.new()
	sim.setup(rules, arena, seed_value, PLAYER_COUNT)
	sim.start()

	_arena_view.build(arena.grid)
	_camera.setup(Vector2i(arena.grid.width, arena.grid.height))

	for player in sim.players:
		var view = PlayerView.new()
		view.name = "Player%d" % player.id
		view.setup(player.id, Style.PLAYER_COLORS[player.id % Style.PLAYER_COLORS.size()])
		_entity_root.add_child(view)
		_player_views[player.id] = view

	if _mode == Mode.ONE_PLAYER or not _shot_path.is_empty():
		for i in PLAYER_COUNT:
			_ai[i] = SimpleAi.new(seed_value + 31 * (i + 1))

	_update_views(0.0)


func _physics_process(delta: float) -> void:
	if sim == null:
		return
	if _shot_path.is_empty():
		_poll_global_input()
	if _paused or _shot_frozen:
		return

	_accum += delta
	var steps := 0
	while _accum >= TICK_DT and steps < 4:
		_accum -= TICK_DT
		steps += 1
		_tick()


func _process(delta: float) -> void:
	if sim == null:
		return
	_update_views(delta)
	_maybe_capture_shot()


func _tick() -> void:
	var humans := PLAYER_COUNT if _mode == Mode.TWO_PLAYER and _shot_path.is_empty() else 1
	for i in humans:
		var command: Dictionary = _input_router.read_player(i)
		sim.submit_command(i, command["dir"], command["bomb"])

	for i in _ai:
		var command: Dictionary = _ai[i].think(sim, i)
		sim.submit_command(i, command["dir"], command["bomb"])

	sim.step()
	_handle_events(sim.take_events())


func _handle_events(events: Array) -> void:
	var crates_changed := false
	for event in events:
		match event.type:
			SimEvent.Type.BOMB_EXPLODED:
				_camera.kick(0.9)
			SimEvent.Type.PLAYER_HIT:
				_camera.kick(1.4)
			SimEvent.Type.CRATE_DESTROYED:
				crates_changed = true
	if crates_changed:
		_arena_view.refresh_crates(sim.grid)


func _update_views(delta: float) -> void:
	var size := Vector2i(arena.grid.width, arena.grid.height)

	for player in sim.players:
		var view = _player_views.get(player.id, null)
		if view != null:
			view.sync(player, size, delta)

	_sync_bombs(size, delta)
	_sync_blasts(size, delta)
	_sync_pickups(size, delta)

	if _hud != null:
		_hud.update_from_sim(sim, _mode_name(), _paused)


func _sync_bombs(size: Vector2i, delta: float) -> void:
	var live := {}
	for bomb in sim.bombs:
		live[bomb.id] = true
		var view = _bomb_views.get(bomb.id, null)
		if view == null:
			view = BombView.new()
			view.setup(bomb.id)
			_entity_root.add_child(view)
			_bomb_views[bomb.id] = view
		view.sync(bomb, size, delta, rules)

	for id in _bomb_views.keys():
		if not live.has(id):
			_bomb_views[id].queue_free()
			_bomb_views.erase(id)


func _sync_blasts(size: Vector2i, delta: float) -> void:
	var live := {}
	for tile in sim.blasts:
		live[tile] = true
		var view = _blast_views.get(tile, null)
		if view == null:
			view = BlastView.new()
			view.setup()
			view.position = Style.tile_to_world(tile, size, 0.0)
			_entity_root.add_child(view)
			_blast_views[tile] = view
		var cell = sim.blasts[tile]
		view.sync(sim.tick - cell.created_tick, rules.blast_ticks, delta)

	for tile in _blast_views.keys():
		if not live.has(tile):
			_blast_views[tile].queue_free()
			_blast_views.erase(tile)


func _sync_pickups(size: Vector2i, delta: float) -> void:
	var live := {}
	for pickup in sim.pickups:
		live[pickup.tile] = true
		var view = _pickup_views.get(pickup.tile, null)
		if view == null or view.pickup_type != pickup.type:
			if view != null:
				view.queue_free()
			view = PickupView.new()
			view.setup(pickup.type)
			view.position = Style.tile_to_world(pickup.tile, size, 0.0)
			_entity_root.add_child(view)
			_pickup_views[pickup.tile] = view
		view.sync(delta)

	for tile in _pickup_views.keys():
		if not live.has(tile):
			_pickup_views[tile].queue_free()
			_pickup_views.erase(tile)


func _poll_global_input() -> void:
	var globals: Dictionary = _input_router.poll_global()
	if globals["toggle_pause"]:
		_paused = not _paused
	if globals["restart"]:
		_start_match()
	elif globals["mode_1p"] and _mode != Mode.ONE_PLAYER:
		_mode = Mode.ONE_PLAYER
		_start_match()
	elif globals["mode_2p"] and _mode != Mode.TWO_PLAYER:
		_mode = Mode.TWO_PLAYER
		_start_match()


func _mode_name() -> String:
	return "1P vs CPU" if _mode == Mode.ONE_PLAYER else "2P LOCAL"


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-ticks="):
			_shot_ticks = int(arg.trim_prefix("--shot-ticks="))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))


func _fast_forward_for_shot() -> void:
	# Play the match with AI on both sides so the captured frame is real gameplay,
	# not a hand-placed diorama.
	for attempt in 4:
		for i in _shot_ticks:
			_shot_step()

		# Keep playing until fire is on screen, a bomb is still armed and both
		# fighters are alive, so the frame proves bombs, blasts and characters.
		var extra := 0
		while extra < 900 and sim.phase == MatchSim.Phase.PLAYING:
			if _shot_is_interesting():
				break
			_shot_step()
			extra += 1
		if _shot_is_interesting():
			break
		# Retries must not replay the identical deterministic match.
		seed_value += 1
		_start_match()

	_shot_frozen = true
	_update_views(0.0)
	print("shot state: tick=%d phase=%d bombs=%d blasts=%d pickups=%d eliminations=%d" % [
		sim.tick, sim.phase, sim.bombs.size(), sim.blasts.size(), sim.pickups.size(), sim.eliminations,
	])
	for player in sim.players:
		print("  player %d tile=%s alive=%s stats=%d/%d/%d kick=%s" % [
			player.id, str(player.tile), str(player.alive), player.capacity, player.blast_range,
			player.speed_level, str(player.has_kick),
		])


func _shot_is_interesting() -> bool:
	return not sim.blasts.is_empty() and not sim.bombs.is_empty() and sim.alive_count() >= 2


func _shot_step() -> void:
	for id in _ai:
		var command: Dictionary = _ai[id].think(sim, id)
		sim.submit_command(id, command["dir"], command["bomb"])
	sim.step()
	_handle_events(sim.take_events())


func _maybe_capture_shot() -> void:
	if _shot_path.is_empty() or _shot_done:
		return
	_shot_frames += 1
	if _shot_frames < 8:
		return
	_shot_done = true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	# unproject_position() is in design-space (1920x1080); scale it to the PNG.
	var visible := get_viewport().get_visible_rect().size
	var image_scale := Vector2(float(image.get_width()), float(image.get_height())) / visible
	for player in sim.players:
		var world := Style.position_to_world(player.visual_position(), Vector2i(arena.grid.width, arena.grid.height), 0.8)
		print("  on screen: player %d -> %s" % [player.id, str(_camera.unproject_position(world) * image_scale)])
	var err := image.save_png(_shot_path)
	print("shot saved: %s (err=%d, tick=%d, phase=%d)" % [_shot_path, err, sim.tick, sim.phase])
	get_tree().quit(0 if err == OK else 1)
