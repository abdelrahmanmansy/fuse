shader_type spatial;
// Wooden crate: plank seams, dark frame and the classic diagonal cross brace.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 wood_a : source_color = vec3(0.580, 0.380, 0.190);
uniform vec3 wood_b : source_color = vec3(0.720, 0.500, 0.270);
uniform vec3 frame : source_color = vec3(0.340, 0.210, 0.090);

varying vec3 tint;

void vertex() {
	tint = COLOR.rgb;
}

void fragment() {
	vec2 uv = UV;

	float border = max(
		max(step(uv.x, 0.075), step(0.925, uv.x)),
		max(step(uv.y, 0.075), step(0.925, uv.y)));
	float plank = step(fract(uv.x * 4.0), 0.05);
	float diag_a = 1.0 - smoothstep(0.0, 0.040, abs(uv.x - uv.y));
	float diag_b = 1.0 - smoothstep(0.0, 0.040, abs(uv.x + uv.y - 1.0));
	float brace = max(diag_a, diag_b);

	vec3 base = mix(wood_a, wood_b, fract(uv.x * 4.0));
	base += 0.018 * sin(uv.y * 90.0 + uv.x * 13.0);
	vec3 color = mix(base, frame, clamp(border + brace * 0.92, 0.0, 1.0));
	color = mix(color, frame, plank * 0.55);

	ALBEDO = color * tint;
	ROUGHNESS = 0.85;
	SPECULAR = 0.10;
}
