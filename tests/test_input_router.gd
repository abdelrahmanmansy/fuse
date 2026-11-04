extends "res://tests/case.gd"
## Input-path tests: real key events are latched and consumed by the next tick,
## so a tap that begins and ends between two simulation ticks is not lost.

const InputRouter = preload("res://src/input/input_router.gd")


func _key(code: Key, pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func test_latched_bomb_press_is_consumed_exactly_once() -> void:
	var router = InputRouter.new()
	router.handle_event(_key(KEY_SPACE, true))

	check(router.read_player(0)["bomb"], "press is delivered even with no held key")
	check(not router.read_player(0)["bomb"], "the latch clears after the tick reads it")


func test_release_and_key_repeat_do_not_latch() -> void:
	var router = InputRouter.new()
	router.handle_event(_key(KEY_SPACE, false))
	check(not router.read_player(0)["bomb"], "key-up alone is not a press")

	router.handle_event(_key(KEY_SPACE, true, true))
	check(not router.read_player(0)["bomb"], "auto-repeat is ignored")


func test_players_latch_independently() -> void:
	var router = InputRouter.new()
	router.handle_event(_key(KEY_ENTER, true))

	check(not router.read_player(0)["bomb"], "P1 did not receive P2's press")
	check(router.read_player(1)["bomb"], "P2 received the Enter press")


func test_global_actions_latch_once() -> void:
	var router = InputRouter.new()
	router.handle_event(_key(KEY_R, true))

	check(router.poll_global()["restart"], "restart press latched")
	check(not router.poll_global()["restart"], "restart does not repeat")

	router.handle_event(_key(KEY_1, true))
	check(router.poll_global()["mode_1p"], "mode switch latched")


func test_clear_latches_drops_queued_presses() -> void:
	var router = InputRouter.new()
	router.handle_event(_key(KEY_SPACE, true))
	router.handle_event(_key(KEY_ESCAPE, true))
	router.clear_latches()

	check(not router.read_player(0)["bomb"], "queued bomb dropped")
	check(not router.poll_global()["toggle_pause"], "queued pause dropped")


func test_suspended_router_ignores_input_until_resume() -> void:
	var router = InputRouter.new()
	router.suspend()

	router.handle_event(_key(KEY_SPACE, true))
	check(not router.read_player(0)["bomb"], "unfocused window ignores presses")
	check(not router.poll_global()["toggle_pause"], "unfocused window ignores global keys")

	router.resume()
	check(not router.read_player(0)["bomb"], "resuming does not replay a press")


func test_virtual_direction_drives_player_one_only() -> void:
	var router = InputRouter.new()
	router.set_virtual_dir(Vector2i(1, 0))

	eq(router.read_player(0)["dir"], Vector2i(1, 0), "touch d-pad steers P1")
	eq(router.read_player(1)["dir"], Vector2i.ZERO, "touch d-pad does not steer P2")


func test_virtual_bomb_is_consumed_once() -> void:
	var router = InputRouter.new()
	router.trigger_virtual_bomb()

	check(router.read_player(0)["bomb"], "touch bomb is delivered")
	check(not router.read_player(0)["bomb"], "touch bomb is consumed once")


func test_clear_latches_clears_virtual_touch_state() -> void:
	var router = InputRouter.new()
	router.set_virtual_dir(Vector2i(1, 0))
	router.trigger_virtual_bomb()
	router.clear_latches()

	eq(router.read_player(0)["dir"], Vector2i.ZERO, "pause drops a held touch direction")
	check(not router.read_player(0)["bomb"], "pause drops a queued touch bomb")

