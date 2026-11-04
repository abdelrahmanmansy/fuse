shader_type spatial;
// Terracotta brick for the indestructible arena blocks. UVs wrap per box face,
// so every wall tile gets readable mortar lines from any angle.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 brick_a : source_color = vec3(0.620, 0.400, 0.320);
uniform vec3 brick_b : source_color = vec3(0.720, 0.490, 0.400);
uniform vec3 mortar : source_color = vec3(0.320, 0.270, 0.250);
uniform float rows = 4.0;
uniform float columns = 2.0;

varying vec3 tint;

void vertex() {
	tint = COLOR.rgb;
}

void fragment() {
	vec2 uv = UV;
	float row = floor(uv.y * rows);
	float offset = mod(row, 2.0) * 0.5;
	vec2 shifted = vec2(uv.x * columns + offset, uv.y * rows);
	vec2 cell = fract(shifted);
	float horizontal = step(cell.y, 0.10);
	float vertical = step(cell.x, 0.06);
	float gap = clamp(horizontal + vertical, 0.0, 1.0);

	float variant = mod(row + floor(shifted.x), 2.0);
	vec3 base = mix(brick_a, brick_b, variant);
	// Subtle grit so large walls do not read as flat colour.
	base *= 0.94 + 0.06 * sin(uv.x * 57.0 + uv.y * 31.0);

	ALBEDO = mix(base, mortar, gap) * tint;
	ROUGHNESS = 0.90;
	SPECULAR = 0.12;
}
