shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
// Grashalme und Blumen wiegen im Wind (wie in der Browser-Version)
uniform float strength = 0.22;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(TIME * 1.8 + w.x * 0.35 + w.z * 0.27) + 0.4 * sin(TIME * 3.1 + w.x * 1.3);
	float k = max(VERTEX.y, 0.0);
	VERTEX.x += sway * strength * k;
	VERTEX.z += sway * strength * 0.5 * k;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.15);
}
