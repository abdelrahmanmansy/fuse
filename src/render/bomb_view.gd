extends Node3D
## Classic bomb visual: a glossy black sphere with a lit fuse. The fuse ratio comes
## straight from the sim, so what the player sees always matches the tick the
## explosion will happen on.

const Style = preload("res://src/render/arena_style.gd")

var bomb_id: int = -1
var _core: MeshInstance3D
var _fuse: Node3D
var _spark: MeshInstance3D
var _shadow: MeshInstance3D
var _mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _t: float = 0.0


func setup(id: int) -> void:
	bomb_id = id
	_t = float((id * 37) % 100) * 0.01

	var sphere := SphereMesh.new()
	sphere.radius = 0.40
	sphere.height = 0.80
	sphere.radial_segments = 28
	sphere.rings = 14

	_mat = Style.make_material(Color(0.045, 0.050, 0.062))
	_mat.roughness = 0.18
	_mat.metallic = 0.20

	_core = MeshInstance3D.new()
	_core.mesh = sphere
	_core.material_override = _mat
	_core.position.y = 0.42
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_core)

	_fuse = Node3D.new()
	_fuse.position = Vector3(0.04, 0.74, 0.0)
	_fuse.rotation.z = -0.55
	add_child(_fuse)

	var cord := CylinderMesh.new()
	cord.top_radius = 0.026
	cord.bottom_radius = 0.034
	cord.height = 0.30
	cord.radial_segments = 10
	var cord_node := MeshInstance3D.new()
	cord_node.mesh = cord
	cord_node.material_override = Style.make_material(Color(0.72, 0.62, 0.44))
	cord_node.position.y = 0.13
	_fuse.add_child(cord_node)

	var spark := SphereMesh.new()
	spark.radius = 0.085
	spark.height = 0.17
	spark.radial_segments = 12
	spark.rings = 6
	_spark_mat = Style.make_material(Color(1.0, 0.86, 0.42), Color(1.0, 0.68, 0.14), 5.0)
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark = MeshInstance3D.new()
	_spark.mesh = spark
	_spark.material_override = _spark_mat
	_spark.position.y = 0.31
	_fuse.add_child(_spark)

	var disc := CylinderMesh.new()
	disc.top_radius = 0.40
	disc.bottom_radius = 0.40
	disc.height = 0.02
	disc.radial_segments = 20
	_shadow = MeshInstance3D.new()
	_shadow.mesh = disc
	var shadow_mat := Style.make_material(Color(0.0, 0.0, 0.0, 0.42))
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = shadow_mat
	_shadow.position.y = 0.012
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)


func sync(bomb, grid_size: Vector2i, delta: float, rules) -> void:
	_t += delta
	position = Style.position_to_world(bomb.visual_position(), grid_size, 0.0)

	var fuse_max: int = maxi(rules.fuse_ticks, 1)
	var ratio := clampf(float(bomb.fuse) / float(fuse_max), 0.0, 1.0)
	var urgency := 1.0 - ratio
	var blink := 0.55 + 0.45 * absf(sin(_t * (7.0 + urgency * 26.0)))

	# Breathe like an over-inflated balloon; faster as the fuse burns down.
	var pulse := 1.0 + 0.055 * sin(_t * (5.0 + urgency * 14.0))
	_core.scale = Vector3(pulse, 2.0 - pulse, pulse)
	_core.position.y = 0.42 + absf(sin(_t * 6.0)) * 0.015

	# Late-fuse white/red flashing is the classic "get away" tell.
	var flash := 0.0
	if urgency > 0.70:
		flash = absf(sin(_t * (12.0 + urgency * 36.0))) * ((urgency - 0.70) / 0.30)
	_mat.albedo_color = Color(0.045, 0.050, 0.062).lerp(Color(1.0, 0.86, 0.70), flash * 0.85)
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.26, 0.10)
	_mat.emission_energy_multiplier = 0.10 + urgency * 2.0 + flash * 4.0

	_spark.position.y = 0.31 + 0.025 * sin(_t * 17.0)
	_spark.scale = Vector3.ONE * (0.75 + 0.45 * blink)
	_spark_mat.emission_energy_multiplier = 3.0 + 4.0 * blink
	_fuse.rotation.z = -0.55 + 0.06 * sin(_t * 3.1)
