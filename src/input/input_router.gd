extends RefCounted
## Keyboard/gamepad -> per-player commands. Only this layer knows about devices;
## the simulation receives plain {dir, bomb} dictionaries.

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

var _prev_bomb := [false, false, false, false]
var _prev_pause := false
var _prev_restart := false
var _prev_one := false
var _prev_two := false


func read_player(index: int) -> Dictionary:
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
	return {"dir": dir, "bomb": pressed}


func poll_global() -> Dictionary:
	var pause := Input.is_physical_key_pressed(KEY_ESCAPE)
	var restart := Input.is_physical_key_pressed(KEY_R)
	var one := Input.is_physical_key_pressed(KEY_1)
	var two := Input.is_physical_key_pressed(KEY_2)
	var result := {
		"toggle_pause": pause and not _prev_pause,
		"restart": restart and not _prev_restart,
		"mode_1p": one and not _prev_one,
		"mode_2p": two and not _prev_two,
	}
	_prev_pause = pause
	_prev_restart = restart
	_prev_one = one
	_prev_two = two
	return result


func _pad_dir(index: int) -> Vector2i:
	var pads := Input.get_connected_joypads()
	if index >= pads.size():
		return Vector2i.ZERO
	var device: int = pads[index]
	var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	var y := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	var dir := Vector2i.ZERO
	if absf(x) > 0.4:
		dir = Dirs.RIGHT if x > 0.0 else Dirs.LEFT
	elif absf(y) > 0.4:
		dir = Dirs.DOWN if y > 0.0 else Dirs.UP

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
