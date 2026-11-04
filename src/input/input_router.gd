extends RefCounted
## Keyboard/gamepad -> per-player commands. Only this layer knows about devices;
## the simulation receives plain {dir, bomb} dictionaries.
##
## Two input paths are merged on purpose:
##   - held state is polled every tick for movement (smooth, cancellable)
##   - press edges are also latched from real input events, so a tap that starts
##     and ends between two ticks is never lost (bomb, pause, restart, modes)
##
## Latching is what makes the game feel immediate on high-refresh displays and
## under frame hitches: the event arrives when it happens, the tick consumes it.

const Dirs = preload("res://src/core/sim/dirs.gd")

const P1_KEYS := {
	"up": KEY_W,
	"down": KEY_S,
	"left": KEY_A,
	"right": KEY_D,
	"bomb": KEY_SPACE,
}
const P2_KEYS := {
	"up": KEY_UP,
	"down": KEY_DOWN,
	"left": KEY_LEFT,
	"right": KEY_RIGHT,
	"bomb": KEY_ENTER,
}

## Analog sticks report noise around 0.1; 0.28 reaches the first registered
## direction sooner than the old 0.4 without causing drift.
const STICK_DEADZONE := 0.28

var _prev_bomb := [false, false, false, false]
var _bomb_latch := [false, false, false, false]
var _prev_pause := false
var _prev_restart := false
var _prev_one := false
var _prev_two := false
var _pause_latch := false
var _restart_latch := false
var _mode1_latch := false
var _mode2_latch := false
var _suspended := false


func read_player(index: int) -> Dictionary:
	if _suspended:
		return {"dir": Vector2i.ZERO, "bomb": false}
	var keys: Dictionary = P1_KEYS if index == 0 else P2_KEYS
	var dir := Vector2i.ZERO
	if Input.is_physical_key_pressed(keys["left"]):
		dir = Dirs.LEFT
	elif Input.is_physical_key_pressed(keys["right"]):
		dir = Dirs.RIGHT
	elif Input.is_physical_key_pressed(keys["up"]):
		dir = Dirs.UP
	elif Input.is_physical_key_pressed(keys["down"]):
		dir = Dirs.DOWN

	var bomb := Input.is_physical_key_pressed(keys["bomb"])

	var pad := _pad_dir(index)
	if pad != Vector2i.ZERO:
		dir = pad
	if index < Input.get_connected_joypads().size():
		var device: int = Input.get_connected_joypads()[index]
		if _joy_bomb(device):
			bomb = true

	var pressed: bool = bomb and not bool(_prev_bomb[index])
	_prev_bomb[index] = bomb
	if _bomb_latch[index]:
		pressed = true
		_bomb_latch[index] = false
	return {"dir": dir, "bomb": pressed}


func poll_global() -> Dictionary:
	if _suspended:
		return {
			"toggle_pause": false,
			"restart": false,
			"mode_1p": false,
			"mode_2p": false,
		}
	var pause := Input.is_physical_key_pressed(KEY_ESCAPE)
	var restart := Input.is_physical_key_pressed(KEY_R)
	var one := Input.is_physical_key_pressed(KEY_1)
	var two := Input.is_physical_key_pressed(KEY_2)
	var result := {
		"toggle_pause": _pause_latch or (pause and not _prev_pause),
		"restart": _restart_latch or (restart and not _prev_restart),
		"mode_1p": _mode1_latch or (one and not _prev_one),
		"mode_2p": _mode2_latch or (two and not _prev_two),
	}
	_prev_pause = pause
	_prev_restart = restart
	_prev_one = one
	_prev_two = two
	_pause_latch = false
	_restart_latch = false
	_mode1_latch = false
	_mode2_latch = false
	return result


## Record a real key/pad press the instant it happens. Called from the game
## shell's _unhandled_input, so UI-consumed events never leak into gameplay.
func handle_event(event: InputEvent) -> void:
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return
		match event.physical_keycode:
			KEY_SPACE:
				_bomb_latch[0] = true
			KEY_ENTER:
				_bomb_latch[1] = true
			KEY_ESCAPE:
				_pause_latch = true
			KEY_R:
				_restart_latch = true
			KEY_1:
				_mode1_latch = true
			KEY_2:
				_mode2_latch = true
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_X:
			var index := _pad_index(event.device)
			if index >= 0 and index < _bomb_latch.size():
				_bomb_latch[index] = true


## Drop queued presses without touching held state (pausing must not bank a
## bomb that fires on resume).
func clear_latches() -> void:
	for i in _bomb_latch.size():
		_bomb_latch[i] = false
	_pause_latch = false
	_restart_latch = false
	_mode1_latch = false
	_mode2_latch = false


## Window lost focus: stop reading devices and forget queued presses. Godot does
## not expose a way to force-release physical keys, so ignoring held state while
## unfocused is the safe option (the next focus-in re-syncs the edge trackers).
func suspend() -> void:
	_suspended = true
	reset()


func resume() -> void:
	_suspended = false
	reset()


## Full reset for round starts and focus changes: sync the edge trackers to the
## keys actually held now (so the menu-confirm keypress does not fire a bomb on
## the first tick) and forget queued presses.
func reset() -> void:
	clear_latches()
	for i in _prev_bomb.size():
		var keys: Dictionary = P1_KEYS if i == 0 else P2_KEYS
		_prev_bomb[i] = Input.is_physical_key_pressed(keys["bomb"])
	_prev_pause = Input.is_physical_key_pressed(KEY_ESCAPE)
	_prev_restart = Input.is_physical_key_pressed(KEY_R)
	_prev_one = Input.is_physical_key_pressed(KEY_1)
	_prev_two = Input.is_physical_key_pressed(KEY_2)


func _pad_dir(index: int) -> Vector2i:
	var pads := Input.get_connected_joypads()
	if index >= pads.size():
		return Vector2i.ZERO
	var device: int = pads[index]
	var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var y := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	var dir := Vector2i.ZERO

	# Pick the most-deflected axis: the old "x first" rule made a diagonal push
	# feel like it ignored the stronger vertical component.
	var ax := absf(x)
	var ay := absf(y)
	if maxf(ax, ay) >= STICK_DEADZONE:
		if ax >= ay:
			dir = Dirs.RIGHT if x > 0.0 else Dirs.LEFT
		else:
			dir = Dirs.DOWN if y > 0.0 else Dirs.UP

	# A digital D-pad always wins over the stick.
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		dir = Dirs.LEFT
	elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		dir = Dirs.RIGHT
	elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
		dir = Dirs.UP
	elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
		dir = Dirs.DOWN
	return dir


func _joy_bomb(device: int) -> bool:
	return Input.is_joy_button_pressed(device, JOY_BUTTON_A) \
		or Input.is_joy_button_pressed(device, JOY_BUTTON_X)


func _pad_index(device: int) -> int:
	return Input.get_connected_joypads().find(device)
