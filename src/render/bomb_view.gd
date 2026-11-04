extends Node3D
## Bomb visual: pulse + fuse blink. The fuse ratio comes straight from the sim, so
## what the player sees always matches the tick the explosion will happen on.

const Style = preload("res://src/render/arena_style.gd")

var bomb_id: int = -1
var _core: MeshInstance3D
var _spark: MeshInstance3D
var _mat: StandardMaterial3D
var _spark_mat: StandardMaterial3D
var _t: float = 0.0


func setup(id: int) -> void:
	bomb_id = id
	_t = float((id * 37) % 100) * 0.01

	var sphere := SphereMesh.new()
	sphere.radius = 0.36
	sphere.height = 0.72
	sphere.radial_segments = 24
	sphere.rings = 12

	_mat = Style.make_material(Color(0.14, 0.16, 0.21), Color(1.0, 0.36, 0.20), 0.25)
	_mat.roughness = 0.28
	_mat.metallic = 0.35

	_core = MeshInstance3D.new()
	_core.mesh = sphere
	_core.material_override = _mat
	_core.position.y = 0.38
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_core)

	var spark := SphereMesh.new()
	spark.radius = 0.075
	spark.height = 0.15
	spark.radial_segments = 10
	spark.rings = 6
	_spark_mat = Style.make_material(Color(1.0, 0.85, 0.4), Color(1.0, 0.75, 0.2), 4.0)
	_spark = MeshInstance3D.new()
	_spark.mesh = spark
	_spark.material_override = _spark_mat
	_spark.position.y = 0.80
	add_child(_spark)


func sync(bomb, grid_size: Vector2i, delta: float, rules) -> void:
	_t += delta
	position = Style.position_to_world(bomb.visual_position(), grid_size, 0.0)

	var fuse_max: int = maxi(rules.fuse_ticks, 1)
	var ratio := clampf(float(bomb.fuse) / float(fuse_max), 0.0, 1.0)
	var urgency := 1.0 - ratio
	var blink := 0.55 + 0.45 * absf(sin(_t * (7.0 + urgency * 26.0)))

	var pulse := 1.0 + 0.07 * sin(_t * (5.0 + urgency * 14.0))
	_core.scale = Vector3.ONE * pulse
	_core.position.y = 0.38 + absf(sin(_t * 6.0)) * 0.02
	_mat.albedo_color = Color(0.14, 0.16, 0.21).lerp(Color(0.55, 0.16, 0.10), urgency * 0.8)
	_mat.emission_energy_multiplier = 0.25 + urgency * 3.0 * blink

	_spark.position.y = 0.80 + 0.03 * sin(_t * 17.0)
	_spark.scale = Vector3.ONE * (0.7 + 0.5 * blink)
	_spark_mat.emission_energy_multiplier = 3.0 + 3.0 * blink
