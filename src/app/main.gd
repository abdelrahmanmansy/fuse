extends Node3D
## M2 game shell: menu flow + fixed-tick match driver + presentation layer.
##
## Responsibilities are deliberately split:
##   - simulation: src/core (pure, deterministic, tested headless)
##   - views:      src/render (read sim state, never write it)
##   - input:      src/input (device -> command dictionary)
##   - opponent:   src/ai (emits normal commands)
##   - HUD/menus:  src/ui
##   - flow:       src/app/app_flow.gd (title -> match -> results -> series)
##
## Debug/automation flags (user args after `--`):
##   --shot=<path>        fast-forward a seed and save a PNG, then quit
##   --shot-ticks=<n>     simulation ticks to run before the shot (default 480)
##   --seed=<n>           fixed arena/match seed
##   --locale=<en|ar>     force a UI language for captures (not saved)
##   --hide=<layers>      hide arena layers for visual debugging, comma separated
##                        (floor,slab,walls,caps,crates)

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
const AppFlow = preload("res://src/app/app_flow.gd")
const Settings = preload("res://src/app/settings.gd")
const L10n = preload("res://src/app/l10n.gd")
const ThemeBuilder = preload("res://src/ui/theme_builder.gd")
const AudioDirector = preload("res://src/audio/audio_director.gd")
const TitleScreen = preload("res://src/ui/screens/title_screen.gd")
const PauseMenu = preload("res://src/ui/screens/pause_menu.gd")
const SeriesPanel = preload("res://src/ui/screens/series_panel.gd")
const SettingsScreen = preload("res://src/ui/screens/settings_screen.gd")

const MatchSim = preload("res://src/core/sim/match_sim.gd")
const SimEvent = preload("res://src/core/sim/sim_event.gd")
const Ruleset = preload("res://src/core/rules/ruleset.gd")
const ArenaLayout = preload("res://src/core/arena/arena_layout.gd")

const TICK_DT := 1.0 / 60.0
const PLAYER_COUNT := 2

var sim
var rules
var arena
var seed_value: int = 4242

var _flow
var _settings
var _paused: bool = false
var _accum: float = 0.0
var _round_recorded: bool = false

var _arena_view
var _camera
var _entity_root: Node3D
var _hud
var _title
var _pause_menu
var _series
var _settings_screen
var _audio

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

var _capture_path: String = ""
var _capture_screen: String = "title"
var _capture_after: int = 24
var _capture_frames: int = 0
var _capture_done: bool = false
var _forced_locale: String = ""
var _hidden_layers: Array[String] = []

const LAYER_NODES := {
	"floor": "Floor",
	"slab": "FloorSlab",
	"walls": "Walls",
	"caps": "WallCaps",
	"crates": "Crates",
}


func _ready() -> void:
	_parse_args()
	_settings = Settings.new()
	_settings.load_settings()
	if not _forced_locale.is_empty():
		_settings.locale = _forced_locale
	_flow = AppFlow.new()
	_flow.best_of = _settings.best_of
	_build_world()
	_input_router = InputRouter.new()
	_apply_settings()
	_apply_locale()

	if _shot_path.is_empty():
		if _capture_path.is_empty():
			_start_match()
			_show_title()
		else:
			_setup_capture()
	else:
		# A capture must be real gameplay, so skip menus and let the AI play both.
		_flow.begin_series(AppFlow.MODE_1P)
		_start_match()
		_fast_forward_for_shot()


func _build_world() -> void:
	# One theme for every Control: Noto Sans with an Arabic-capable fallback.
	get_window().theme = ThemeBuilder.build()

	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Style.COLOR_BG
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.40, 0.50, 0.64)
	environment.ambient_light_energy = 0.36
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
	key_light.light_color = Color(1.0, 0.96, 0.90)
	key_light.light_energy = 1.20
	key_light.shadow_enabled = true
	key_light.directional_shadow_max_distance = 90.0
	add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "FillLight"
	fill_light.rotation_degrees = Vector3(-38, 142, 0)
	fill_light.light_color = Color(0.52, 0.68, 1.0)
	fill_light.light_energy = 0.28
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

	_title = TitleScreen.new()
	_title.name = "TitleScreen"
	add_child(_title)
	_title.mode_selected.connect(_on_mode_selected)
	_title.settings_requested.connect(_open_settings)
	_title.quit_requested.connect(_on_quit)

	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(func() -> void: _set_paused(false))
	_pause_menu.restart_requested.connect(_on_restart_round)
	_pause_menu.quit_requested.connect(_to_title)

	_series = SeriesPanel.new()
	_series.name = "SeriesPanel"
	add_child(_series)
	_series.advance_requested.connect(_on_series_advance)
	_series.change_mode_requested.connect(_to_title)
	_series.quit_requested.connect(_on_quit)

	_settings_screen = SettingsScreen.new()
	_settings_screen.name = "SettingsScreen"
	add_child(_settings_screen)
	_settings_screen.values_changed.connect(_on_settings_changed)
	_settings_screen.closed.connect(_on_settings_closed)

	_audio = AudioDirector.new()
	_audio.name = "Audio"
	add_child(_audio)
	# Captures must stay silent and deterministic; headless runs have no audio
	# device and playing would leave a dangling playback at exit.
	_audio.muted = not _shot_path.is_empty() or DisplayServer.get_name() == "headless"


func _start_match() -> void:
	_paused = false
	_pause_menu.close()
	_series.close()
	_round_recorded = false
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
	if not arena.generate(rules.arena_width, rules.arena_height, seed_value, PLAYER_COUNT,
			rules.crate_density_percent):
		push_error("arena generation failed: %s" % arena.last_error)
		return

	sim = MatchSim.new()
	sim.setup(rules, arena, seed_value, PLAYER_COUNT)
	sim.start()

	_arena_view.build(arena.grid)
	for key in _hidden_layers:
		var node: Node = _arena_view.get_node_or_null(String(LAYER_NODES.get(key, "")))
		if node != null:
			node.visible = false
	_camera.setup(Vector2i(arena.grid.width, arena.grid.height))

	for player in sim.players:
		var view = PlayerView.new()
		view.name = "Player%d" % player.id
		view.setup(player.id, Style.PLAYER_COLORS[player.id % Style.PLAYER_COLORS.size()])
		_entity_root.add_child(view)
		_player_views[player.id] = view

	_ensure_ai()
	_hud.visible = _flow.screen == AppFlow.Screen.MATCH
	# A key still held from the menu (menu confirm) must not count as a fresh
	# gameplay press on the first tick of the round.
	if _input_router != null:
		_input_router.reset()
	_update_views(0.0)


## AI participants depend on what is on screen: attract demo and shot mode play
## themselves, 1P uses a CPU opponent, 2P is two humans.
func _ensure_ai() -> void:
	if not _shot_path.is_empty() or _flow.screen == AppFlow.Screen.TITLE:
		for i in PLAYER_COUNT:
			_ai[i] = SimpleAi.new(seed_value + 31 * (i + 1))
	elif _flow.mode == AppFlow.MODE_1P:
		_ai[1] = SimpleAi.new(seed_value + 62)


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
	if _hud.visible:
		_hud.update_from_sim(sim, _mode_name())
	_maybe_capture_shot()
	_maybe_capture_frame()


func _tick() -> void:
	var humans := 0
	if _flow.screen == AppFlow.Screen.MATCH and _shot_path.is_empty():
		humans = PLAYER_COUNT if _flow.mode == AppFlow.MODE_2P else 1
	for i in humans:
		var command: Dictionary = _input_router.read_player(i)
		sim.submit_command(i, command["dir"], command["bomb"])

	for i in _ai:
		var command: Dictionary = _ai[i].think(sim, i)
		sim.submit_command(i, command["dir"], command["bomb"])

	sim.step()
	_handle_events(sim.take_events())

	# The title screen runs an endless attract match so the backdrop is always live.
	if _flow.screen == AppFlow.Screen.TITLE and sim.phase == MatchSim.Phase.IDLE:
		_start_match()


func _handle_events(events: Array) -> void:
	if _audio != null:
		_audio.handle_events(events)
	var crates_changed := false
	for event in events:
		match event.type:
			SimEvent.Type.BOMB_EXPLODED:
				_camera.kick(0.9)
			SimEvent.Type.PLAYER_HIT:
				_camera.kick(1.4)
			SimEvent.Type.CRATE_DESTROYED:
				crates_changed = true
			SimEvent.Type.MATCH_ENDED:
				if _flow.screen == AppFlow.Screen.MATCH and _shot_path.is_empty():
					_finish_round(int(event.data.winner_id))
	if crates_changed:
		_arena_view.refresh_crates(sim.grid)


# --- menu flow ----------------------------------------------------------------

func _show_title() -> void:
	_title.open()
	_hud.visible = false


func _on_mode_selected(mode: int) -> void:
	_flow.begin_series(mode)
	_title.close()
	_start_match()


func _on_series_advance() -> void:
	if _flow.series_over:
		_flow.begin_series(_flow.mode)
	else:
		_flow.next_round()
	_start_match()


# --- settings -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# ESC should back out of the settings screen without needing to find BACK.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE and _settings_screen != null and _settings_screen.visible:
			_on_settings_closed()
			get_viewport().set_input_as_handled()
			return

	# Latch real presses for gameplay so taps between ticks are never dropped.
	if _input_router != null and _flow != null and _flow.screen == AppFlow.Screen.MATCH:
		_input_router.handle_event(event)


func _notification(what: int) -> void:
	# Alt-tabbing must not leave keys stuck or bank a frame burst on return.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _input_router != null:
			Input.flush_buffered_events()
			_input_router.suspend()
		_accum = 0.0
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _input_router != null:
			_input_router.resume()
		_accum = 0.0


func _open_settings() -> void:
	_title.close()
	_settings_screen.open_with(_settings)


func _on_settings_closed() -> void:
	_settings_screen.close()
	_settings.save_settings()
	_show_title()


func _on_settings_changed() -> void:
	# Live-apply so volume/fullscreen/language feedback is immediate; persist on close.
	_settings.save_settings()
	_apply_settings()
	_apply_locale()


func _apply_settings() -> void:
	if _settings == null:
		return
	if _flow != null:
		_flow.best_of = _settings.best_of
	if _audio != null:
		_audio.master = clampf(_settings.master_volume * _settings.sfx_volume, 0.0, 1.0)
	# Headless runs have no display server; only touch the window when one exists.
	if DisplayServer.get_name() != "headless":
		var want_fullscreen: bool = _settings.fullscreen
		var is_fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if want_fullscreen != is_fullscreen:
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if want_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_locale() -> void:
	L10n.set_locale(_settings.locale if _settings != null else "en")
	var rtl := L10n.is_rtl()
	for screen in [_title, _pause_menu, _series, _settings_screen]:
		if screen != null:
			screen.set_rtl(rtl)
			screen.retranslate()
	if _hud != null:
		_hud.set_rtl(rtl)
		_hud.retranslate()


func _on_restart_round() -> void:
	_start_match()


func _to_title() -> void:
	_flow.back_to_title()
	_start_match()
	_show_title()


func _on_quit() -> void:
	get_tree().quit()


func _finish_round(winner_id: int) -> void:
	if _round_recorded:
		return
	_round_recorded = true
	_flow.record_round(winner_id)
	_camera.kick(1.5)
	_hud.visible = false
	_series.open_with(_flow)


func _set_paused(on: bool) -> void:
	if _flow.screen != AppFlow.Screen.MATCH:
		return
	_paused = on
	# Never resume by replaying the frames spent in the menu, and never let a
	# press queued while paused fire as soon as play resumes.
	_accum = 0.0
	if _input_router != null:
		_input_router.clear_latches()
	_hud.visible = not on
	if on:
		_pause_menu.open()
	else:
		_pause_menu.close()


func _poll_global_input() -> void:
	if _shot_path != "":
		return
	if _flow.screen != AppFlow.Screen.MATCH:
		return

	var globals: Dictionary = _input_router.poll_global()
	if globals["toggle_pause"]:
		_set_paused(not _paused)
		return
	if _paused:
		return

	if globals["restart"]:
		_start_match()
	elif globals["mode_1p"] and _flow.mode != AppFlow.MODE_1P:
		_on_mode_selected(AppFlow.MODE_1P)
	elif globals["mode_2p"] and _flow.mode != AppFlow.MODE_2P:
		_on_mode_selected(AppFlow.MODE_2P)


func _update_views(delta: float) -> void:
	var size := Vector2i(arena.grid.width, arena.grid.height)

	for player in sim.players:
		var view = _player_views.get(player.id, null)
		if view != null:
			view.sync(player, size, delta)

	_sync_bombs(size, delta)
	_sync_blasts(size, delta)
	_sync_pickups(size, delta)


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


func _mode_name() -> String:
	return L10n.t("mode.1p") if _flow.mode == AppFlow.MODE_1P else L10n.t("mode.2p")


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot-ticks="):
			_shot_ticks = int(arg.trim_prefix("--shot-ticks="))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--capture="):
			_capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-screen="):
			_capture_screen = arg.trim_prefix("--capture-screen=")
		elif arg.begins_with("--capture-after="):
			_capture_after = int(arg.trim_prefix("--capture-after="))
		elif arg.begins_with("--locale="):
			var code := arg.trim_prefix("--locale=")
			if code == "ar" or code == "en":
				_forced_locale = code
		elif arg.begins_with("--hide="):
			for token in arg.trim_prefix("--hide=").split(",", false):
				_hidden_layers.append(token.strip_edges())


## Debug-only: bring a specific menu on screen so it can be captured for review.
func _setup_capture() -> void:
	match _capture_screen:
		"pause":
			_flow.begin_series(AppFlow.MODE_1P)
			_start_match()
			_set_paused(true)
		"series":
			_flow.begin_series(AppFlow.MODE_1P)
			_start_match()
			_flow.record_round(0)
			_hud.visible = false
			_series.open_with(_flow)
		"settings":
			_start_match()
			_hud.visible = false
			_settings_screen.open_with(_settings)
		_:
			_start_match()
			_show_title()


func _maybe_capture_frame() -> void:
	if _capture_path.is_empty() or _capture_done:
		return
	_capture_frames += 1
	if _capture_frames < _capture_after:
		return
	_capture_done = true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var err := image.save_png(_capture_path)
	print("capture saved: %s (err=%d, screen=%s)" % [_capture_path, err, _capture_screen])
	get_tree().quit(0 if err == OK else 1)


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
