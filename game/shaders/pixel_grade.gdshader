shader_type canvas_item;
uniform float glow_amount = 0.10;
uniform float vignette_amount = 0.11;
void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	vec2 px = TEXTURE_PIXEL_SIZE * 2.0;
	vec3 glow = max(texture(TEXTURE, UV + vec2(px.x,0.0)).rgb - 0.74, vec3(0.0));
	glow += max(texture(TEXTURE, UV - vec2(px.x,0.0)).rgb - 0.74, vec3(0.0));
	glow += max(texture(TEXTURE, UV + vec2(0.0,px.y)).rgb - 0.74, vec3(0.0));
	glow += max(texture(TEXTURE, UV - vec2(0.0,px.y)).rgb - 0.74, vec3(0.0));
	c += glow * glow_amount;
	float edge = dot(UV - 0.5, UV - 0.5);
	c *= 1.0 - edge * vignette_amount;
	COLOR = vec4(c, 1.0);
}
