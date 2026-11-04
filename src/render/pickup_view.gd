extends Node3D
## Floor loot: a spinning ring with a readable label. Colors match the HUD legend.

const Style = preload("res://src/render/arena_style.gd")

var pickup_type: int = 0

var _ring: MeshInstance3D
var _label: Label3D
var _mat: StandardMaterial3D
var _t: float = 0.0


func setup(type: int) -> void:
	pickup_type = type
	var color: Color = Style.PICKUP_COLORS.get(type, Color.WHITE)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.16
	torus.outer_radius = 0.31
	torus.rings = 20
	torus.ring_segments = 10
	_mat = Style.make_material(color, color, 1.4)
	_mat.roughness = 0.30
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _mat
	_ring.rotation.x = PI * 0.5
	_ring.position.y = 0.5
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)

	_label = Label3D.new()
	_label.text = Style.PICKUP_LABELS[type] if type >= 0 and type < Style.PICKUP_LABELS.size() else "?"
	_label.font_size = 44
	_label.pixel_size = 0.004
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = color
	_label.outline_size = 8
	_label.outline_modulate = Color(0.02, 0.03, 0.05, 0.9)
	_label.position.y = 1.05
	_label.no_depth_test = false
	add_child(_label)


func sync(delta: float) -> void:
	_t += delta
	_ring.rotation.z += delta * 2.2
	_ring.position.y = 0.5 + sin(_t * 2.6) * 0.08
	_label.position.y = 1.06 + sin(_t * 2.6) * 0.08
	_mat.emission_energy_multiplier = 1.2 + 0.5 * absf(sin(_t * 3.4))
	_label.modulate.a = 0.85 + 0.15 * absf(sin(_t * 3.4))
