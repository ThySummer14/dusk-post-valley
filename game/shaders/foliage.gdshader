shader_type spatial;
uniform vec4 leaf_color : source_color = vec4(0.27, 0.39, 0.28, 1.0);
uniform float wind_strength = 0.025;
uniform float occlusion_fade = 0.0;
varying vec3 local_pos;
void vertex() {
	local_pos = VERTEX;
	vec3 center = MODEL_MATRIX[3].xyz;
	VERTEX.x += sin(TIME * 0.85 + center.x * 1.3 + center.z * 0.7) * max(VERTEX.y, 0.0) * wind_strength;
}
void fragment() {
	float screen_pattern = mod(floor(FRAGCOORD.x) + mod(floor(FRAGCOORD.y), 2.0) * 2.0, 4.0) * 0.25;
	if (occlusion_fade > 0.01 && screen_pattern < occlusion_fade) { discard; }
	vec3 leaf_cell = floor(local_pos * 7.0);
	float patch = fract(sin(dot(leaf_cell, vec3(17.1, 31.7, 7.3))) * 431.4);
	ALBEDO = leaf_color.rgb * (0.96 + step(0.64, patch) * 0.055);
	ROUGHNESS = 1.0;
}
void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	float band = floor(facing * 4.0) / 4.0;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * band / 3.14159265;
}
