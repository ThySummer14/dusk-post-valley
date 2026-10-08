shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.12, 0.27, 0.32);
uniform vec3 sky_color : source_color = vec3(0.43, 0.56, 0.59);
uniform float evening = 0.0;
uniform float lantern_lit = 0.0;
// Original world-space water study. No shader-pack code or screen buffers.
uniform bool enhanced_water = true;
uniform float wave_slope : hint_range(0.0, 0.12) = 0.08;
uniform float shore_width : hint_range(0.0, 0.6) = 0.35;
uniform float reflection_weight : hint_range(0.0, 0.7) = 0.45;
// Authored inner faces of this straight creek's banks, supplied by the builder.
// This is an artistic bank-distance mask, not a measured water depth.
uniform vec2 bank_inner_x = vec2(3.0, 5.65);
// A nonnegative value freezes only this material for repeatable QA captures.
uniform float sample_time = -1.0;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Inverse-transpose normal matrix also handles nonuniform mesh scale.
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	float t = sample_time >= 0.0 ? sample_time : TIME;
	vec2 cell = floor(world_pos.xz * 9.0) / 9.0;
	float ripple = sin(cell.y * 8.5 + t * 1.1 + sin(cell.x * 2.5)) * sin(cell.x * 4.0 - t * 0.65);
	if (enhanced_water) {
		float bank_distance = max(0.0, min(world_pos.x - bank_inner_x.x, bank_inner_x.y - world_pos.x));
		float shallow = shore_width > 0.0 ? 1.0 - smoothstep(0.0, max(shore_width, 0.001), bank_distance) : 0.0;
		// The material is also used by rain puddles outside the creek.
		shallow *= step(bank_inner_x.x, world_pos.x) * step(world_pos.x, bank_inner_x.y);
		float a = cell.y * 8.5 + t * 1.1 + sin(cell.x * 2.5);
		float b = cell.x * 4.0 - t * 0.65;
		// Analytic slopes of the same two-wave height field used by ripple.
		vec3 gradient = vec3(cos(a) * 2.5 * cos(cell.x * 2.5) * sin(b) + sin(a) * 4.0 * cos(b), 0.0, 8.5 * cos(a) * sin(b)) / 8.5;
		vec3 base_normal = normalize(world_normal);
		gradient -= base_normal * dot(gradient, base_normal);
		vec3 wave_normal = normalize(base_normal - gradient * wave_slope * mix(1.0, 0.28, shallow));
		NORMAL = normalize(mat3(VIEW_MATRIX) * wave_normal);
		// This game's orthographic camera has parallel view rays, +Z to camera.
		float edge = 1.0 - clamp(dot(NORMAL, vec3(0.0, 0.0, 1.0)), 0.0, 1.0);
		float edge2 = edge * edge;
		float fresnel = 0.02 + 0.98 * edge2 * edge2 * edge;
		vec3 shallow_color = mix(deep_color, vec3(0.30, 0.42, 0.34), 0.45);
		vec3 surface = mix(deep_color, shallow_color, shallow);
		surface = mix(surface, sky_color, 0.16 + fresnel * reflection_weight) * mix(1.0, 0.66, evening);
		float lamp_band = exp(-pow((world_pos.x - 5.05) * 2.1, 2.0)) * exp(-abs(world_pos.z - 3.0) * 0.42);
		float lamp_breakup = smoothstep(-0.1, 0.65, ripple);
		vec3 warmth = vec3(0.75, 0.42, 0.13) * lamp_band * lamp_breakup * lantern_lit * (0.90 + fresnel * reflection_weight);
		float glint = smoothstep(0.76, 0.94, ripple) * 0.08 * (1.0 - shallow * 0.75);
		ALBEDO = surface + vec3(glint) + warmth * 0.35;
		ROUGHNESS = mix(0.28, 0.48, shallow);
		METALLIC = 0.08;
		EMISSION = vec3(0.05, 0.09, 0.10) * (0.3 + evening * 0.7) + warmth * 0.40;
	} else {
	// Exact v0.3 shading fallback; sample_time only permits phase-matched QA.
	float glint = smoothstep(0.64, 0.86, ripple) * 0.2;
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	vec3 surface = mix(deep_color, sky_color, 0.22 + fresnel * 0.7) * mix(1.0, 0.66, evening);
	float lamp_band = exp(-pow((world_pos.x - 5.05) * 2.1, 2.0)) * exp(-abs(world_pos.z - 3.0) * 0.42);
	float lamp_breakup = smoothstep(-0.1, 0.65, sin(cell.y * 21.0 + t * 0.8 + sin(cell.x * 13.0)));
	vec3 reflected_warmth = vec3(0.75, 0.42, 0.13) * lamp_band * lamp_breakup * lantern_lit;
	ALBEDO = surface + vec3(glint) + reflected_warmth * 0.35;
	ROUGHNESS = 0.22;
	METALLIC = 0.18;
	NORMAL = normalize(NORMAL + vec3(sin(cell.x * 2.0 + t) * 0.08, 0.0, cos(cell.y * 4.0 + t) * 0.1));
	EMISSION = vec3(0.05, 0.09, 0.10) * (0.3 + evening * 0.7) + reflected_warmth * 0.28;
	}
}
