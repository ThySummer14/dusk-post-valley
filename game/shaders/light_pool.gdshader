shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(1.0, 0.58, 0.21, 0.19);
void fragment() {
	float r = length((UV - 0.5) * 2.0);
	float ring = floor(clamp(1.0 - r, 0.0, 1.0) * 6.0) / 6.0;
	ALBEDO = tint.rgb;
	ALPHA = ring * tint.a;
}
