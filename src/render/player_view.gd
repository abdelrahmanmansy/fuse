extends Node3D
## Grey-box character animation. The body is a capsule with a visor showing facing;
## motion bob, start squash and elimination flattening are real transforms driven by
## simulation state, not placeholder claims.

const Style = preload("res://src/render/arena_style.gd")

var player_id: int = 0

var _pivot: Node3D
var _body: MeshInstance3D
var _visor: MeshInstance3D
var _shadow: MeshInstance3D
var _mat: StandardMaterial3D
var _visor_mat: StandardMaterial3D

var _elapsed: float = 0.0
var _yaw: float = 0.0
var _death_t: float = -1.0
var _was_moving: bool = false
var _squash: float = 0.0
var _blink_t: float = 0.0


func setup(id: int, color: Color) -> void:
	player_id = id
	_yaw = PI

	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	add_child(_pivot)

	_mat = Style.make_material(color, color, 0.35)
	_mat.roughness = 0.42
	var capsule := CapsuleMesh.new()
	capsule.radius = Style.PLAYER_RADIUS
	capsule.height = Style.PLAYER_HEIGHT
	_body = MeshInstance3D.new()
	_body.mesh = capsule
	_body.material_override = _mat
	_body.position.y = Style.PLAYER_HEIGHT * 0.5 + 0.02
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_pivot.add_child(_body)

	_visor_mat = Style.make_material(Color(0.05, 0.06, 0.08), Color(1, 1, 1), 0.15)
	var visor := BoxMesh.new()
	visor.size = Vector3(0.4, 0.11, 0.08)
	_visor = MeshInstance3D.new()
	_visor.mesh = visor
	_visor.material_override = _visor_mat
	_visor.position = Vector3(0.0, Style.PLAYER_HEIGHT * 0.72, Style.PLAYER_RADIUS + 0.02)
	_pivot.add_child(_visor)

	var disc := CylinderMesh.new()
	disc.top_radius = Style.PLAYER_RADIUS * 1.25
	disc.bottom_radius = Style.PLAYER_RADIUS * 1.25
	disc.height = 0.02
	_shadow = MeshInstance3D.new()
	_shadow.mesh = disc
	var shadow_mat := Style.make_material(Color(0.0, 0.0, 0.0, 0.55))
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = shadow_mat
	_shadow.position.y = 0.012
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)


## Draws the character at `player.visual_position()` (tile units) on top of `grid_size`.
func sync(player, grid_size: Vector2i, delta: float) -> void:
	_elapsed += delta

	if not player.alive:
		if _death_t < 0.0:
			_death_t = 0.0
		_death_t += delta
		var flat := clampf(1.0 - _death_t / 0.25, 0.0, 1.0)
		_pivot.scale = Vector3(1.0 + (1.0 - flat) * 0.6, maxf(flat, 0.06), 1.0 + (1.0 - flat) * 0.6)
		_pivot.position.y = 0.0
		_shadow.visible = false
		if _death_t > 0.9:
			visible = false
		return

	if not visible:
		visible = true
		_death_t = -1.0
		_pivot.scale = Vector3.ONE

	_death_t = -1.0
	_shadow.visible = true

	var target := Style.position_to_world(player.visual_position(), grid_size, 0.0)
	position = target

	var facing: Vector2i = player.facing
	if facing != Vector2i.ZERO:
		var target_yaw := atan2(float(facing.x), float(facing.y))
		_yaw = lerp_angle(_yaw, target_yaw, clampf(delta * 16.0, 0.0, 1.0))
	_pivot.rotation.y = _yaw

	# Bob only while actually crossing a tile; ease out of it when stopping.
	var moving: bool = player.moving
	if moving and not _was_moving:
		_squash = 1.0
	_was_moving = moving
	_squash = maxf(0.0, _squash - delta * 6.0)

	var bob := 0.0
	if moving:
		bob = absf(sin(_elapsed * 13.0)) * 0.09
	var squash := 1.0 + _squash * 0.10
	_pivot.position.y = bob
	_pivot.scale = Vector3(squash, 1.0 - (squash - 1.0) * 0.9, squash)

	# Spawn-guard shimmer.
	var guarding: bool = player.spawn_guard > 0
	_mat.emission_energy_multiplier = 0.35 + (0.35 * absf(sin(_elapsed * 9.0)) if guarding else 0.0)
