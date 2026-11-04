extends Node3D
## Floor loot icons built from primitives instead of text: a bomb, a flame, a
## lightning bolt and a boxing glove, each on a colour-coded ring. Classic read at
## a glance, no label required.

const Style = preload("res://src/render/arena_style.gd")

var pickup_type: int = 0

var _ring: MeshInstance3D
var _icon: Node3D
var _ring_mat: StandardMaterial3D
var _t: float = 0.0


func setup(type: int) -> void:
	pickup_type = type
	var color: Color = Style.PICKUP_COLORS.get(type, Color.WHITE)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.30
	torus.outer_radius = 0.44
	torus.rings = 24
	torus.ring_segments = 10
	_ring_mat = Style.make_material(color, color, 1.6)
	_ring_mat.roughness = 0.30
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _ring_mat
	_ring.rotation.x = PI * 0.5
	_ring.position.y = 0.06
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_icon = Node3D.new()
	_icon.position.y = 0.80
	add_child(_icon)
	match type:
		0:
			_build_bomb(color)
		1:
			_build_fire(color)
		2:
			_build_speed(color)
		_:
			_build_kick(color)

	var disc := CylinderMesh.new()
	disc.top_radius = 0.38
	disc.bottom_radius = 0.38
	disc.height = 0.02
	disc.radial_segments = 20
	var shadow := MeshInstance3D.new()
	shadow.mesh = disc
	var shadow_mat := Style.make_material(Color(0.0, 0.0, 0.0, 0.34))
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shadow_mat
	shadow.position.y = 0.012
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)


func _add(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_icon.add_child(node)
	return node


func _sphere(radius: float, material: Material, at: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return _add(mesh, material, at)


func _build_bomb(tint: Color) -> void:
	var dark := Style.make_material(Color(0.060, 0.065, 0.080))
	dark.roughness = 0.22
	dark.metallic = 0.20
	_sphere(0.21, dark, Vector3(0.0, 0.02, 0.0))

	var cord := CylinderMesh.new()
	cord.top_radius = 0.020
	cord.bottom_radius = 0.026
	cord.height = 0.20
	cord.radial_segments = 8
	var cord_mat := Style.make_material(Color(0.74, 0.64, 0.46))
	var node := _add(cord, cord_mat, Vector3(0.06, 0.24, 0.0))
	node.rotation.z = -0.45

	var spark_mat := Style.make_material(Color(1.0, 0.85, 0.40), Color(1.0, 0.66, 0.12), 4.0)
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sphere(0.055, spark_mat, Vector3(0.115, 0.34, 0.0))
	_ring_mat.emission_energy_multiplier = 1.8 + tint.r * 0.2


func _build_fire(tint: Color) -> void:
	var outer := CylinderMesh.new()
	outer.top_radius = 0.02
	outer.bottom_radius = 0.24
	outer.height = 0.52
	outer.radial_segments = 14
	var outer_mat := Style.make_material(Color(1.0, 0.42, 0.10), Color(1.0, 0.38, 0.06), 2.2)
	_add(outer, outer_mat, Vector3(0.0, 0.10, 0.0))

	var inner := CylinderMesh.new()
	inner.top_radius = 0.01
	inner.bottom_radius = 0.12
	inner.height = 0.34
	inner.radial_segments = 12
	var inner_mat := Style.make_material(Color(1.0, 0.88, 0.42), Color(1.0, 0.78, 0.22), 3.0)
	_add(inner, inner_mat, Vector3(0.0, 0.04, 0.0))


func _build_speed(tint: Color) -> void:
	var bolt_mat := Style.make_material(tint, tint, 2.4)
	bolt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var segments := [
		[Vector3(-0.03, 0.14, 0.0), 0.50, Vector3(0.11, 0.30, 0.075)],
		[Vector3(0.03, -0.01, 0.0), -0.50, Vector3(0.11, 0.28, 0.075)],
		[Vector3(-0.02, -0.16, 0.0), 0.50, Vector3(0.11, 0.26, 0.075)],
	]
	for data in segments:
		var mesh := BoxMesh.new()
		mesh.size = data[2]
		var node := _add(mesh, bolt_mat, data[0])
		node.rotation.z = data[1]


func _build_kick(tint: Color) -> void:
	var glove_mat := Style.make_material(tint, tint * 0.6, 0.9)
	glove_mat.roughness = 0.45
	var glove := _sphere(0.22, glove_mat, Vector3(0.0, 0.02, 0.02))
	glove.scale = Vector3(1.0, 0.85, 1.25)

	var cuff := CylinderMesh.new()
	cuff.top_radius = 0.13
	cuff.bottom_radius = 0.13
	cuff.height = 0.14
	cuff.radial_segments = 14
	var cuff_mat := Style.make_material(tint.darkened(0.20))
	var node := _add(cuff, cuff_mat, Vector3(0.0, -0.12, -0.12))
	node.rotation.x = PI * 0.5


func sync(delta: float) -> void:
	_t += delta
	_icon.rotation.y += delta * 1.9
	_icon.position.y = 0.80 + sin(_t * 2.5) * 0.075
	_ring.rotation.z += delta * 0.6
	_ring_mat.emission_energy_multiplier = 1.3 + 0.55 * absf(sin(_t * 3.2))
	_ring.scale = Vector3.ONE * (1.0 + 0.04 * sin(_t * 3.2))
