extends Node3D
## One burning tile. Grows on spawn, holds, then fades out; the fade curve is
## normalised to `rules.blast_ticks` so the visual lifetime matches the damage window.

const Style = preload("res://src/render/arena_style.gd")

var _mat: StandardMaterial3D
var _mesh: MeshInstance3D
var _t: float = 0.0


func setup() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(Style.TILE_SIZE * 0.94, 1.05, Style.TILE_SIZE * 0.94)

	_mat = Style.make_material(Color(1.0, 0.55, 0.18), Color(1.0, 0.42, 0.10), 5.5)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	_mesh = MeshInstance3D.new()
	_mesh.mesh = box
	_mesh.material_override = _mat
	_mesh.position.y = 0.55
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func sync(age_ticks: int, blast_ticks: int, delta: float) -> void:
	_t += delta
	var life := clampf(float(age_ticks) / float(maxi(blast_ticks, 1)), 0.0, 1.0)

	var grow := clampf(life / 0.18, 0.0, 1.0)
	var fade := clampf((life - 0.55) / 0.45, 0.0, 1.0)
	var scale_xz := lerpf(0.35, 1.0, grow) * (1.0 - fade * 0.15)
	_mesh.scale = Vector3(scale_xz, lerpf(0.5, 1.0, grow), scale_xz)
	_mesh.rotation.y += delta * 2.5

	var flicker := 0.85 + 0.15 * sin(_t * 40.0)
	_mat.albedo_color.a = (1.0 - fade) * flicker
	_mat.emission_energy_multiplier = 5.5 * (1.0 - fade * 0.75)
