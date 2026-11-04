extends Node3D
## Code-built Bomberman-style character: white suit, coloured helmet, visible face,
## gloves, boots and a springy antenna. All motion (bob, lean, arm swing, footsteps,
## blink, placement squash, elimination flatten) is driven by simulation state.

const Style = preload("res://src/render/arena_style.gd")

var player_id: int = 0

var _pivot: Node3D
var _rig: Node3D
var _shadow: MeshInstance3D
var _suit_mat: StandardMaterial3D
var _accent_mat: StandardMaterial3D
var _face_mat: StandardMaterial3D
var _eye_mat: StandardMaterial3D
var _arm_left: Node3D
var _arm_right: Node3D
var _foot_left: MeshInstance3D
var _foot_right: MeshInstance3D
var _eyes: Array[MeshInstance3D] = []
var _antenna_ball: MeshInstance3D

var _elapsed: float = 0.0
var _yaw: float = 0.0
var _death_t: float = -1.0
var _was_moving: bool = false
var _squash: float = 0.0
var _blink_t: float = 0.0
var _lean: float = 0.0


func setup(id: int, color: Color) -> void:
	player_id = id
	_yaw = PI

	_pivot = Node3D.new()
	_pivot.name = "Facing"
	add_child(_pivot)

	_rig = Node3D.new()
	_rig.name = "Rig"
	_pivot.add_child(_rig)

	_suit_mat = Style.make_material(Style.SUIT_COLOR)
	_suit_mat.roughness = 0.55
	_accent_mat = Style.make_material(color, color, 0.18)
	_accent_mat.roughness = 0.42
	_face_mat = Style.make_material(Style.SKIN_COLOR)
	_face_mat.roughness = 0.62
	_eye_mat = Style.make_material(Style.EYE_COLOR)
	_eye_mat.roughness = 0.30

	var torso := CapsuleMesh.new()
	torso.radius = 0.30
	torso.height = 0.80
	torso.radial_segments = 24
	torso.rings = 8
	_add(torso, _suit_mat, Vector3(0.0, 0.46, 0.0))

	# Belt separates the suit from the head and carries the player colour.
	var belt := CylinderMesh.new()
	belt.top_radius = 0.315
	belt.bottom_radius = 0.315
	belt.height = 0.12
	belt.radial_segments = 24
	_add(belt, _accent_mat, Vector3(0.0, 0.30, 0.0))

	var head := SphereMesh.new()
	head.radius = 0.36
	head.height = 0.72
	head.radial_segments = 28
	head.rings = 14
	_add(head, _face_mat, Vector3(0.0, 1.06, 0.0))

	# Helmet: a squashed sphere reads as a dome without needing custom meshes.
	var helmet := SphereMesh.new()
	helmet.radius = 0.385
	helmet.height = 0.77
	helmet.radial_segments = 28
	helmet.rings = 14
	var helmet_node := _add(helmet, _accent_mat, Vector3(0.0, 1.20, 0.0))
	helmet_node.scale = Vector3(1.02, 0.74, 1.02)

	var brim := CylinderMesh.new()
	brim.top_radius = 0.405
	brim.bottom_radius = 0.405
	brim.height = 0.07
	brim.radial_segments = 28
	_add(brim, _accent_mat, Vector3(0.0, 1.11, 0.0))

	# Eyes sit on the face, slightly proud so they stay visible at a distance.
	var eye := SphereMesh.new()
	eye.radius = 0.055
	eye.height = 0.11
	eye.radial_segments = 12
	eye.rings = 8
	for side in [-1.0, 1.0]:
		var eye_node := _add(eye, _eye_mat, Vector3(side * 0.125, 1.08, 0.335))
		_eyes.append(eye_node)

	# Antenna: the silhouette detail that makes the character read as Bomberman.
	var stalk := CylinderMesh.new()
	stalk.top_radius = 0.022
	stalk.bottom_radius = 0.028
	stalk.height = 0.20
	stalk.radial_segments = 10
	_add(stalk, _accent_mat, Vector3(0.0, 1.57, 0.0))

	var ball := SphereMesh.new()
	ball.radius = 0.072
	ball.height = 0.144
	ball.radial_segments = 14
	ball.rings = 8
	_antenna_ball = _add(ball, _accent_mat, Vector3(0.0, 1.69, 0.0))

	# Arms pivot at the shoulder so they can swing while walking.
	_arm_left = _make_arm(-1.0)
	_arm_right = _make_arm(1.0)

	var foot := BoxMesh.new()
	foot.size = Vector3(0.20, 0.13, 0.31)
	_foot_left = _add(foot, _accent_mat, Vector3(-0.145, 0.065, 0.075))
	_foot_right = _add(foot, _accent_mat, Vector3(0.145, 0.065, 0.075))

	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.02
	disc.radial_segments = 24
	_shadow = MeshInstance3D.new()
	_shadow.mesh = disc
	var shadow_mat := Style.make_material(Color(0.0, 0.0, 0.0, 0.45))
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = shadow_mat
	_shadow.position.y = 0.012
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)


func _make_arm(side: float) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(side * 0.315, 0.64, 0.0)
	shoulder.rotation.z = side * 0.20
	_rig.add_child(shoulder)
	shoulder.set_meta("base_z", side * 0.20)

	var limb := CapsuleMesh.new()
	limb.radius = 0.075
	limb.height = 0.36
	limb.radial_segments = 14
	limb.rings = 6
	var node := MeshInstance3D.new()
	node.mesh = limb
	node.material_override = _suit_mat
	node.position.y = -0.12
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	shoulder.add_child(node)

	var glove := SphereMesh.new()
	glove.radius = 0.105
	glove.height = 0.21
	glove.radial_segments = 14
	glove.rings = 8
	var glove_node := MeshInstance3D.new()
	glove_node.mesh = glove
	glove_node.material_override = _accent_mat
	glove_node.position.y = -0.31
	glove_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	shoulder.add_child(glove_node)
	return shoulder


func _add(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_rig.add_child(node)
	return node


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

	position = Style.position_to_world(player.visual_position(), grid_size, 0.0)

	var facing: Vector2i = player.facing
	if facing != Vector2i.ZERO:
		var target_yaw := atan2(float(facing.x), float(facing.y))
		# A reversal is a 180° turn: snap it faster so the body catches up with the
		# instant movement instead of moonwalking for a fifth of a second.
		var turn_rate := 30.0 if absf(angle_difference(_yaw, target_yaw)) > 2.0 else 16.0
		_yaw = lerp_angle(_yaw, target_yaw, clampf(delta * turn_rate, 0.0, 1.0))
	_pivot.rotation.y = _yaw

	var moving: bool = player.moving
	if moving and not _was_moving:
		_squash = 1.0
	_was_moving = moving
	_squash = maxf(0.0, _squash - delta * 6.0)

	var step := sin(_elapsed * 13.0) if moving else 0.0
	var bob := absf(step) * 0.075 if moving else 0.0
	var squash := 1.0 + _squash * 0.10
	_rig.position.y = bob
	_rig.scale = Vector3(squash, 1.0 - (squash - 1.0) * 0.9, squash)

	# Lean into the direction of travel, never more than a few degrees.
	var target_lean := 0.10 if moving else 0.0
	_lean = lerpf(_lean, target_lean, clampf(delta * 10.0, 0.0, 1.0))
	_rig.rotation.x = _lean

	_arm_left.rotation.x = step * 0.65
	_arm_right.rotation.x = -step * 0.65
	_foot_left.position.y = 0.065 + maxf(0.0, step) * 0.075
	_foot_right.position.y = 0.065 + maxf(0.0, -step) * 0.075

	# Blink every few seconds; cheap, but it makes the character feel alive.
	_blink_t += delta
	var blinking := fmod(_blink_t, 3.4) < 0.10
	for eye in _eyes:
		eye.scale.y = 0.15 if blinking else 1.0

	var guarding: bool = player.spawn_guard > 0
	var shimmer := 0.18 + (0.45 * absf(sin(_elapsed * 9.0)) if guarding else 0.0)
	_accent_mat.emission_energy_multiplier = shimmer
	_antenna_ball.scale = Vector3.ONE * (1.0 + (0.12 * sin(_elapsed * 4.0) if guarding else 0.0))
