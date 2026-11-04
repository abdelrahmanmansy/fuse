extends Node3D
## One burning tile rendered as layered flame lances over a ground glow. Adjacent
## tiles join into the classic cross-shaped explosion; the fade curve is normalised
## to `rules.blast_ticks` so the visual lifetime matches the damage window.

const Style = preload("res://src/render/arena_style.gd")

var _glow: MeshInstance3D
var _outer: MeshInstance3D
var _inner: MeshInstance3D
var _licks: Array[MeshInstance3D] = []
var _outer_mat: StandardMaterial3D
var _inner_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _t: float = 0.0


func setup() -> void:
	_outer_mat = _flame_material(Color(1.0, 0.40, 0.08), 0.92)
	_inner_mat = _flame_material(Color(1.0, 0.86, 0.38), 0.95)
	_glow_mat = _flame_material(Color(1.0, 0.48, 0.10), 0.55)

	var outer_cone := CylinderMesh.new()
	outer_cone.top_radius = 0.08
	outer_cone.bottom_radius = 0.68
	outer_cone.height = 1.85
	outer_cone.radial_segments = 18
	_outer = _mesh(outer_cone, _outer_mat, Vector3(0.0, 0.92, 0.0))

	var inner_cone := CylinderMesh.new()
	inner_cone.top_radius = 0.03
	inner_cone.bottom_radius = 0.34
	inner_cone.height = 1.40
	inner_cone.radial_segments = 16
	_inner = _mesh(inner_cone, _inner_mat, Vector3(0.0, 0.70, 0.0))

	var lick := SphereMesh.new()
	lick.radius = 0.22
	lick.height = 0.44
	lick.radial_segments = 12
	lick.rings = 6
	for i in 3:
		var node := _mesh(lick, _outer_mat if i != 1 else _inner_mat, Vector3(0.0, 0.55, 0.0))
		_licks.append(node)

	var disc := CylinderMesh.new()
	disc.top_radius = 0.92
	disc.bottom_radius = 0.92
	disc.height = 0.03
	disc.radial_segments = 24
	_glow = _mesh(disc, _glow_mat, Vector3(0.0, 0.03, 0.0))


func _flame_material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := Style.make_material(Color(color.r, color.g, color.b, alpha))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func sync(age_ticks: int, blast_ticks: int, delta: float) -> void:
	_t += delta
	var life := clampf(float(age_ticks) / float(maxi(blast_ticks, 1)), 0.0, 1.0)

	var grow := clampf(life / 0.16, 0.0, 1.0)
	var fade := clampf((life - 0.52) / 0.48, 0.0, 1.0)
	var width := lerpf(0.45, 1.0, grow) * (1.0 - fade * 0.10)
	var height := lerpf(0.35, 1.0, grow) * (1.0 - fade * 0.25)
	var flicker := 0.88 + 0.12 * sin(_t * 42.0 + position.x * 3.0)

	_outer.scale = Vector3(width, height, width)
	_outer.rotation.y += delta * 2.2
	_outer_mat.albedo_color.a = (1.0 - fade) * 0.90 * flicker

	_inner.scale = Vector3(width * 0.82, height * 0.90, width * 0.82)
	_inner.rotation.y -= delta * 3.6
	_inner_mat.albedo_color.a = (1.0 - fade) * 0.95

	_glow.scale = Vector3(width * (1.0 + 0.06 * flicker), 1.0, width * (1.0 + 0.06 * flicker))
	_glow_mat.albedo_color.a = (1.0 - fade) * 0.45 * flicker

	# Three licking tongues orbiting the column, phasing in and out.
	for i in _licks.size():
		var angle := _t * (2.4 + i * 0.7) + TAU * float(i) / float(_licks.size())
		var radius := 0.28 * width
		var node := _licks[i]
		node.position = Vector3(cos(angle) * radius, (0.45 + 0.22 * float(i)) * height, sin(angle) * radius)
		node.scale = Vector3.ONE * (width * (0.75 + 0.25 * sin(_t * 7.0 + i)))
		node.rotation.y = angle
