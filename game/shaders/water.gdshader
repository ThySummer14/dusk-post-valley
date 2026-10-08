shader_type spatial;
render_mode cull_disabled;
uniform vec3 deep_color : source_color = vec3(0.12, 0.27, 0.32);
uniform vec3 sky_color : source_color = vec3(0.43, 0.56, 0.59);
uniform float evening = 0.0;
uniform float lantern_lit = 0.0;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 cell = floor(world_pos.xz * 9.0) / 9.0;
	float ripple = sin(cell.y * 8.5 + TIME * 1.1 + sin(cell.x * 2.5)) * sin(cell.x * 4.0 - TIME * 0.65);
	float glint = smoothstep(0.64, 0.86, ripple) * 0.2;
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	vec3 surface = mix(deep_color, sky_color, 0.22 + fresnel * 0.7) * mix(1.0, 0.66, evening);
	float lamp_band = exp(-pow((world_pos.x - 5.05) * 2.1, 2.0)) * exp(-abs(world_pos.z - 3.0) * 0.42);
	float lamp_breakup = smoothstep(-0.1, 0.65, sin(cell.y * 21.0 + TIME * 0.8 + sin(cell.x * 13.0)));
	vec3 reflected_warmth = vec3(0.75, 0.42, 0.13) * lamp_band * lamp_breakup * lantern_lit;
	ALBEDO = surface + vec3(glint) + reflected_warmth * 0.35;
	ROUGHNESS = 0.22;
	METALLIC = 0.18;
	NORMAL = normalize(NORMAL + vec3(sin(cell.x * 2.0 + TIME) * 0.08, 0.0, cos(cell.y * 4.0 + TIME) * 0.1));
	EMISSION = vec3(0.05, 0.09, 0.10) * (0.3 + evening * 0.7) + reflected_warmth * 0.28;
}
