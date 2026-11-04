shader_type spatial;
// Classic grass checkerboard baked into the floor slab. Working in world space
// means one plane covers the whole board with a crisp two-tone checker, dark tile
// seams and subtle grass speckle instead of hundreds of instanced quads.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec2 grid_size = vec2(15.0, 13.0);
uniform float tile_size = 2.0;
uniform vec3 color_a : source_color = vec3(0.400, 0.690, 0.330);
uniform vec3 color_b : source_color = vec3(0.340, 0.620, 0.270);
uniform vec3 seam_color : source_color = vec3(0.200, 0.380, 0.160);
uniform float seam_width = 0.040;

varying vec3 world_position;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_position.xz / tile_size + grid_size * 0.5;
	vec2 cell = floor(uv);
	vec2 local = fract(uv);

	float checker = mod(cell.x + cell.y, 2.0);
	vec3 base = mix(color_a, color_b, checker);

	// Per-tile tone jitter keeps the checker from looking printed.
	base *= 0.955 + 0.09 * hash21(cell);

	// Sparse grass speckle, stable in world space.
	float speckle = hash21(floor(world_position.xz * 7.0));
	base *= 0.94 + 0.12 * speckle;

	// Dark seams on the tile borders read as the classic slab grid.
	vec2 edge = min(local, vec2(1.0) - local);
	float seam = 1.0 - smoothstep(0.0, seam_width, min(edge.x, edge.y));
	ALBEDO = mix(base, seam_color, seam * 0.9);
	ROUGHNESS = 0.94;
	SPECULAR = 0.05;
}
